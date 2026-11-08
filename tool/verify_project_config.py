"""Source configuration checks. Does not substitute for inspecting signed artifacts."""
from pathlib import Path
import plistlib
import re
import xml.etree.ElementTree as ET

ROOT = Path(__file__).resolve().parents[1]
ANDROID = '{http://schemas.android.com/apk/res/android}'


def main():
    pubspec = (ROOT / 'pubspec.yaml').read_text()
    version = re.search(r'^version:\s*([^\s#]+)', pubspec, re.MULTILINE).group(1)
    info = (ROOT / 'lib/core/app_info.dart').read_text()
    default = re.search(r"defaultValue:\s*'([^']+)'", info).group(1)
    assert version == default, 'Align core/app_info.dart backup/About version with pubspec.yaml.'

    manifest = ET.parse(ROOT / 'android/app/src/main/AndroidManifest.xml').getroot()
    denied = {'android.permission.MANAGE_EXTERNAL_STORAGE',
              'android.permission.READ_EXTERNAL_STORAGE', 'android.permission.WRITE_EXTERNAL_STORAGE'}
    assert any(item.attrib.get(ANDROID + 'name') == 'android.permission.INTERNET' for item in manifest.findall('uses-permission')), 'Peer sharing requires INTERNET permission.'
    permissions = {item.attrib.get(ANDROID + 'name') for item in manifest.findall('uses-permission')}
    assert not permissions & denied, 'Release source requests network or broad storage permission.'
    app = manifest.find('application')
    assert app.attrib.get(ANDROID + 'allowBackup') == 'false', 'Internal ledger must exclude automatic backup.'
    for attr, expected in [('fullBackupContent', '@xml/backup_rules'), ('dataExtractionRules', '@xml/data_extraction_rules')]:
        assert app.attrib.get(ANDROID + attr) == expected, f'Missing Android {attr} configuration.'
    old_rules = ET.parse(ROOT / 'android/app/src/main/res/xml/backup_rules.xml').getroot()
    new_rules = ET.parse(ROOT / 'android/app/src/main/res/xml/data_extraction_rules.xml').getroot()
    for rule in [old_rules, new_rules.find('cloud-backup'), new_rules.find('device-transfer')]:
        assert rule is not None and any(item.attrib == {'domain': 'root', 'path': '.'} for item in rule.findall('exclude')), 'Missing root backup/transfer exclusion.'

    with (ROOT / 'ios/Runner/Info.plist').open('rb') as file:
        ios = plistlib.load(file)
    assert not ios.get('UIFileSharingEnabled', False), 'Do not expose internal financial files through file sharing.'
    with (ROOT / 'ios/Runner/PrivacyInfo.xcprivacy').open('rb') as file:
        privacy = plistlib.load(file)
    assert privacy['NSPrivacyTracking'] is False and not privacy['NSPrivacyCollectedDataTypes'], 'Re-review privacy disclosures if app data collection changes.'
    print(f'Project source configuration passed (app {version}). Inspect merged permissions and privacy reports on release artifacts separately.')


if __name__ == '__main__':
    main()
