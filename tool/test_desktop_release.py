"""Focused release integrity checks; no live services or native toolchains."""
import base64
import tempfile
import unittest
import zipfile
import sys
from pathlib import Path
from unittest.mock import patch
import desktop_appcast
import package_desktop
import publish_release


class DesktopReleaseTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        (self.root / 'pubspec.yaml').write_text('version: 0.4.7+16\n')
        for folder in ('android', 'mac', 'window'):
            (self.root / 'release' / folder).mkdir(parents=True)
        for module in (package_desktop, publish_release, desktop_appcast):
            patcher = patch.object(module, 'ROOT', self.root)
            patcher.start()
            self.addCleanup(patcher.stop)
        self.apk = self.root / 'release/android/expense-tracker-0.4.7-arm64-release.apk'
        self.apk.write_bytes(b'test apk')
        for folder, suffix in (('mac', '-macos.dmg'), ('mac', '-macos-update.zip'),
                               ('window', '-windows-x64.zip'), ('window', '-windows-x64-setup.exe')):
            (self.root / 'release' / folder / f'expense-tracker-0.4.7{suffix}').write_bytes(b'test payload')
        self.apk, self.manifest_path, self.manifest = publish_release.artifact()
        self.manifest_path.write_text('{}')

    def assets(self, **kwargs):
        return publish_release.release_assets(self.apk, self.manifest_path, self.manifest, **kwargs)

    def feeds(self):
        desktop_appcast.generate('macos', base64.b64encode(b'x' * 64).decode())
        desktop_appcast.generate('windows', base64.b64encode(b'y' * 48).decode())

    def test_complete_release_checksums_cover_every_platform(self):
        assets = self.assets()
        self.assertEqual(len(assets), 6)
        sums = publish_release.checksums(assets)
        self.assertEqual(len(sums.splitlines()), 6)
        self.assertEqual(self.manifest_path.parent, self.root / 'release/android')
        self.assertEqual({path.parent.name for _, path, _ in assets}, {'android', 'mac', 'window'})
        self.assertEqual(assets[1][0], 'update.json')
        self.assertNotIn('release/', sums)  # GitHub download names stay flat.
        self.apk.write_bytes(b'changed')
        self.assertNotEqual(sums, publish_release.checksums(assets))

    def test_missing_windows_bundle_blocks_publication(self):
        (self.root / 'release/window/expense-tracker-0.4.7-windows-x64.zip').unlink()
        with self.assertRaisesRegex(RuntimeError, 'Missing required'):
            self.assets()

    def test_update_enabled_release_requires_both_feeds(self):
        with self.assertRaisesRegex(RuntimeError, 'Both signed'):
            self.assets(require_feeds=True)
        self.feeds()
        self.assertEqual(len(self.assets(require_feeds=True)), 8)

    def test_prepare_requires_feeds_by_default_and_writes_grouped_metadata(self):
        with patch.object(sys, 'argv', ['publish_release.py', '--prepare']):
            with self.assertRaisesRegex(RuntimeError, 'Both signed'):
                publish_release.main()
            self.feeds()
            publish_release.main()
        sums = self.root / 'release/SHA256SUMS-0.4.7.txt'
        self.assertEqual(len(sums.read_text().splitlines()), 8)
        self.assertIn('  appcast-windows.xml\n', sums.read_text())
        self.assertEqual(publish_release.json.loads(self.manifest_path.read_text()), self.manifest)
        self.assertFalse((self.root / 'release/update-0.4.7.json').exists())

    def test_appcast_payload_size_mismatch_is_rejected(self):
        self.feeds()
        (self.root / 'release/mac/expense-tracker-0.4.7-macos-update.zip').write_bytes(b'changed')
        with self.assertRaisesRegex(RuntimeError, 'does not match'):
            self.assets()

    def test_appcast_native_build_mismatch_is_rejected(self):
        self.feeds()
        self.manifest['version_code'] += 1
        with self.assertRaisesRegex(RuntimeError, 'does not match'):
            self.assets()

    def test_malformed_feed_signature_blocks_publication(self):
        self.feeds()
        path = self.root / 'release/mac/appcast-macos-0.4.7.xml'
        tree = publish_release.ET.parse(path)
        tree.find('./channel/item/enclosure').set(f'{{{desktop_appcast.SPARKLE}}}edSignature', 'not a signature')
        tree.write(path)
        with self.assertRaisesRegex(RuntimeError, 'Malformed desktop updater signature'):
            self.assets()

    def test_appcast_refuses_wrong_signature_and_overwrite(self):
        with self.assertRaises(ValueError):
            desktop_appcast.generate('macos', base64.b64encode(b'short').decode())
        self.feeds()
        with self.assertRaisesRegex(ValueError, 'overwrite'):
            desktop_appcast.generate('macos', base64.b64encode(b'x' * 64).decode())

    def test_windows_zip_contains_native_libraries_and_assets(self):
        for suffix in ('-windows-x64.zip', '-windows-x64-setup.exe'):
            (self.root / 'release/window' / f'expense-tracker-0.4.7{suffix}').unlink()
        source = self.root / 'bundle'
        (source / 'data/flutter_assets').mkdir(parents=True)
        for name in ('expense_tracker.exe', 'flutter_windows.dll', 'plugin.dll', 'data/flutter_assets/a'):
            (source / name).write_bytes(b'test component')

        def compile_installer(command, **kwargs):
            self.assertIn('/DAppVersion=0.4.7', command)
            self.assertIn(f'/DOutputDir={self.root / "release/window"}', command)
            (self.root / 'release/window/expense-tracker-0.4.7-windows-x64-setup.exe').write_bytes(b'test installer')

        with patch.object(package_desktop.platform, 'system', return_value='Windows'), patch.object(package_desktop.subprocess, 'run', side_effect=compile_installer):
            archive, _ = package_desktop.package('windows', source)
        with zipfile.ZipFile(archive) as bundle:
            self.assertTrue({'expense_tracker.exe', 'flutter_windows.dll', 'plugin.dll', 'data/flutter_assets/a'}.issubset(bundle.namelist()))

    def test_macos_packaging_rejects_missing_app(self):
        with patch.object(package_desktop.platform, 'system', return_value='Darwin'):
            with self.assertRaisesRegex(RuntimeError, 'Build the macOS'):
                package_desktop.package('macos')

    def test_macos_packages_directly_into_mac_folder_without_overwriting(self):
        app = self.root / 'expense_tracker.app'
        (app / 'Contents').mkdir(parents=True)
        (app / 'Contents/Info.plist').write_bytes(package_desktop.plistlib.dumps(
            dict(CFBundleShortVersionString='0.4.7', CFBundleVersion='16')))
        folder = self.root / 'release/mac'
        for path in folder.iterdir():
            path.unlink()

        def package_command(command, **kwargs):
            if command[0] == 'hdiutil' or '-c' in command:
                Path(command[-1]).write_bytes(b'packaged app')

        with patch.object(package_desktop.platform, 'system', return_value='Darwin'), patch.object(package_desktop.subprocess, 'run', side_effect=package_command), patch.object(Path, 'symlink_to'):
            paths = package_desktop.package('macos', app)
            self.assertTrue(all(path.parent == folder and path.is_file() for path in paths))
            with self.assertRaisesRegex(RuntimeError, 'overwrite'):
                package_desktop.package('macos', app)


if __name__ == '__main__':
    unittest.main()
