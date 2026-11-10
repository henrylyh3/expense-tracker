"""Configure temporary signing credentials and finalize GitHub Actions builds.

Private values enter through environment variables, never command interpolation
or artifacts. This script does not create certificates or publish releases.
"""
import argparse
import base64
import json
import os
import re
import secrets
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

import package_desktop
import publish_release
from package_desktop import ROOT, PLATFORM_FOLDERS, version

REQUIRED = {
    'android': ['ANDROID_KEYSTORE_BASE64', 'ANDROID_STORE_PASSWORD',
                'ANDROID_KEY_ALIAS', 'ANDROID_KEY_PASSWORD'],
    'windows': ['WINDOWS_CERTIFICATE_BASE64', 'WINDOWS_CERTIFICATE_PASSWORD',
                'WINDOWS_UPDATER_PRIVATE_KEY', 'WINDOWS_UPDATER_PUBLIC_KEY'],
    'macos': ['MACOS_CERTIFICATE_BASE64', 'MACOS_CERTIFICATE_PASSWORD',
              'MACOS_CODESIGN_IDENTITY', 'MACOS_SPARKLE_PRIVATE_KEY',
              'MACOS_SPARKLE_PUBLIC_KEY', 'MACOS_NOTARY_KEY_BASE64',
              'MACOS_NOTARY_KEY_ID', 'MACOS_NOTARY_ISSUER_ID'],
}
PRIVATE_INPUTS = {
    'android': REQUIRED['android'],
    'windows': ['WINDOWS_CERTIFICATE_BASE64', 'WINDOWS_CERTIFICATE_PASSWORD', 'WINDOWS_UPDATER_PRIVATE_KEY'],
    'macos': ['MACOS_CERTIFICATE_BASE64', 'MACOS_CERTIFICATE_PASSWORD',
              'MACOS_SPARKLE_PRIVATE_KEY', 'MACOS_NOTARY_KEY_BASE64'],
}


def native(command, env=None):
    return subprocess.run([str(value) for value in command], cwd=ROOT,
                          env=env, text=True, capture_output=True, check=True).stdout.strip()


def require_inputs(target):
    if os.environ.get('GITHUB_ACTIONS') == 'true':
        for name in PRIVATE_INPUTS[target]:
            value = os.environ.get(name, '')
            if value:
                escaped = value.replace('%', '%25').replace('\r', '%0D').replace('\n', '%0A')
                print('::add-mask::' + escaped, flush=True)
    missing = [name for name in REQUIRED[target] if not os.environ.get(name, '').strip()]
    if missing:
        raise RuntimeError('Missing GitHub Actions Variables: ' + ', '.join(missing))
    if os.environ.get('GITHUB_ACTIONS') != 'true':
        raise RuntimeError('Credential installation is restricted to GitHub Actions runners.')


def private_file(path, value):
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open('xb') as stream:
        stream.write(value if isinstance(value, bytes) else value.encode())
    path.chmod(0o600)
    return path


def decoded(name):
    # UI paste may include line breaks; malformed content never enters logs.
    return base64.b64decode(''.join(os.environ[name].split()), validate=True)


def property_value(value):
    """Java Properties.load(InputStream) consumes ISO-8859-1 and UTF-16 escapes."""
    result = ''
    encoded = value.encode('utf-16-be')
    for unit in (encoded[index:index + 2] for index in range(0, len(encoded), 2)):
        code = int.from_bytes(unit, 'big')
        char = chr(code)
        if char in '\\:=#! ':
            result += '\\' + char
        elif code < 32 or code > 126:
            result += f'\\u{code:04x}'
        else:
            result += char
    return result


def github_env(name, value):
    if '\n' in str(value) or '\r' in str(value):
        raise RuntimeError('Invalid generated runner environment value.')
    with Path(os.environ['GITHUB_ENV']).open('a') as stream:
        stream.write(f'{name}={value}\n')


def work_directory():
    return Path(os.environ['SIGNING_WORK_DIRECTORY'])


def save_state(work, state):
    (work / 'state.json').write_text(json.dumps(state))


def configure(target):
    require_inputs(target)
    work = Path(tempfile.mkdtemp(prefix='expense-tracker-signing-', dir=os.environ['RUNNER_TEMP']))
    work.chmod(0o700)
    github_env('SIGNING_WORK_DIRECTORY', work)
    state = {'target': target}
    save_state(work, state)
    if target == 'android':
        keystore = private_file(work / 'release.jks', decoded('ANDROID_KEYSTORE_BASE64'))
        fields = {'storeFile': keystore.as_posix(), 'storePassword': os.environ['ANDROID_STORE_PASSWORD'],
                  'keyAlias': os.environ['ANDROID_KEY_ALIAS'], 'keyPassword': os.environ['ANDROID_KEY_PASSWORD']}
        private_file(ROOT / 'android/key.properties', ''.join(f'{key}={property_value(value)}\n' for key, value in fields.items()))
    elif target == 'windows':
        public = os.environ['WINDOWS_UPDATER_PUBLIC_KEY'].strip() + '\n'
        if 'PRIVATE KEY' in public or '-----BEGIN PUBLIC KEY-----' not in public:
            raise RuntimeError('WINDOWS_UPDATER_PUBLIC_KEY must contain only a PEM public key.')
        private_file(ROOT / 'dsa_pub.pem', public)
        private_file(ROOT / 'dsa_priv.pem', os.environ['WINDOWS_UPDATER_PRIVATE_KEY'].strip() + '\n')
        certificate = private_file(work / 'certificate.pfx', decoded('WINDOWS_CERTIFICATE_BASE64'))
        script = ('$password = ConvertTo-SecureString $env:WINDOWS_CERTIFICATE_PASSWORD -AsPlainText -Force; '
                  '$cert = Import-PfxCertificate -FilePath $env:CI_CERTIFICATE_FILE -CertStoreLocation Cert:\\CurrentUser\\My -Password $password | '
                  'Where-Object HasPrivateKey | Select-Object -First 1; '
                  'if (-not $cert) { exit 1 }; $cert.Thumbprint')
        thumbprint = native(['powershell.exe', '-NoProfile', '-NonInteractive', '-Command', script],
                            env={**os.environ, 'CI_CERTIFICATE_FILE': str(certificate)})
        if not re.fullmatch(r'[A-Fa-f0-9]{40}', thumbprint):
            raise RuntimeError('Could not identify imported Windows signing certificate.')
        state['thumbprint'] = thumbprint
        save_state(work, state)
        candidates = list((Path(os.environ['ProgramFiles(x86)']) / 'Windows Kits/10/bin').glob('*/x64/signtool.exe'))
        if not candidates:
            raise RuntimeError('Windows SDK SignTool is missing.')
        state['signtool'] = str(max(candidates, key=lambda path: tuple(map(int, path.parent.parent.name.split('.')))))
        save_state(work, state)
        openssl = shutil.which('openssl') or next((str(path) for path in (
            Path(os.environ['ProgramFiles']) / 'OpenSSL-Win64/bin/openssl.exe',
            Path(os.environ['ProgramFiles']) / 'Git/usr/bin/openssl.exe') if path.is_file()), None)
        if not openssl:
            raise RuntimeError('OpenSSL is required by WinSparkle signing.')
        with Path(os.environ['GITHUB_PATH']).open('a') as stream:
            stream.write(str(Path(openssl).parent) + '\n')
        actual_public = native([openssl, 'dsa', '-in', ROOT / 'dsa_priv.pem', '-pubout'])
        if ''.join(actual_public.split()) != ''.join(public.split()):
            raise RuntimeError('WinSparkle private/public keys do not match.')
    else:
        public = os.environ['MACOS_SPARKLE_PUBLIC_KEY'].strip()
        if len(base64.b64decode(public, validate=True)) != 32:
            raise RuntimeError('MACOS_SPARKLE_PUBLIC_KEY must be a 32-byte Base64 public key.')
        private = ''.join(os.environ['MACOS_SPARKLE_PRIVATE_KEY'].split())
        if len(base64.b64decode(private, validate=True)) not in (32, 96):
            raise RuntimeError('Invalid Sparkle exported private-key format.')
        private_file(ROOT / 'macos/Runner/Configs/Signing.xcconfig', f'SPARKLE_PUBLIC_ED_KEY = {public}\n')
        key_file = private_file(work / 'sparkle-private-key.txt', private)
        github_env('SPARKLE_PRIVATE_KEY_FILE', key_file)
        swift = ('import Foundation; import CryptoKit; '
                 'let text = try String(contentsOfFile: CommandLine.arguments[1], encoding: .utf8).trimmingCharacters(in: .whitespacesAndNewlines); '
                 'guard let data = Data(base64Encoded: text) else { exit(1) }; '
                 'let pub = data.count == 32 ? try Curve25519.Signing.PrivateKey(rawRepresentation: data).publicKey.rawRepresentation : Data(data.suffix(32)); '
                 'print(pub.base64EncodedString())')
        if native(['swift', '-e', swift, key_file]) != public:
            raise RuntimeError('Sparkle private/public keys do not match.')
        private_file(work / 'notary-key.p8', decoded('MACOS_NOTARY_KEY_BASE64'))
        certificate = private_file(work / 'certificate.p12', decoded('MACOS_CERTIFICATE_BASE64'))
        keychain = work / 'release.keychain-db'
        state['keychain'] = str(keychain)
        save_state(work, state)
        password = secrets.token_urlsafe(32)
        native(['security', 'create-keychain', '-p', password, keychain])
        native(['security', 'set-keychain-settings', '-lut', '21600', keychain])
        native(['security', 'unlock-keychain', '-p', password, keychain])
        native(['security', 'import', certificate, '-k', keychain, '-P', os.environ['MACOS_CERTIFICATE_PASSWORD'],
                '-T', '/usr/bin/codesign', '-T', '/usr/bin/security'])
        native(['security', 'set-key-partition-list', '-S', 'apple-tool:,apple:,codesign:', '-s', '-k', password, keychain])
    clear_outputs(target)
    print(f'{target}: temporary signing configuration ready; private values not logged.')


def clear_outputs(target):
    name, _ = version()
    folder = ROOT / 'release' / PLATFORM_FOLDERS[target]
    # Only the current version in this ephemeral checkout. Keep predecessor APKs
    # for certificate continuity checks and all historical release files.
    for path in folder.glob(f'expense-tracker-{name}-*'):
        if path.is_file():
            path.unlink()
    for path in (folder / f'appcast-{target}-{name}.xml', folder / f'update-{name}.json'):
        path.unlink(missing_ok=True)


def mac_sign(path, entitlements=None, preserve=False):
    identity = os.environ['MACOS_CODESIGN_IDENTITY']
    if not identity.startswith('Developer ID Application:'):
        raise RuntimeError('MACOS_CODESIGN_IDENTITY must be a Developer ID Application identity.')
    state = json.loads((work_directory() / 'state.json').read_text())
    command = ['codesign', '--force', '--timestamp', '--keychain', state['keychain'], '--sign', identity]
    if path.suffix != '.dmg':
        command += ['--options', 'runtime']
    if entitlements:
        command += ['--entitlements', entitlements]
    elif preserve:
        command += ['--preserve-metadata=entitlements']
    native([*command, path])


def notarize(path):
    output = native(['xcrun', 'notarytool', 'submit', path, '--key', work_directory() / 'notary-key.p8',
                     '--key-id', os.environ['MACOS_NOTARY_KEY_ID'], '--issuer', os.environ['MACOS_NOTARY_ISSUER_ID'],
                     '--wait', '--output-format', 'json'])
    if json.loads(output).get('status') != 'Accepted':
        raise RuntimeError('Apple notarization was not accepted; inspect the submission in your Apple account.')


def windows_sign(path):
    state = json.loads((work_directory() / 'state.json').read_text())
    timestamp = os.environ.get('WINDOWS_TIMESTAMP_URL') or 'http://timestamp.digicert.com'
    native([state['signtool'], 'sign', '/sha1', state['thumbprint'], '/s', 'My', '/fd', 'SHA256',
            '/tr', timestamp, '/td', 'SHA256', path])
    native([state['signtool'], 'verify', '/pa', '/all', path])


def sign_app(target):
    if target == 'windows':
        windows_sign(ROOT / 'build/windows/x64/runner/Release/expense_tracker.exe')
        return
    app = ROOT / 'build/macos/Build/Products/Release/expense_tracker.app'
    frameworks = app / 'Contents/Frameworks'
    # Sign inside out; never apply the main app's entitlements with --deep.
    for path in sorted(frameworks.rglob('*'), key=lambda item: len(item.parts), reverse=True):
        if path.is_symlink():
            continue
        container = path.is_dir() and path.suffix in ('.framework', '.app', '.xpc')
        macho = False
        if path.is_file():
            with path.open('rb') as stream:
                macho = stream.read(4) in (b'\xcf\xfa\xed\xfe', b'\xce\xfa\xed\xfe', b'\xca\xfe\xba\xbe', b'\xbe\xba\xfe\xca')
        if container or macho:
            mac_sign(path, preserve=True)
    mac_sign(app, entitlements=ROOT / 'macos/Runner/Release.entitlements')
    native(['codesign', '--verify', '--deep', '--strict', app])
    archive = work_directory() / 'notarize-app.zip'
    native(['ditto', '-c', '-k', '--keepParent', app, archive])
    notarize(archive)
    native(['xcrun', 'stapler', 'staple', app])


def sign_package(target):
    name, _ = version()
    folder = ROOT / 'release' / PLATFORM_FOLDERS[target]
    if target == 'windows':
        windows_sign(folder / f'expense-tracker-{name}-windows-x64-setup.exe')
    else:
        dmg = folder / f'expense-tracker-{name}-macos.dmg'
        mac_sign(dmg)
        notarize(dmg)
        native(['xcrun', 'stapler', 'staple', dmg])


def export(target):
    name, _ = version()
    release = ROOT / 'release'
    output = ROOT / 'build/release-upload'
    if output.exists():
        shutil.rmtree(output)
    if target == 'all':
        apk, manifest, data = publish_release.artifact()
        paths = [path for _, path, _ in publish_release.release_assets(apk, manifest, data, require_feeds=True)]
        paths.append(release / f'SHA256SUMS-{name}.txt')
    else:
        suffixes = {'android': ['-arm64-release.apk'], 'macos': ['-macos.dmg', '-macos-update.zip'],
                    'windows': ['-windows-x64.zip', '-windows-x64-setup.exe']}[target]
        folder = release / PLATFORM_FOLDERS[target]
        paths = [folder / f'expense-tracker-{name}{suffix}' for suffix in suffixes]
        if target != 'android':
            paths.append(folder / f'appcast-{target}-{name}.xml')
    for path in paths:
        if not path.is_file() or not path.stat().st_size:
            raise RuntimeError(f'Missing finalized artifact: {path.relative_to(ROOT)}')
    for path in paths:
        destination = output / path.relative_to(release)
        destination.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(path, destination)
    print(f'Exported {len(paths)} current-version files; no credentials or earlier artifacts included.')


def cleanup():
    if not os.environ.get('SIGNING_WORK_DIRECTORY'):
        return
    if os.environ.get('GITHUB_ACTIONS') != 'true':
        raise RuntimeError('Credential cleanup is restricted to GitHub Actions runners.')
    work = work_directory()
    state = json.loads((work / 'state.json').read_text())
    try:
        if state.get('keychain') and Path(state['keychain']).exists():
            native(['security', 'delete-keychain', state['keychain']])
        if state.get('thumbprint'):
            script = 'Remove-Item -LiteralPath ("Cert:\\CurrentUser\\My\\" + $env:CI_CERTIFICATE_THUMBPRINT) -DeleteKey -ErrorAction Stop'
            native(['powershell.exe', '-NoProfile', '-NonInteractive', '-Command', script],
                   env={**os.environ, 'CI_CERTIFICATE_THUMBPRINT': state['thumbprint']})
    finally:
        for path in ('android/key.properties', 'dsa_priv.pem', 'dsa_pub.pem', 'macos/Runner/Configs/Signing.xcconfig'):
            (ROOT / path).unlink(missing_ok=True)
        shutil.rmtree(work)


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('action', choices=['check', 'configure', 'sign-app', 'sign-package', 'export', 'cleanup'])
    parser.add_argument('platform', nargs='?', choices=[*PLATFORM_FOLDERS, 'all'])
    args = parser.parse_args()
    if args.action != 'cleanup' and (not args.platform or args.platform == 'all' and args.action != 'export'):
        parser.error('Choose one native platform; all is supported only for export.')
    if args.platform == 'android' and args.action in ('sign-app', 'sign-package'):
        parser.error('Android signing happens during the Gradle build.')
    try:
        if args.action == 'cleanup':
            cleanup()
        else:
            {'check': require_inputs, 'configure': configure, 'sign-app': sign_app, 'sign-package': sign_package, 'export': export}[args.action](args.platform)
    except (RuntimeError, OSError, ValueError, subprocess.CalledProcessError) as error:
        # Never print exception objects containing native command arguments or
        # stdout/stderr: certificate passwords and imported key data are secret.
        print(str(error) if isinstance(error, RuntimeError) else 'Signing operation failed; check credentials, certificate validity and native tooling.', file=sys.stderr)
        sys.exit(1)
