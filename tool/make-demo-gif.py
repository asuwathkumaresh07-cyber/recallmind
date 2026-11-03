"""Encode screenshots from record-demo.cjs into the README animation."""
from pathlib import Path
from PIL import Image

paths = sorted(Path('.tool-data/demo-frames').glob('*.png'))
if not paths:
    raise SystemExit('Run node tool/record-demo.cjs first.')
frames = []
for path in paths:
    with Image.open(path) as image:
        frames.append(image.convert('RGB').resize((896, 700), Image.Resampling.LANCZOS).quantize(colors=128))
frames[0].save('docs/images/recallmind-demo.gif', save_all=True, append_images=frames[1:], duration=180, loop=0, optimize=True)
print(f'Saved {len(frames)} frames to docs/images/recallmind-demo.gif')
