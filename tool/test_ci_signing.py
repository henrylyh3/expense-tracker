"""Focused CI credential handling and artifact-isolation tests; no real secrets."""
import base64
import contextlib
import io
import json
import os
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

import ci_signing
import package_desktop


class CiSigningTests(unittest.TestCase):
    def setUp(self):
        temp = tempfile.TemporaryDirectory()
        self.addCleanup(temp.cleanup)
        self.root = Path(temp.name)
        (self.root / 'pubspec.yaml').write_text('version: 0.4.8+17\n')
        for module in (ci_signing, package_desktop):
            patcher = patch.object(module, 'ROOT', self.root)
            patcher.start()
            self.addCleanup(patcher.stop)
        self.env = {'GITHUB_ACTIONS': 'true', 'RUNNER_TEMP': str(self.root),
                    'GITHUB_ENV': str(self.root / 'github-env')}
        patcher = patch.dict(os.environ, self.env, clear=True)
        patcher.start()
        self.addCleanup(patcher.stop)

    def android(self):
        return {'ANDROID_KEYSTORE_BASE64': base64.b64encode(b'original keystore fixture').decode(),
                'ANDROID_STORE_PASSWORD': 'test-password', 'ANDROID_KEY_ALIAS': 'existing-alias',
                'ANDROID_KEY_PASSWORD': 'test-key-password'}

    def test_missing_inputs_report_names_without_creating_files(self):
        with self.assertRaisesRegex(RuntimeError, 'ANDROID_KEYSTORE_BASE64') as error:
            ci_signing.configure('android')
        self.assertNotIn('test-password', str(error.exception))
        self.assertFalse((self.root / 'github-env').exists())

    def test_variable_credentials_are_masked_with_multiline_escaping(self):
        os.environ.update(self.android())
        os.environ['ANDROID_KEY_PASSWORD'] = 'line1%\r\nline2'
        output = io.StringIO()
        with contextlib.redirect_stdout(output):
            ci_signing.require_inputs('android')
        self.assertIn('::add-mask::line1%25%0D%0Aline2\n', output.getvalue())
        self.assertEqual(output.getvalue().count('::add-mask::'), 4)

    def test_java_properties_preserve_unicode_backslash_and_line_breaks(self):
        self.assertEqual(ci_signing.property_value(' a\\b\n中😀='), r'\ a\\b\u000a\u4e2d\ud83d\ude00\=')

    def test_android_restores_original_bytes_and_cleanup_removes_credentials(self):
        os.environ.update(self.android())
        ci_signing.configure('android')
        settings = dict(line.split('=', 1) for line in (self.root / 'github-env').read_text().splitlines())
        work = Path(settings['SIGNING_WORK_DIRECTORY'])
        self.assertEqual((work / 'release.jks').read_bytes(), b'original keystore fixture')
        properties = self.root / 'android/key.properties'
        self.assertIn('keyAlias=existing-alias\n', properties.read_text())
        if os.name != 'nt':
            self.assertEqual(properties.stat().st_mode & 0o777, 0o600)
        os.environ.update(settings)
        ci_signing.cleanup()
        self.assertFalse(work.exists())
        self.assertFalse(properties.exists())

    def test_configuration_cannot_install_credentials_on_local_machine(self):
        os.environ.update(self.android())
        os.environ.pop('GITHUB_ACTIONS')
        with self.assertRaisesRegex(RuntimeError, 'restricted to GitHub Actions'):
            ci_signing.configure('android')

    def test_current_output_cleanup_preserves_predecessor_and_other_platform(self):
        folder = self.root / 'release/android'
        folder.mkdir(parents=True)
        previous = folder / 'expense-tracker-0.4.6-arm64-release.apk'
        current = folder / 'expense-tracker-0.4.8-arm64-release.apk'
        other = self.root / 'release/window/expense-tracker-0.4.8-windows-x64.zip'
        other.parent.mkdir(parents=True)
        for path in (previous, current, other):
            path.write_bytes(b'fixture')
        ci_signing.clear_outputs('android')
        self.assertTrue(previous.exists())
        self.assertTrue(other.exists())
        self.assertFalse(current.exists())

    def test_export_whitelist_never_includes_credentials_or_old_releases(self):
        folder = self.root / 'release/android'
        folder.mkdir(parents=True)
        (folder / 'expense-tracker-0.4.8-arm64-release.apk').write_bytes(b'current apk')
        (folder / 'expense-tracker-0.4.6-arm64-release.apk').write_bytes(b'old apk')
        (folder / 'dsa_priv.pem').write_text('private material fixture')
        ci_signing.export('android')
        names = [path.relative_to(self.root / 'build/release-upload').as_posix()
                 for path in (self.root / 'build/release-upload').rglob('*') if path.is_file()]
        self.assertEqual(names, ['android/expense-tracker-0.4.8-arm64-release.apk'])

    def test_private_material_in_public_variable_is_rejected_before_import(self):
        os.environ.update({name: 'fixture' for name in ci_signing.REQUIRED['windows']})
        os.environ['WINDOWS_UPDATER_PUBLIC_KEY'] = '-----BEGIN PUBLIC KEY-----\n-----BEGIN PRIVATE KEY-----'
        with patch.object(ci_signing, 'native') as native:
            with self.assertRaisesRegex(RuntimeError, 'only a PEM public key'):
                ci_signing.configure('windows')
            native.assert_not_called()

    def test_mac_private_public_mismatch_blocks_certificate_import(self):
        os.environ.update({name: 'fixture' for name in ci_signing.REQUIRED['macos']})
        os.environ['MACOS_SPARKLE_PUBLIC_KEY'] = base64.b64encode(b'x' * 32).decode()
        os.environ['MACOS_SPARKLE_PRIVATE_KEY'] = base64.b64encode(b'y' * 32).decode()
        with patch.object(ci_signing, 'native', return_value='different-public-key') as native:
            with self.assertRaisesRegex(RuntimeError, 'private/public keys do not match'):
                ci_signing.configure('macos')
            self.assertEqual(native.call_count, 1)
            self.assertEqual(native.call_args.args[0][0], 'swift')

    def test_export_rejects_missing_finalized_appcast(self):
        folder = self.root / 'release/window'
        folder.mkdir(parents=True)
        for suffix in ('-windows-x64.zip', '-windows-x64-setup.exe'):
            (folder / f'expense-tracker-0.4.8{suffix}').write_bytes(b'fixture')
        with self.assertRaisesRegex(RuntimeError, 'Missing finalized artifact'):
            ci_signing.export('windows')
        self.assertFalse((self.root / 'build/release-upload').exists())

    def test_mac_signing_preserves_helper_entitlements_without_deep_signing(self):
        os.environ['SIGNING_WORK_DIRECTORY'] = str(self.root)
        os.environ['MACOS_CODESIGN_IDENTITY'] = 'Developer ID Application: Test Identity'
        ci_signing.save_state(self.root, {'keychain': str(self.root / 'temporary.keychain-db')})
        with patch.object(ci_signing, 'native') as native:
            ci_signing.mac_sign(self.root / 'Downloader.xpc', preserve=True)
            command = native.call_args.args[0]
            self.assertIn('--preserve-metadata=entitlements', command)
            self.assertIn('runtime', command)
            self.assertNotIn('--deep', command)
            ci_signing.mac_sign(self.root / 'installer.dmg')
            self.assertNotIn('--options', native.call_args.args[0])


if __name__ == '__main__':
    unittest.main()
