"""iPad App Store screenshots (2048x2732, 12.9" slot) from the real iPad renders."""
import os, sys
sys.path.insert(0, os.path.dirname(__file__))
from PIL import Image, ImageDraw
import make_shots as m  # shared helpers: font, emoji, rounded, shadow, tile, wrap

W, H = 2048, 2732
ROOT = m.ROOT
RAW = f'{ROOT}/tool/screenshots/out'
OUT = f'{ROOT}/docs/screenshots'


def status_bar(shot):
    """Draw an iPad status bar into the 48px top inset of the render."""
    d = ImageDraw.Draw(shot)
    d.text((40, 32), '9:41  Tue Oct 6', font=m.font(26, 'Semibold'), fill=(0, 0, 0), anchor='lm')
    x, base = 1870, 42
    for i, h in enumerate([8, 12, 16, 20]):
        d.rounded_rectangle([x + i * 9, base - h, x + i * 9 + 6, base], 2, fill=(0, 0, 0))
    cx, cy = 1932, 42
    for r in (20, 13, 6):
        d.arc([cx - r, cy - r, cx + r, cy + r], 225, 315, fill=(0, 0, 0), width=4)
    bx, by = 1960, 23
    d.rounded_rectangle([bx, by, bx + 48, by + 22], 6, outline=(0, 0, 0), width=3)
    d.rounded_rectangle([bx + 5, by + 5, bx + 43, by + 17], 3, fill=(0, 0, 0))
    d.rounded_rectangle([bx + 50, by + 7, bx + 54, by + 15], 2, fill=(0, 0, 0))
    return shot


def ipad(shot, sw):
    s = sw / shot.width
    sh = int(shot.height * s)
    screen = shot.resize((sw, sh), Image.LANCZOS).convert('RGBA')
    r = 40
    mask = Image.new('L', screen.size, 0)
    ImageDraw.Draw(mask).rounded_rectangle([0, 0, sw - 1, sh - 1], r, fill=255)
    screen.putalpha(mask)
    bez = 38
    frame = m.rounded((sw + bez * 2, sh + bez * 2), r + bez, (24, 26, 25, 255))
    ImageDraw.Draw(frame).rounded_rectangle([1, 1, frame.width - 2, frame.height - 2], r + bez, outline=(70, 74, 72), width=3)
    frame.alpha_composite(screen, (bez, bez))
    cx = frame.width // 2  # front camera in the bezel
    ImageDraw.Draw(frame).ellipse([cx - 7, bez // 2 - 7, cx + 7, bez // 2 + 7], fill=(45, 48, 50))
    return frame


def make(name, raw, line1, line2, sub, tiles, corners):
    c = Image.new('RGBA', (W, H))
    top, bot = (244, 247, 238), (255, 255, 255)
    d = ImageDraw.Draw(c)
    for y in range(H):
        t = y / H
        d.line([(0, y), (W, y)], fill=tuple(int(top[i] + (bot[i] - top[i]) * t) for i in range(3)))

    icon = Image.open(m.ICON).convert('RGBA').resize((132, 132), Image.LANCZOS)
    mk = Image.new('L', icon.size, 0)
    ImageDraw.Draw(mk).rounded_rectangle([0, 0, 131, 131], 30, fill=255)
    icon.putalpha(mk)
    bf = m.font(76, 'Bold')
    bw = d.textlength('PantryPal', font=bf)
    x0 = int((W - (132 + 30 + bw)) / 2)
    c.alpha_composite(icon, (x0, 120))
    d.text((x0 + 162, 186), 'PantryPal', font=bf, fill=m.INK, anchor='lm')

    hf = m.font(150, 'Heavy')
    d.text((W // 2, 390), line1, font=hf, fill=m.INK, anchor='mm')
    d.text((W // 2, 555), line2, font=hf, fill=m.ACCENT, anchor='mm')
    sf = m.font(58)
    y = 690
    for ln in m.wrap(sub, sf, 1500, d):
        d.text((W // 2, y), ln, font=sf, fill=m.MUTED, anchor='mm')
        y += 74

    for ch, x, yy, size in corners:
        c.alpha_composite(m.emoji(ch, size), (x, yy))

    shot = status_bar(Image.open(f'{RAW}/{raw}').convert('RGB'))
    fr = ipad(shot, 1300)
    px, py = (W - fr.width) // 2, 830
    m.shadow(c, (px, py, px + fr.width, py + fr.height), 110, 50, 90, (0, 40))
    c.alpha_composite(fr, (px, py))

    for ch, x, yy in tiles:
        m.tile(c, ch, x, yy, size=180)

    os.makedirs(OUT, exist_ok=True)
    c.convert('RGB').save(f'{OUT}/{name}.png', optimize=True)
    print('saved', f'{OUT}/{name}.png', c.size)


make('ipad_01_use_first', 'ipad_home.png', 'Know What to', 'Use First',
     "See what's expiring soon and what to cook tonight — before food goes to waste.",
     tiles=[('⏰', 1810, 1000), ('🥕', 60, 1350), ('💰', 1810, 1900)],
     corners=[('🥚', 1700, 2330, 380), ('🌿', -80, 2250, 420), ('🍅', -50, 1800, 240)])

make('ipad_02_plan', 'ipad_plan.png', 'Plan Meals From', 'What You Have',
     "Turn your pantry into dinners, batch cook, and buy only what's missing.",
     tiles=[('🗓️', 60, 1050), ('🍲', 1810, 1400), ('🛒', 60, 1950)],
     corners=[('🧄', 1720, 2300, 340), ('🌿', -90, 2300, 420), ('🥦', 1760, 1950, 240)])
