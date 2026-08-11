#!/usr/bin/env python3
"""Render the Ballast mark to PNG, from the geometry in IMPLEMENTATION.md §8.

Four corner marks framing a single point. The frame is the session; the point is
the one thing you named. Two rules protect it: the dot stays small relative to the
frame, and at small sizes the arms grow longer as they thicken.

Pillow does not antialias strokes, so everything is drawn at SS× and downsampled.
"""

from PIL import Image, ImageDraw

INK = (0x16, 0x20, 0x2B)
PAPER = (0xE3, 0xE9, 0xEA)
SS = 4  # supersample factor

# render -> (stroke, inset, arm, dot radius), from the §8.3 cuts table
CUTS = {
    1024: (34, 262, 104, 48),
    180: (34, 262, 104, 48),
    120: (36, 262, 106, 50),
    76: (42, 262, 110, 54),
    60: (52, 268, 110, 60),
    40: (58, 280, 120, 68),
    29: (68, 290, 130, 76),
}


def arms(inset, arm):
    """The four corner polylines on the 1024 grid."""
    a, b = inset, 1024 - inset
    a2, b2 = a + arm, b - arm
    return [
        [(a, a2), (a, a), (a2, a)],  # top-left
        [(b2, a), (b, a), (b, a2)],  # top-right
        [(b, b2), (b, b), (b2, b)],  # bottom-right
        [(a2, b), (a, b), (a, b2)],  # bottom-left
    ]


def render(size, stroke, inset, arm, dot, fg, bg):
    canvas = size * SS
    scale = canvas / 1024
    image = Image.new("RGBA", (canvas, canvas), bg + (255,) if bg else (0, 0, 0, 0))
    draw = ImageDraw.Draw(image)

    width = int(round(stroke * scale))
    radius = width / 2

    for polyline in arms(inset, arm):
        points = [(x * scale, y * scale) for x, y in polyline]
        draw.line(points, fill=fg, width=width)
        # Round caps and joins: Pillow has neither, so cap every vertex by hand.
        for x, y in points:
            draw.ellipse([x - radius, y - radius, x + radius, y + radius], fill=fg)

    r = dot * scale
    c = 512 * scale
    draw.ellipse([c - r, c - r, c + r, c + r], fill=fg)

    return image.resize((size, size), Image.LANCZOS)


def main():
    import os
    import sys

    out = sys.argv[1] if len(sys.argv) > 1 else "."
    os.makedirs(out, exist_ok=True)
    stroke, inset, arm, dot = CUTS[1024]

    # Light and dark ship opaque; the tinted slot is composited by the system.
    render(1024, stroke, inset, arm, dot, INK, PAPER).convert("RGB").save(
        f"{out}/icon-light.png")
    render(1024, stroke, inset, arm, dot, PAPER, INK).convert("RGB").save(
        f"{out}/icon-dark.png")
    render(1024, 40, inset, 104, 54, (255, 255, 255), None).save(
        f"{out}/icon-tinted.png")
    print(f"wrote icon-light/dark/tinted.png to {out}")


if __name__ == "__main__":
    main()
