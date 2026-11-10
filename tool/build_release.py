"""Build, package and sign one platform on its native host; never publish.

Desktop builds enable the signed GitHub update feed automatically. Use --stage
to pause for Developer ID/notarization or Authenticode signing before finalizing.
"""
import argparse
import base64
import json
import os
import platform
import re
import shutil
import subprocess
import sys
from pathlib import Path

import desktop_appcast
import package_desktop
from package_desktop import ROOT, PLATFORM_FOLDERS, version
from publish_release import REPO

FOCUSED_TESTS = [
    'test/core/sharing/discord_sharing_test.dart',
    'test/core/sharing/discord_web_invite_test.dart',
    'test/features/settings/web_invitation_test.dart',
    'test/core/updates/desktop_updater_test.dart',
    'test/core/updates/update_service_test.dart',
    'test/features/settings/update_prompt_test.dart',
]


def run(command, capture=False, env=None):
    return subprocess.run(command, cwd=ROOT, check=True, text=True,
                          capture_output=capture, env=env)


def update_defines(target):
    return ['DESKTOP_UPDATE_SIGNING_CONFIGURED=true',
            f'DESKTOP_UPDATE_FEED_URL=https://github.com/{REPO}/releases/latest/download/appcast-{target}.xml']


def verify_update_build(target):
    config = ROOT / ('macos/Flutter/ephemeral/Flutter-Generated.xcconfig' if target == 'macos'
                     else 'windows/flutter/ephemeral/generated_config.cmake')
    text = config.read_text() if config.is_file() else ''
    match = re.search(r'DART_DEFINES=([A-Za-z0-9+/=,]+)', text)
    defines = {base64.b64decode(value, validate=True).decode() for value in match[1].split(',')} if match else set()
    if not set(update_defines(target)).issubset(defines):
        raise RuntimeError(f'This native build has no configured update feed. Rebuild with python tool/build_release.py {target} --stage build.')


def check_configuration(target):
    if target == 'android':
        if not (ROOT / 'android/key.properties').is_file():
            raise RuntimeError('Missing android/key.properties and original Android release keystore. Do not generate a replacement key.')
    elif target == 'macos':
        if platform.system() != 'Darwin':
            raise RuntimeError('macOS releases require a macOS host with full Xcode.')
        config = ROOT / 'macos/Runner/Configs/Signing.xcconfig'
        text = config.read_text() if config.is_file() else ''
        match = re.search(r'^\s*SPARKLE_PUBLIC_ED_KEY\s*=\s*([A-Za-z0-9+/]+={0,2})\s*$', text, re.M)
        if not match or len(base64.b64decode(match[1], validate=True)) != 32:
            raise RuntimeError('Configure a real SPARKLE_PUBLIC_ED_KEY in macos/Runner/Configs/Signing.xcconfig first.')
    else:
        if platform.system() != 'Windows':
            raise RuntimeError('Windows releases require a Windows host with Visual Studio C++ tooling.')
        key = ROOT / 'dsa_pub.pem'
        if not key.is_file() or '-----BEGIN PUBLIC KEY-----' not in key.read_text():
            raise RuntimeError('Missing dsa_pub.pem public updater key. Generate/restore the Windows updater keys first.')
        if 'PRIVATE KEY' in key.read_text():
            raise RuntimeError('dsa_pub.pem must contain only the public updater key; never embed private signing material.')


def build(target, flutter):
    check_configuration(target)
    sdk = json.loads(run([flutter, '--version', '--machine'], capture=True).stdout)
    if (sdk.get('channel') != 'stable' or '-' in sdk.get('frameworkVersion', '')
            or sdk.get('repositoryUrl', '').removesuffix('.git') != 'https://github.com/flutter/flutter'):
        raise RuntimeError('Release verification requires an official stable Flutter SDK.')
    run([flutter, 'pub', 'get', '--enforce-lockfile'])
    run([flutter, 'analyze', '--no-pub'])
    run([flutter, 'test', '--no-pub', *FOCUSED_TESTS])
    if target == 'android':
        run([flutter, 'build', 'apk', '--release', '--target-platform', 'android-arm64', '--split-per-abi'])
    else:
        run([flutter, 'build', target, '--release',
             *[f'--dart-define={value}' for value in update_defines(target)]])


def android_tools():
    sdk = Path(os.environ.get('ANDROID_HOME') or os.environ.get('ANDROID_SDK_ROOT')
               or Path.home() / ('Library/Android/sdk' if platform.system() == 'Darwin' else 'Android/Sdk'))
    directories = [path for path in (sdk / 'build-tools').glob('*')
                   if re.fullmatch(r'\d+\.\d+\.\d+', path.name)]
    if not directories:
        raise RuntimeError('Set ANDROID_HOME to an SDK containing stable Android build-tools.')
    tools = max(directories, key=lambda path: tuple(map(int, path.name.split('.'))))
    return tools / ('apksigner.bat' if platform.system() == 'Windows' else 'apksigner'), tools / ('aapt.exe' if platform.system() == 'Windows' else 'aapt')


def stage_android():
    name, build_number = version()
    source = ROOT / 'build/app/outputs/flutter-apk/app-arm64-v8a-release.apk'
    output = ROOT / 'release/android' / f'expense-tracker-{name}-arm64-release.apk'
    if output.exists():
        raise RuntimeError(f'Refusing to overwrite {output.name}.')
    apksigner, aapt = android_tools()
    signature = run([str(apksigner), 'verify', '--print-certs', str(source)], capture=True).stdout
    digest = re.search(r'Signer #1 certificate SHA-256 digest: (\S+)', signature)
    if not digest:
        raise RuntimeError('Cannot verify the Android release signer.')
    badging = run([str(aapt), 'dump', 'badging', str(source)], capture=True).stdout
    code = 2000 + int(build_number)
    package = re.search(r"^package: name='([^']+)' versionCode='(\d+)' versionName='([^']+)'", badging, re.M)
    if (not package or package.groups() != ('com.example.expense_tracker', str(code), name)
            or not re.search(r"^native-code: 'arm64-v8a'\s*$", badging, re.M)):
        raise RuntimeError('APK package ID, version code, version name or ARM64 architecture is incorrect.')
    previous = sorted(output.parent.glob('expense-tracker-*-arm64-release.apk'),
                      key=lambda path: tuple(map(int, re.search(r'(\d+\.\d+\.\d+)', path.name)[1].split('.'))))
    if previous:
        old_signature = run([str(apksigner), 'verify', '--print-certs', str(previous[-1])], capture=True).stdout
        old_digest = re.search(r'Signer #1 certificate SHA-256 digest: (\S+)', old_signature)
        old_badging = run([str(aapt), 'dump', 'badging', str(previous[-1])], capture=True).stdout
        old_code = re.search(r"versionCode='(\d+)'", old_badging)
        if not old_digest or old_digest[1] != digest[1] or not old_code or int(old_code[1]) >= code:
            raise RuntimeError('APK must retain the previous release signer and increase its version code.')
    output.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(source, output)
    return [output]


def sign(target, dart):
    check_configuration(target)
    verify_update_build(target)
    name, _ = version()
    folder = ROOT / 'release' / PLATFORM_FOLDERS[target]
    if target == 'macos':
        app = ROOT / 'build/macos/Build/Products/Release/expense_tracker.app'
        dmg = folder / f'expense-tracker-{name}-macos.dmg'
        with (app / 'Contents/Info.plist').open('rb') as stream:
            info = package_desktop.plistlib.load(stream)
        configured_key = re.search(r'^\s*SPARKLE_PUBLIC_ED_KEY\s*=\s*(\S+)',
                                  (ROOT / 'macos/Runner/Configs/Signing.xcconfig').read_text(), re.M)[1]
        if info.get('SUPublicEDKey') != configured_key:
            raise RuntimeError('Built macOS app does not embed the configured updater public key.')
        run(['codesign', '--verify', '--deep', '--strict', str(app)])
        run(['spctl', '--assess', '--type', 'execute', str(app)])
        run(['xcrun', 'stapler', 'validate', str(app)])
        run(['hdiutil', 'verify', str(dmg)])
        run(['codesign', '--verify', '--strict', str(dmg)])
        run(['xcrun', 'stapler', 'validate', str(dmg)])
        payload = folder / f'expense-tracker-{name}-macos-update.zip'
        attribute = 'edSignature'
    else:
        if not (ROOT / 'dsa_priv.pem').is_file():
            raise RuntimeError('Restore ignored dsa_priv.pem before signing the Windows updater payload.')
        payload = folder / f'expense-tracker-{name}-windows-x64-setup.exe'
        app = ROOT / 'build/windows/x64/runner/Release/expense_tracker.exe'
        for path in (app, payload):
            # Environment avoids PowerShell interpreting spaces/quotes in paths.
            script = 'if ((Get-AuthenticodeSignature -LiteralPath $env:EXPENSE_TRACKER_SIGNED_FILE).Status -ne "Valid") { exit 1 }'
            run(['powershell.exe', '-NoProfile', '-NonInteractive', '-Command', script],
                env={**os.environ, 'EXPENSE_TRACKER_SIGNED_FILE': str(path)})
        attribute = 'dsaSignature'
    command = [dart, 'run', 'auto_updater:sign_update', str(payload)]
    private_key_file = os.environ.get('SPARKLE_PRIVATE_KEY_FILE')
    if target == 'macos' and private_key_file:
        if not Path(private_key_file).is_file():
            raise RuntimeError('SPARKLE_PRIVATE_KEY_FILE does not exist.')
        command += ['--ed-key-file', private_key_file]
    result = run(command, capture=True)
    match = re.search(rf'sparkle:{attribute}="([A-Za-z0-9+/=]+)"', result.stdout)
    if not match:
        raise RuntimeError('Native signing tool did not return an updater signature.')
    return desktop_appcast.generate(target, match[1])


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('platform', choices=PLATFORM_FOLDERS)
    parser.add_argument('--stage', choices=['all', 'build', 'package', 'sign'], default='all')
    parser.add_argument('--flutter', default=os.environ.get('FLUTTER_BIN', 'flutter'))
    parser.add_argument('--dart', default=os.environ.get('DART_BIN', 'dart'))
    parser.add_argument('--iscc', default='ISCC.exe')
    args = parser.parse_args()
    if args.platform == 'android' and args.stage == 'sign':
        parser.error('Android APKs are signed during the build; use --stage package to verify/stage.')
    if args.stage in ('all', 'build'):
        build(args.platform, args.flutter)
    if args.stage in ('all', 'package'):
        if args.platform != 'android':
            check_configuration(args.platform)
            verify_update_build(args.platform)
        results = stage_android() if args.platform == 'android' else package_desktop.package(args.platform, iscc=args.iscc)
        for path in results:
            print(path.relative_to(ROOT))
    if args.platform != 'android' and args.stage in ('all', 'sign'):
        print(sign(args.platform, args.dart).relative_to(ROOT))


if __name__ == '__main__':
    try:
        main()
    except (RuntimeError, ValueError, OSError, subprocess.CalledProcessError) as error:
        # Native tool output/commands can contain local signing details.
        print(str(error) if isinstance(error, RuntimeError) else
              'Release build/signing failed. Check native toolchain, signing setup and final artifacts.', file=sys.stderr)
        sys.exit(1)
