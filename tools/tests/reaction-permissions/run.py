import argparse
from pathlib import Path
import subprocess
import tempfile

root = Path(__file__).resolve().parents[3]
parser = argparse.ArgumentParser()
parser.add_argument('--source-root', type=Path, default=root)
args = parser.parse_args()

def body(source, marker):
    start = source.index(marker) + len(marker)
    depth = 1
    end = start
    while depth:
        depth += (source[end] == '{') - (source[end] == '}')
        end += 1
    return source[start:end - 1]

rows = (args.source_root / 'packages/ChatUI/Sources/ChatUI/ChatRowItem.swift').read_text()
chips = (args.source_root / 'packages/ChatUI/Sources/ChatUI/ChatReactionsView.swift').read_text()
fixture = Path(__file__).with_name('ReactionPermissionTests.swift').read_text()
fixture = fixture.replace('__CAN_REACT__', body(rows, 'public var canReact: Bool {'))
fixture = fixture.replace('__CHIP_ACTION__', body(chips, 'action: { value, isFilterTag in'))
stars = body(rows, '}, starReact: {').replace(' [weak self] in', '', 1)
fixture = fixture.replace('__STAR_ACTION__', stars)
with tempfile.TemporaryDirectory(prefix='reaction-permissions-') as temp:
    temp = Path(temp)
    (temp / 'main.swift').write_text(fixture)
    binary = temp / 'tests'
    subprocess.run(['swiftc', str(temp / 'main.swift'), '-o', str(binary)], check=True)
    raise SystemExit(subprocess.run([str(binary)]).returncode)
