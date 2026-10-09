#!/usr/bin/env python3
"""Export real Icon Composer renders and assemble a size/appearance proof sheet.

Requires Xcode's Icon Composer (ictool) and Pillow. Run from any directory.
DEVELOPER_DIR selects Xcode; ICTOOL can override the renderer executable.
"""
import os
from pathlib import Path
import subprocess

from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parent
SIZES = (1024, 128, 32, 16)
MODES = ('Default', 'Dark', 'ClearLight', 'ClearDark', 'TintedLight', 'TintedDark')
GENERATIONS = (26, 27)


def main():
    developer = Path(os.environ.get('DEVELOPER_DIR') or subprocess.check_output(
        ['xcode-select', '-p'], text=True).strip())
    renderer = Path(os.environ.get('ICTOOL') or developer.parent /
                    'Applications/Icon Composer.app/Contents/Executables/ictool')
    if not renderer.is_file():
        raise SystemExit('Select Xcode with Icon Composer using DEVELOPER_DIR or set ICTOOL.')
    output = ROOT / 'previews'
    output.mkdir(exist_ok=True)
    for generation in GENERATIONS:
        for mode in MODES:
            for size in SIZES:
                path = output / f'{generation}-{mode}-{size}.png'
                subprocess.run([
                    str(renderer), str(ROOT / 'Yap.icon'), '--export-image',
                    '--output-file', str(path), '--platform', 'macOS',
                    '--rendition', mode, '--width', str(size), '--height', str(size),
                    '--scale', '1', '--design-generation', str(generation),
                    '--tint-color', '0.58', '--tint-strength', '0.5',
                ], check=True, stdout=subprocess.DEVNULL)
            print(f'Rendered macOS {generation}: {mode}', flush=True)

    # Each 1024 image and each small render is pasted at its actual pixel size.
    # The checkerboard is only the sheet's backing, never part of the icon assets.
    column, row = 1080, 1400
    sheet = Image.new('RGB', (column * len(MODES) + 64, row * 2 + 132), '#eeece8')
    draw = ImageDraw.Draw(sheet)
    title = ImageFont.load_default(size=34)
    heading = ImageFont.load_default(size=26)
    label = ImageFont.load_default(size=19)
    draw.text((32, 22), 'Yap — native Icon Composer renders · 1024 / 128 / 32 / 16 px', fill='#242126', font=title)
    draw.text((32, 70), 'Both design generations · Clear and Tinted include light and dark · blue tint example · images shown at 1×', fill='#514b53', font=label)
    for ri, generation in enumerate(GENERATIONS):
        top = 132 + ri * row
        for ci, mode in enumerate(MODES):
            left = 32 + ci * column
            draw.text((left, top), f'macOS {generation} · {mode}', fill='#242126', font=heading)
            box_y = top + 44
            for yy in range(0, 1024, 32):
                for xx in range(0, 1024, 32):
                    fill = '#d5d2d6' if ((xx + yy)//32) % 2 else '#e2dfe3'
                    draw.rectangle((left+xx, box_y+yy, left+xx+31, box_y+yy+31), fill=fill)
            im = Image.open(output / f'{generation}-{mode}-1024.png').convert('RGBA')
            sheet.paste(im, (left, box_y), im)
            draw.text((left, box_y+1036), '1024 px', fill='#514b53', font=label)
            for size, dx in ((128, 0), (32, 208), (16, 320)):
                yy = box_y + 1110
                im = Image.open(output / f'{generation}-{mode}-{size}.png').convert('RGBA')
                sheet.paste(im, (left+dx, yy), im)
                draw.text((left+dx, yy+144), f'{size} px', fill='#514b53', font=label)
    sheet.save(ROOT / 'glass-check.png')
    print('Saved icon/glass-check.png')


if __name__ == '__main__':
    main()
