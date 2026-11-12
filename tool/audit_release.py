"""Inspect unsigned release APK/AAB without accessing signing secrets."""
import argparse
import hashlib
import json
import struct
import zipfile
from pathlib import Path

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('artifacts', nargs='+', type=Path)
parser.add_argument('--output', type=Path, required=True)
args = parser.parse_args()
reports = []
for path in args.artifacts:
    libraries = []
    with zipfile.ZipFile(path) as archive:
        names = archive.namelist()
        assert not any(n.endswith('kernel_blob.bin') for n in names), 'Debug kernel included'
        assert not any(n.upper().endswith(('.RSA', '.DSA', '.EC')) and n.startswith('META-INF/') for n in names), 'Unexpected JAR signature in unsigned audit'
        prefix = ('base/' if path.suffix == '.aab' else '') + 'assets/flutter_assets/'
        counts = {}
        for language in ['en', 'es', 'de', 'fr', 'zh']:
            manifest = json.loads(archive.read(prefix + 'assets/courses/manifest' + ('' if language == 'en' else '-' + language) + '.json'))
            lessons = [l for s in manifest['sections'] for t in s['themes'] for l in t['lessons']]
            counts[language] = len(lessons)
            for lesson in lessons:
                assert prefix + lesson['asset'] in names
        assert counts == dict(en=72, es=42, de=42, fr=32, zh=32), counts
        for name in names:
            if not name.endswith('.so'):
                continue
            data = archive.read(name)
            assert data[:4] == b'\x7fELF'
            wide = data[4] == 2
            endian = '<' if data[5] == 1 else '>'
            offset = struct.unpack_from(endian + ('Q' if wide else 'I'), data, 32 if wide else 28)[0]
            size, count = struct.unpack_from(endian + 'HH', data, 54 if wide else 42)
            aligns = []
            for i in range(count):
                start = offset + i * size
                if struct.unpack_from(endian + 'I', data, start)[0] == 1:
                    aligns.append(struct.unpack_from(endian + ('Q' if wide else 'I'), data, start + (48 if wide else 28))[0])
            assert aligns
            if wide:
                assert all(a >= 16384 for a in aligns), (name, aligns)
            libraries.append(dict(file=name, bits=64 if wide else 32, loadAlignments=aligns))
        assert any(l['file'].endswith('/libapp.so') for l in libraries)
        assert any(l['file'].endswith('/libflutter.so') for l in libraries)
        # A dependency must not advertise an ABI without the actual app engine.
        for folder in {l['file'].rsplit('/', 1)[0] for l in libraries}:
            assert folder + '/libflutter.so' in names, ('Missing engine', folder)
            assert folder + '/libapp.so' in names, ('Missing app', folder)
    reports.append(dict(file=path.name, bytes=path.stat().st_size,
                        sha256=hashlib.sha256(path.read_bytes()).hexdigest(),
                        lessons=counts, libraries=libraries,
                        status='UNSIGNED AUDIT — not installable or publishable'))
args.output.parent.mkdir(parents=True, exist_ok=True)
args.output.write_text(json.dumps(reports, indent=2) + '\n', encoding='utf-8')
print(json.dumps([dict(file=r['file'], bytes=r['bytes'], sha256=r['sha256']) for r in reports]))
