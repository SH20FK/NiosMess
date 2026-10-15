"""Pin unused Material Symbols axes without removing saved wallpaper glyphs.

Run in the CI checkout before building. --output-dir keeps source assets intact
for local verification. All codepoints, FILL and weight 100..700 are retained.
"""
import argparse
import json
import math
import pathlib
from fontTools.ttLib import TTFont
from fontTools.pens.boundsPen import BoundsPen
from fontTools.varLib.instancer import instantiateVariableFont


def bounds(font, glyph, location):
    if font['glyf'][glyph].numberOfContours == 0:
        return None
    glyphs = font.getGlyphSet(location=location)
    pen = BoundsPen(glyphs)
    glyphs[glyph].draw(pen)
    return pen.bounds


def optimize(source, destination):
    original = TTFont(source, recalcTimestamp=False)
    cmap = original.getBestCmap()
    if not {'GRAD', 'opsz'} <= {axis.axisTag for axis in original['fvar'].axes}:
        raise ValueError('Expected original Material Symbols axes')
    result = instantiateVariableFont(
        original, {'GRAD': 0, 'opsz': 24, 'wght': (100, 400, 700)},
        inplace=False, optimize=True,
    )
    if result.getBestCmap() != cmap:
        raise ValueError('Unicode mapping changed')
    axes = {axis.axisTag: axis for axis in result['fvar'].axes}
    if set(axes) != {'wght', 'FILL'}:
        raise ValueError('Unexpected remaining axes')
    if axes['wght'].minValue != 100 or axes['wght'].maxValue != 700:
        raise ValueError('Supported wallpaper weights changed')
    # Sample original outlines at extremes and the default, not just file size.
    glyphs = list(cmap.values())[::137]
    for weight in (100, 400, 700):
        for fill in (0, 1):
            for glyph in glyphs:
                before = bounds(original, glyph, {'GRAD': 0, 'opsz': 24, 'wght': weight, 'FILL': fill})
                after = bounds(result, glyph, {'wght': weight, 'FILL': fill})
                if before is None or after is None:
                    if before != after:
                        raise ValueError('Empty glyph changed')
                elif not all(math.isclose(a, b, abs_tol=1.0) for a, b in zip(before, after)):
                    raise ValueError('Glyph bounds changed')
    destination.parent.mkdir(parents=True, exist_ok=True)
    temporary = destination.with_suffix('.ttf.tmp')
    result.save(temporary)
    before_size, after_size = source.stat().st_size, temporary.stat().st_size
    # Windows does not allow replacing the source while TTFont holds it open.
    original.close()
    result.close()
    if after_size >= before_size:
        temporary.unlink()
        raise ValueError('Font optimization increased size')
    temporary.replace(destination)
    with TTFont(destination) as verified:
        if verified.getBestCmap() != cmap:
            raise ValueError('Serialized glyph mapping changed')
    return {'font': source.name, 'before': before_size, 'after': after_size,
            'unicode_codepoints': len(cmap), 'outline_checks': len(glyphs) * 6}


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--output-dir', type=pathlib.Path)
    args = parser.parse_args()
    root = pathlib.Path(__file__).resolve().parents[1]
    folder = root / 'assets/fonts/material_symbols'
    results = []
    for source in sorted(folder.glob('MaterialSymbols*.ttf')):
        results.append(optimize(source, (args.output_dir or folder) / source.name))
    if len(results) != 3:
        raise ValueError('Expected all three symbol styles')
    print(json.dumps(results, indent=2))


if __name__ == '__main__':
    main()
