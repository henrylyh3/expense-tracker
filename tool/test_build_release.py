"""Focused checks for release activation, signing gates and APK continuity."""
import base64
import json
import os
import subprocess
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

import build_release
import desktop_appcast
import package_desktop


class BuildReleaseTests(unittest.TestCase):
    def setUp(self):
        mode = patch.dict(os.environ, {'DESKTOP_SIGNING_MODE': 'trusted'})
        mode.start()
        self.addCleanup(mode.stop)
        temp = tempfile.TemporaryDirectory()
        self.addCleanup(temp.cleanup)
        self.root = Path(temp.name)
        (self.root / 'pubspec.yaml').write_text('version: 0.4.8+17\n')
        for module in (build_release, desktop_appcast, package_desktop):
            patcher = patch.object(module, 'ROOT', self.root)
            patcher.start()
            self.addCleanup(patcher.stop)

    def mac_key(self):
        config = self.root / 'macos/Runner/Configs/Signing.xcconfig'
        config.parent.mkdir(parents=True)
        config.write_text('SPARKLE_PUBLIC_ED_KEY = ' + base64.b64encode(b'x' * 32).decode() + '\n')

    def test_missing_signing_configuration_blocks_build_before_commands(self):
        with patch.object(build_release.platform, 'system', return_value='Darwin'), patch.object(build_release, 'run') as run:
            for target in ('macos', 'android'):
                with self.subTest(target=target), self.assertRaises(RuntimeError):
                    build_release.build(target, 'flutter')
            run.assert_not_called()

    def test_desktop_build_enables_correct_feed_after_focused_checks(self):
        self.mac_key()
        sdk = json.dumps(dict(channel='stable', frameworkVersion='3.47.9', repositoryUrl='https://github.com/flutter/flutter.git'))
        with patch.object(build_release.platform, 'system', return_value='Darwin'), patch.object(build_release, 'run', return_value=subprocess.CompletedProcess([], 0, stdout=sdk)) as run:
            build_release.build('macos', 'flutter')
        commands = [call.args[0] for call in run.call_args_list]
        self.assertEqual(commands[2], ['flutter', 'analyze', '--no-pub'])
        self.assertEqual(commands[3], ['flutter', 'test', '--no-pub', *build_release.FOCUSED_TESTS])
        self.assertIn('--dart-define=DESKTOP_UPDATE_SIGNING_CONFIGURED=true', commands[4])
        self.assertIn('--dart-define=DESKTOP_UPDATE_FEED_URL=https://github.com/henrylyh3/expense-tracker/releases/latest/download/appcast-macos.xml', commands[4])

    def test_prerelease_sdk_cannot_produce_release(self):
        self.mac_key()
        sdk = json.dumps(dict(channel='stable', frameworkVersion='3.48.0-0.5.pre', repositoryUrl='https://github.com/flutter/flutter.git'))
        with patch.object(build_release.platform, 'system', return_value='Darwin'), patch.object(build_release, 'run', return_value=subprocess.CompletedProcess([], 0, stdout=sdk)) as run:
            with self.assertRaisesRegex(RuntimeError, 'official stable'):
                build_release.build('macos', 'flutter')
            self.assertEqual(run.call_count, 1)

    def windows_payload(self):
        (self.root / 'dsa_pub.pem').write_text('-----BEGIN PUBLIC KEY-----\ntest public key\n-----END PUBLIC KEY-----\n')
        (self.root / 'dsa_priv.pem').write_text('test-only signing fixture')
        folder = self.root / 'release/window'
        folder.mkdir(parents=True)
        (folder / 'expense-tracker-0.4.8-windows-x64-setup.exe').write_bytes(b'test payload')
        config = self.root / 'windows/flutter/ephemeral/generated_config.cmake'
        config.parent.mkdir(parents=True)
        defines = ','.join(base64.b64encode(value.encode()).decode() for value in build_release.update_defines('windows'))
        config.write_text(f'list(APPEND FLUTTER_TOOL_ENVIRONMENT "DART_DEFINES={defines}")\n')
        return folder

    def test_validation_build_cannot_be_finalized_as_update_enabled(self):
        folder = self.windows_payload()
        (self.root / 'windows/flutter/ephemeral/generated_config.cmake').write_text('')
        with patch.object(build_release.platform, 'system', return_value='Windows'), patch.object(build_release, 'run') as run:
            with self.assertRaisesRegex(RuntimeError, 'no configured update feed'):
                build_release.sign('windows', 'dart')
            run.assert_not_called()
        self.assertFalse(list(folder.glob('appcast*')))

    def test_failed_authenticode_verification_cannot_generate_feed(self):
        folder = self.windows_payload()
        with patch.object(build_release.platform, 'system', return_value='Windows'), patch.object(build_release, 'run', side_effect=subprocess.CalledProcessError(1, 'verification')):
            with self.assertRaises(subprocess.CalledProcessError):
                build_release.sign('windows', 'dart')
        self.assertFalse(list(folder.glob('appcast*')))

    def test_private_key_material_cannot_be_embedded_in_windows_build(self):
        self.windows_payload()
        key = self.root / 'dsa_pub.pem'
        key.write_text(key.read_text() + '-----BEGIN DSA PRIVATE KEY-----\n')
        with patch.object(build_release.platform, 'system', return_value='Windows'), patch.object(build_release, 'run') as run:
            with self.assertRaisesRegex(RuntimeError, 'never embed private'):
                build_release.build('windows', 'flutter')
            run.assert_not_called()

    def test_signing_uses_native_signature_and_platform_folder(self):
        folder = self.windows_payload()
        signature = base64.b64encode(b'x' * 48).decode()
        output = f'sparkle:dsaSignature="{signature}" length="0"'
        with patch.object(build_release.platform, 'system', return_value='Windows'), patch.object(build_release, 'run', return_value=subprocess.CompletedProcess([], 0, stdout=output)) as run:
            feed = build_release.sign('windows', 'dart')
        self.assertEqual(feed, folder / 'appcast-windows-0.4.8.xml')
        self.assertIn(signature, feed.read_text())
        self.assertEqual(run.call_args.args[0][:3], ['dart', 'run', 'auto_updater:sign_update'])
        self.assertEqual(run.call_count, 3)  # App + installer verification, then signing.

    def test_personal_windows_still_signs_updates_without_authenticode_gate(self):
        folder = self.windows_payload()
        signature = base64.b64encode(b'x' * 48).decode()
        with patch.dict(os.environ, {'DESKTOP_SIGNING_MODE': 'personal'}), patch.object(build_release.platform, 'system', return_value='Windows'), patch.object(build_release, 'run', return_value=subprocess.CompletedProcess([], 0, stdout=f'sparkle:dsaSignature="{signature}"')) as run:
            feed = build_release.sign('windows', 'dart')
        self.assertTrue(feed.is_file())
        self.assertEqual(run.call_count, 1)
        self.assertEqual(run.call_args.args[0][:3], ['dart', 'run', 'auto_updater:sign_update'])

    def test_personal_update_signing_failure_cannot_create_feed(self):
        folder = self.windows_payload()
        with patch.dict(os.environ, {'DESKTOP_SIGNING_MODE': 'personal'}), patch.object(build_release.platform, 'system', return_value='Windows'), patch.object(build_release, 'run', side_effect=subprocess.CalledProcessError(1, 'updater signing failed')):
            with self.assertRaises(subprocess.CalledProcessError):
                build_release.sign('windows', 'dart')
        self.assertFalse(list(folder.glob('appcast*')))

    def apk_source(self):
        source = self.root / 'build/app/outputs/flutter-apk/app-arm64-v8a-release.apk'
        source.parent.mkdir(parents=True)
        source.write_bytes(b'new signed apk')
        previous = self.root / 'release/android/expense-tracker-0.4.6-arm64-release.apk'
        previous.parent.mkdir(parents=True)
        previous.write_bytes(b'previous signed apk')

    def apk_result(self, command, capture=False, old_digest='a' * 64, old_code=2015):
        previous = '0.4.6' in command[-1]
        if 'verify' in command:
            output = 'Signer #1 certificate SHA-256 digest: ' + (old_digest if previous else 'a' * 64)
        else:
            code, name = (old_code, '0.4.6') if previous else (2017, '0.4.8')
            output = f"package: name='com.example.expense_tracker' versionCode='{code}' versionName='{name}'\nnative-code: 'arm64-v8a'\n"
        return subprocess.CompletedProcess(command, 0, stdout=output)

    def test_apksigner_sdk_range_labels_keep_strict_certificate_identity(self):
        digest = 'a' * 64
        self.assertEqual(build_release.apk_signers('Signer #1 certificate SHA-256 digest: ' + digest), {digest})
        sdk_output = 'Signer (minSdkVersion=33, maxSdkVersion=2147483647) certificate SHA-256 digest: ' + digest.upper()
        sdk_output += '\nSource Stamp Signer certificate SHA-256 digest: ' + 'b' * 64
        self.assertEqual(build_release.apk_signers(sdk_output), {digest})
        self.assertFalse(build_release.apk_signers('Signer #1 certificate SHA-256 digest: short'))
        self.assertFalse(build_release.apk_signers('Source Stamp Signer certificate SHA-256 digest: ' + digest))

    def test_v31_signer_can_stage_with_unchanged_previous_certificate(self):
        self.apk_source()
        def result(command, **kwargs):
            result = self.apk_result(command, **kwargs)
            if 'verify' in command and '0.4.6' not in command[-1]:
                result.stdout = result.stdout.replace('Signer #1', 'Signer (minSdkVersion=33, maxSdkVersion=2147483647)')
            return result
        with patch.object(build_release, 'android_tools', return_value=(Path('apksigner'), Path('aapt'))), patch.object(build_release, 'run', side_effect=result):
            output = build_release.stage_android()
        self.assertEqual(len(output), 1)
        self.assertEqual(output[0].read_bytes(), b'new signed apk')

    def test_apk_signer_change_or_non_increasing_code_blocks_staging(self):
        self.apk_source()
        with patch.object(build_release, 'android_tools', return_value=(Path('apksigner'), Path('aapt'))):
            for digest, code in [('b' * 64, 2015), ('a' * 64, 2017)]:
                with self.subTest(digest=digest, code=code), patch.object(build_release, 'run', side_effect=lambda command, **kwargs: self.apk_result(command, old_digest=digest, old_code=code)):
                    with self.assertRaisesRegex(RuntimeError, 'previous release signer'):
                        build_release.stage_android()
        self.assertFalse((self.root / 'release/android/expense-tracker-0.4.8-arm64-release.apk').exists())

    def test_verified_apk_staged_without_overwriting_previous_release(self):
        self.apk_source()
        with patch.object(build_release, 'android_tools', return_value=(Path('apksigner'), Path('aapt'))), patch.object(build_release, 'run', side_effect=self.apk_result):
            [path] = build_release.stage_android()
            self.assertEqual(path.parent, self.root / 'release/android')
            self.assertEqual(path.read_bytes(), b'new signed apk')
            with self.assertRaisesRegex(RuntimeError, 'overwrite'):
                build_release.stage_android()
        self.assertEqual((path.parent / 'expense-tracker-0.4.6-arm64-release.apk').read_bytes(), b'previous signed apk')

    def test_apk_with_wrong_package_version_or_abi_cannot_be_staged(self):
        self.apk_source()
        for before, after in [("com.example.expense_tracker", "com.other.app"),
                              ("versionName='0.4.8'", "versionName='0.4.7'"),
                              ("native-code: 'arm64-v8a'", "native-code: 'x86_64'")]:
            def result(command, **kwargs):
                value = self.apk_result(command)
                value.stdout = value.stdout.replace(before, after)
                return value
            with self.subTest(after=after), patch.object(build_release, 'android_tools', return_value=(Path('apksigner'), Path('aapt'))), patch.object(build_release, 'run', side_effect=result):
                with self.assertRaisesRegex(RuntimeError, 'architecture is incorrect'):
                    build_release.stage_android()
        self.assertFalse((self.root / 'release/android/expense-tracker-0.4.8-arm64-release.apk').exists())

    def test_mac_ci_signing_passes_private_key_by_file_path(self):
        self.mac_key()
        public = base64.b64encode(b'x' * 32).decode()
        app = self.root / 'build/macos/Build/Products/Release/expense_tracker.app'
        (app / 'Contents').mkdir(parents=True)
        (app / 'Contents/Info.plist').write_bytes(package_desktop.plistlib.dumps({'SUPublicEDKey': public}))
        config = self.root / 'macos/Flutter/ephemeral/Flutter-Generated.xcconfig'
        config.parent.mkdir(parents=True)
        defines = ','.join(base64.b64encode(value.encode()).decode() for value in build_release.update_defines('macos'))
        config.write_text('DART_DEFINES=' + defines + '\n')
        folder = self.root / 'release/mac'
        folder.mkdir(parents=True)
        (folder / 'expense-tracker-0.4.8-macos-update.zip').write_bytes(b'test payload')
        key = self.root / 'private-key.txt'
        key.write_text('private-key-fixture-never-passed-inline')
        signature = base64.b64encode(b'x' * 64).decode()
        output = f'sparkle:edSignature="{signature}" length="12"'
        with patch.object(build_release.platform, 'system', return_value='Darwin'), patch.dict(build_release.os.environ, {'SPARKLE_PRIVATE_KEY_FILE': str(key)}), patch.object(build_release, 'run', return_value=subprocess.CompletedProcess([], 0, stdout=output)) as run:
            build_release.sign('macos', 'dart')
        command = run.call_args.args[0]
        self.assertEqual(command[-2:], ['--ed-key-file', str(key)])
        self.assertNotIn(key.read_text(), command)


if __name__ == '__main__':
    unittest.main()
