"""Build manual-install ZIPs with one addon directory at each archive root."""
from pathlib import Path
import argparse
import zipfile

root = Path(__file__).resolve().parents[1]
parser = argparse.ArgumentParser()
parser.add_argument('--output', type=Path, default=root / 'local-work' / 'dist')
args = parser.parse_args()
args.output.mkdir(parents=True, exist_ok=True)
for addon in sorted((root / 'addons').iterdir()):
    if not addon.is_dir() or not list(addon.glob('*.toc')):
        continue
    output = args.output / (addon.name + '.zip')
    with zipfile.ZipFile(output, 'w', zipfile.ZIP_DEFLATED) as archive:
        for source in sorted(addon.rglob('*')):
            if source.is_file():
                archive.write(source, source.relative_to(addon.parent).as_posix())
    with zipfile.ZipFile(output) as archive:
        assert archive.testzip() is None
        assert all(name.startswith(addon.name + '/') for name in archive.namelist())
        assert addon.name + '/' + addon.name + '.toc' in archive.namelist()
    print(output)
