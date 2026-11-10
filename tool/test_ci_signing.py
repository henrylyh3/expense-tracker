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

    def test_personal_requires_updater_keys_only_and_trusted_keeps_certificate_gate(self):
        os.environ['DESKTOP_SIGNING_MODE'] = 'personal'
        for target in ('windows', 'macos'):
            names = ci_signing.required_inputs(target)
            self.assertEqual(len(names), 2)
            os.environ.update({name: 'updater fixture' for name in names})
            with contextlib.redirect_stdout(io.StringIO()):
                ci_signing.require_inputs(target)
        os.environ['DESKTOP_SIGNING_MODE'] = 'trusted'
        with self.assertRaisesRegex(RuntimeError, 'CERTIFICATE'):
            ci_signing.require_inputs('macos')
        os.environ['DESKTOP_SIGNING_MODE'] = 'typo'
        with self.assertRaisesRegex(RuntimeError, 'personal or trusted'):
            ci_signing.required_inputs('windows')

    def test_personal_mac_configuration_checks_keys_without_apple_credentials(self):
        os.environ['DESKTOP_SIGNING_MODE'] = 'personal'
        public = base64.b64encode(b'x' * 32).decode()
        os.environ.update(MACOS_SPARKLE_PUBLIC_KEY=public, MACOS_SPARKLE_PRIVATE_KEY=base64.b64encode(b'y' * 32).decode())
        with patch.object(ci_signing, 'native', return_value=public) as native, contextlib.redirect_stdout(io.StringIO()):
            ci_signing.configure('macos')
        self.assertEqual(native.call_count, 1)
        self.assertEqual(native.call_args.args[0][0], 'swift')
        self.assertFalse(list(self.root.rglob('*.p12')))
        self.assertFalse(list(self.root.rglob('*.p8')))
        self.assertTrue((self.root / 'macos/Runner/Configs/Signing.xcconfig').is_file())

    def test_personal_windows_configuration_checks_keys_without_pfx(self):
        os.environ['DESKTOP_SIGNING_MODE'] = 'personal'
        public = '-----BEGIN PUBLIC KEY-----\nfixture\n-----END PUBLIC KEY-----'
        os.environ.update(WINDOWS_UPDATER_PUBLIC_KEY=public, WINDOWS_UPDATER_PRIVATE_KEY='private fixture', GITHUB_PATH=str(self.root / 'github-path'))
        with patch.object(ci_signing.shutil, 'which', return_value='/tools/openssl'), patch.object(ci_signing, 'native', return_value=public) as native, contextlib.redirect_stdout(io.StringIO()):
            ci_signing.configure('windows')
        self.assertEqual(native.call_count, 1)
        self.assertEqual(native.call_args.args[0][0], '/tools/openssl')
        self.assertFalse(list(self.root.rglob('*.pfx')))
        self.assertFalse(list(self.root.rglob('*.p12')))

    def test_personal_app_and_package_steps_do_not_sign_or_notarize(self):
        os.environ['DESKTOP_SIGNING_MODE'] = 'personal'
        with patch.object(ci_signing, 'native') as native:
            ci_signing.sign_app('windows')
            ci_signing.sign_package('windows')
            ci_signing.sign_package('macos')
            native.assert_not_called()
            ci_signing.sign_app('macos')
            self.assertEqual(native.call_args.args[0][:2], ['codesign', '--verify'])

    def test_release_branch_pushes_always_select_all_native_hosts(self):
        for ref in ('refs/heads/release', 'refs/heads/release/0.4.9', 'refs/heads/release/android/fix'):
            with self.subTest(ref=ref):
                matrix = ci_signing.release_matrix(ref, 'push', 'android')
                self.assertEqual({item['target']: item['os'] for item in matrix['include']}, {
                    'android': 'ubuntu-latest', 'windows': 'windows-latest', 'macos': 'macos-latest'})

    def test_manual_runs_preserve_platform_selection_on_main_and_release(self):
        for ref in ('refs/heads/main', 'refs/heads/release/0.4.9'):
            for target in ('android', 'windows', 'macos', 'all'):
                with self.subTest(ref=ref, target=target):
                    matrix = ci_signing.release_matrix(ref, 'workflow_dispatch', target)
                    self.assertEqual(len(matrix['include']), 3 if target == 'all' else 1)
                    if target != 'all':
                        self.assertEqual(matrix['include'][0]['target'], target)

    def test_unrelated_branches_tags_events_and_invalid_platforms_are_rejected(self):
        for ref, event in (('refs/heads/main', 'push'), ('refs/heads/feature/test', 'push'),
                           ('refs/heads/release-candidate', 'push'), ('refs/tags/v0.4.9', 'workflow_dispatch'),
                           ('refs/heads/release/0.4.9', 'pull_request')):
            with self.subTest(ref=ref, event=event), self.assertRaises(RuntimeError):
                ci_signing.release_matrix(ref, event)
        with self.assertRaisesRegex(RuntimeError, 'Choose android'):
            ci_signing.release_matrix('refs/heads/main', 'workflow_dispatch', 'linux')

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

    def test_dash_placeholders_stop_before_import_and_are_not_mask_commands(self):
        os.environ.update({name: ' - ' for name in ci_signing.REQUIRED['android']})
        output = io.StringIO()
        with contextlib.redirect_stdout(output), patch.object(ci_signing, 'native') as native:
            with self.assertRaisesRegex(RuntimeError, 'ANDROID_KEYSTORE_BASE64'):
                ci_signing.configure('android')
            native.assert_not_called()
        self.assertNotIn('::add-mask::', output.getvalue())
        self.assertFalse((self.root / 'github-env').exists())

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

    def test_personal_export_is_labeled_and_does_not_include_private_files(self):
        os.environ['DESKTOP_SIGNING_MODE'] = 'personal'
        folder = self.root / 'release/android'
        folder.mkdir(parents=True)
        (folder / 'expense-tracker-0.4.8-arm64-release.apk').write_bytes(b'apk fixture')
        (folder / 'private.jks').write_bytes(b'private fixture')
        ci_signing.export('android')
        output = self.root / 'build/release-upload'
        self.assertIn('no', (output / 'PERSONAL-USE.txt').read_text().lower())
        self.assertTrue((output / 'android/expense-tracker-0.4.8-arm64-release.apk').is_file())
        self.assertFalse(list(output.rglob('*.jks')))

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
