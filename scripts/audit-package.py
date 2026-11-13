#!/usr/bin/env python3
"""No dependencies: package relationship checks, not a replacement for full schema validation."""
import json
import math
import re
import sys
import uuid
from pathlib import Path

def load(path):
    return json.loads(path.read_text(encoding='utf-8'))

def check(path):
    manifest = load(path / 'manifest.json')
    assert manifest['format'] == 'org.opennotebook.notebook' and manifest['schemaVersion'] in (1,2,3,4)
    uuid.UUID(manifest['id'])
    seen_sections, seen_pages = set(), set()
    for section in manifest['sections']:
        sid = uuid.UUID(section['id'])
        assert sid not in seen_sections, 'duplicate section'
        seen_sections.add(sid)
        for pid in section['pageIDs']:
            key = uuid.UUID(pid)
            assert key not in seen_pages, 'duplicate page'
            seen_pages.add(key)
            page = load(path / 'pages' / (str(key) + '.json'))
            assert uuid.UUID(page['id']) == key, 'mismatched page ID'
            seen_elements = set()
            for element in page['elements']:
                eid = uuid.UUID(element['id'])
                assert eid not in seen_elements, 'duplicate element'
                seen_elements.add(eid)
                frame = element['frame']
                assert all(isinstance(frame[k], (int, float)) and math.isfinite(frame[k]) for k in ['x','y','width','height'])
                assert frame['width'] >= 0 and frame['height'] >= 0
                if 'minimumHeight' in element:
                    assert math.isfinite(element['minimumHeight']) and 0 <= element['minimumHeight'] <= 1000000
                if 'tableColumnWidths' in element:
                    widths = element['tableColumnWidths']
                    assert element['content']['type'] == 'table'
                    assert len(widths) == len(element['content']['rows'][0])
                    assert all(math.isfinite(w) and 0 < w <= 1000000 for w in widths)
                content = element['content']
                assert content['type'] in ('text','richText','ink','image','table','attachment')
                if content['type'] == 'richText':
                    value = content['value']
                    length = len(value['text'].encode('utf-16-le')) // 2
                    assert len(value['runs']) <= 100000
                    formats = [value['defaultFormat']]
                    for run in value['runs']:
                        assert isinstance(run['location'], int) and isinstance(run['length'], int)
                        assert run['location'] >= 0 and run['length'] > 0 and run['location'] + run['length'] <= length
                        formats.append(run['format'])
                    for style in formats:
                        assert style['fontName'] and 6 <= style['fontSize'] <= 288
                        assert not style.get('highlightHex') or re.fullmatch(r'#[0-9a-fA-F]{6}', style['highlightHex'])
                        assert re.fullmatch(r'#[0-9a-fA-F]{6}', style['colorHex'])
                        assert not style.get('link') or re.match(r'^(https?|mailto):', style['link'], re.I)
                if content['type'] == 'ink':
                    for stroke in content['strokes']:
                        uuid.UUID(stroke['id'])
                        assert stroke['width'] > 0 and math.isfinite(stroke['width'])
                        assert 0 <= stroke.get('opacity', 1) <= 1
                        for point in stroke['points']:
                            assert all(math.isfinite(point[k]) for k in ('x', 'y', 'pressure'))
                            assert 0 <= point['pressure'] <= 1
                if content['type'] == 'table':
                    rows = content['rows']
                    assert rows and rows[0] and all(len(row) == len(rows[0]) for row in rows), 'ragged table'
                    assert len(rows) * len(rows[0]) <= 20000
                if content['type'] in ('image','attachment'):
                    name = content['mediaName']
                    assert name not in ('', '.', '..') and '/' not in name and '\\' not in name
                    assert (path / 'media' / name).is_file()
    actual = {uuid.UUID(file.stem) for file in (path / 'pages').glob('*.json')}
    assert actual == seen_pages, 'missing/orphan page'
    return len(seen_pages)

if __name__ == '__main__':
    path = Path(sys.argv[1]) if len(sys.argv) == 2 else Path(__file__).resolve().parents[1] / 'examples/Welcome.onbook'
    print(f'Package relationships pass: {check(path)} page(s)')
