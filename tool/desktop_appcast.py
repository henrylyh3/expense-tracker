"""Create an appcast from a final native payload and its externally made signature."""
import argparse
import base64
import xml.etree.ElementTree as ET
from pathlib import Path
from package_desktop import ROOT, PLATFORM_FOLDERS, version

SPARKLE = 'http://www.andymatuschak.org/xml-namespaces/sparkle'
ET.register_namespace('sparkle', SPARKLE)


def generate(target, signature):
    name, build = version()
    raw = base64.b64decode(signature, validate=True)
    if target == 'macos' and len(raw) != 64:
        raise ValueError('Expected a 64-byte EdDSA signature from sign_update.')
    if target == 'windows' and not 40 <= len(raw) <= 128:
        raise ValueError('Expected a DSA signature from sign_update.')
    suffix = '-macos-update.zip' if target == 'macos' else '-windows-x64-setup.exe'
    payload = ROOT / 'release' / PLATFORM_FOLDERS[target] / f'expense-tracker-{name}{suffix}'
    if not payload.is_file() or payload.stat().st_size == 0:
        raise ValueError('Package and sign the final payload first.')
    rss = ET.Element('rss', version='2.0')
    channel = ET.SubElement(rss, 'channel')
    ET.SubElement(channel, 'title').text = f'Expense Tracker {target}'
    item = ET.SubElement(channel, 'item')
    ET.SubElement(item, 'title').text = f'Expense Tracker {name}'
    attrs = {
        'url': f'https://github.com/henrylyh3/expense-tracker/releases/download/v{name}/{payload.name}',
        'length': str(payload.stat().st_size),
        'type': 'application/octet-stream',
        f'{{{SPARKLE}}}version': build if target == 'macos' else f'{name}+{build}',
        f'{{{SPARKLE}}}shortVersionString': name,
        f'{{{SPARKLE}}}os': 'macos' if target == 'macos' else 'windows',
        f'{{{SPARKLE}}}' + ('edSignature' if target == 'macos' else 'dsaSignature'): signature,
    }
    ET.SubElement(item, 'enclosure', attrs)
    path = payload.parent / f'appcast-{target}-{name}.xml'
    if path.exists():
        raise ValueError('Refusing to overwrite an appcast. Remove the unpublished file explicitly first.')
    ET.indent(rss)
    ET.ElementTree(rss).write(path, encoding='utf-8', xml_declaration=True)
    return path


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('platform', choices=['macos', 'windows'])
    parser.add_argument('--signature', required=True, help='Public signature emitted by auto_updater:sign_update')
    args = parser.parse_args()
    print(generate(args.platform, args.signature).relative_to(ROOT))
