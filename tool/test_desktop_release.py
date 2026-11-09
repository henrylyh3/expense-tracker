"""Focused release integrity checks; no live services or native toolchains."""
import base64
import tempfile
import unittest
import zipfile
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
        (self.root / 'release').mkdir()
        for module in (package_desktop, publish_release, desktop_appcast):
            patcher = patch.object(module, 'ROOT', self.root)
            patcher.start()
            self.addCleanup(patcher.stop)
        self.apk = self.root / 'release/expense-tracker-0.4.7-arm64-release.apk'
        self.apk.write_bytes(b'test apk')
        for suffix in ('-macos.dmg', '-macos-update.zip', '-windows-x64.zip', '-windows-x64-setup.exe'):
            (self.apk.parent / f'expense-tracker-0.4.7{suffix}').write_bytes(b'test payload')
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
        self.apk.write_bytes(b'changed')
        self.assertNotEqual(sums, publish_release.checksums(assets))

    def test_missing_windows_bundle_blocks_publication(self):
        (self.apk.parent / 'expense-tracker-0.4.7-windows-x64.zip').unlink()
        with self.assertRaisesRegex(RuntimeError, 'Missing required'):
            self.assets()

    def test_update_enabled_release_requires_both_feeds(self):
        with self.assertRaisesRegex(RuntimeError, 'Both signed'):
            self.assets(require_feeds=True)
        self.feeds()
        self.assertEqual(len(self.assets(require_feeds=True)), 8)

    def test_appcast_payload_size_mismatch_is_rejected(self):
        self.feeds()
        (self.apk.parent / 'expense-tracker-0.4.7-macos-update.zip').write_bytes(b'changed')
        with self.assertRaisesRegex(RuntimeError, 'does not match'):
            self.assets()

    def test_appcast_refuses_wrong_signature_and_overwrite(self):
        with self.assertRaises(ValueError):
            desktop_appcast.generate('macos', base64.b64encode(b'short').decode())
        self.feeds()
        with self.assertRaisesRegex(ValueError, 'overwrite'):
            desktop_appcast.generate('macos', base64.b64encode(b'x' * 64).decode())

    def test_windows_zip_contains_native_libraries_and_assets(self):
        for suffix in ('-windows-x64.zip', '-windows-x64-setup.exe'):
            (self.apk.parent / f'expense-tracker-0.4.7{suffix}').unlink()
        source = self.root / 'bundle'
        (source / 'data/flutter_assets').mkdir(parents=True)
        for name in ('expense_tracker.exe', 'flutter_windows.dll', 'plugin.dll', 'data/flutter_assets/a'):
            (source / name).write_bytes(b'test component')

        def compile_installer(command, **kwargs):
            self.assertIn('/DAppVersion=0.4.7', command)
            (self.apk.parent / 'expense-tracker-0.4.7-windows-x64-setup.exe').write_bytes(b'test installer')

        with patch.object(package_desktop.platform, 'system', return_value='Windows'), patch.object(package_desktop.subprocess, 'run', side_effect=compile_installer):
            archive, _ = package_desktop.package('windows', source)
        with zipfile.ZipFile(archive) as bundle:
            self.assertTrue({'expense_tracker.exe', 'flutter_windows.dll', 'plugin.dll', 'data/flutter_assets/a'}.issubset(bundle.namelist()))

    def test_macos_packaging_rejects_missing_app(self):
        with patch.object(package_desktop.platform, 'system', return_value='Darwin'):
            with self.assertRaisesRegex(RuntimeError, 'Build the macOS'):
                package_desktop.package('macos')


if __name__ == '__main__':
    unittest.main()
