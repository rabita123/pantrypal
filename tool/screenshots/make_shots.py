"""App Store screenshots (1290x2796) in the style of the existing PantryPal set."""
import os
from PIL import Image, ImageDraw, ImageFilter, ImageFont

W, H = 1290, 2796
ROOT = '/Users/sayratasminrabita/Downloads/pantrypal'
IMG = '/private/tmp/claude-501/-Users-sayratasminrabita-Downloads-pantrypal/57014fb0-2575-4817-908b-f7e0b4a00d45/images'
OUT = f'{ROOT}/docs/screenshots'
ICON = f'{ROOT}/ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-1024x1024@1x.png'
SF = '/System/Library/Fonts/SFNS.ttf'
EMOJI = '/System/Library/Fonts/Apple Color Emoji.ttc'

INK = (20, 54, 28)
ACCENT = (46, 125, 50)
MUTED = (95, 107, 96)


def font(size, weight='Regular'):
    f = ImageFont.truetype(SF, size)
    try:
        f.set_variation_by_name(weight)
    except Exception:
        pass
    return f


def emoji(ch, size):
    f = ImageFont.truetype(EMOJI, 160)
    im = Image.new('RGBA', (200, 200), (0, 0, 0, 0))
    ImageDraw.Draw(im).text((100, 100), ch, font=f, embedded_color=True, anchor='mm')
    im = im.crop(im.getbbox())
    r = size / max(im.size)
    return im.resize((max(1, int(im.width * r)), max(1, int(im.height * r))), Image.LANCZOS)


def rounded(size, radius, fill):
    m = Image.new('L', size, 0)
    ImageDraw.Draw(m).rounded_rectangle([0, 0, size[0] - 1, size[1] - 1], radius, fill=255)
    im = Image.new('RGBA', size, fill)
    im.putalpha(m)
    return im


def shadow(canvas, box, radius, blur, alpha, offset=(0, 24)):
    x0, y0, x1, y1 = box
    pad = blur * 3
    sh = Image.new('RGBA', (x1 - x0 + pad * 2, y1 - y0 + pad * 2), (0, 0, 0, 0))
    ImageDraw.Draw(sh).rounded_rectangle([pad, pad, pad + x1 - x0, pad + y1 - y0], radius, fill=(10, 40, 15, alpha))
    sh = sh.filter(ImageFilter.GaussianBlur(blur))
    canvas.alpha_composite(sh, (x0 - pad + offset[0], y0 - pad + offset[1]))


def clean_status_bar(shot):
    """Replace the real status bar (odd time, 5% battery) with a tidy one."""
    d = ImageDraw.Draw(shot)
    bg = shot.getpixel((30, 30))
    d.rectangle([0, 0, shot.width, 150], fill=bg)
    d.text((150, 92), '9:41', font=font(54, 'Semibold'), fill=(0, 0, 0), anchor='mm')
    x, base = 905, 110  # signal bars
    for i, h in enumerate([16, 24, 32, 40]):
        d.rounded_rectangle([x + i * 17, base - h, x + i * 17 + 11, base], 3, fill=(0, 0, 0))
    cx, cy = 1012, 112  # wifi
    for r in (40, 27, 14):
        d.arc([cx - r, cy - r, cx + r, cy + r], 225, 315, fill=(0, 0, 0), width=8)
    d.ellipse([cx - 5, cy - 9, cx + 5, cy + 1], fill=(0, 0, 0))
    bx, by = 1062, 76  # battery, full
    d.rounded_rectangle([bx, by, bx + 72, by + 36], 10, outline=(0, 0, 0), width=4)
    d.rounded_rectangle([bx + 7, by + 7, bx + 65, by + 29], 5, fill=(0, 0, 0))
    d.rounded_rectangle([bx + 76, by + 12, bx + 82, by + 24], 2, fill=(0, 0, 0))
    return shot


def phone(shot, sw):
    """Screenshot inside a dark iPhone frame with Dynamic Island."""
    s = sw / shot.width
    sh_ = int(shot.height * s)
    screen = shot.resize((sw, sh_), Image.LANCZOS).convert('RGBA')
    rr = int(118 * s / 0.62)
    mask = Image.new('L', screen.size, 0)
    ImageDraw.Draw(mask).rounded_rectangle([0, 0, sw - 1, sh_ - 1], rr, fill=255)
    screen.putalpha(mask)
    bez = 24
    frame = rounded((sw + bez * 2, sh_ + bez * 2), rr + bez, (24, 26, 25, 255))
    edge = ImageDraw.Draw(frame)
    edge.rounded_rectangle([1, 1, frame.width - 2, frame.height - 2], rr + bez, outline=(70, 74, 72), width=3)
    frame.alpha_composite(screen, (bez, bez))
    iw, ih = int(sw * 0.29), int(sw * 0.085)
    ImageDraw.Draw(frame).rounded_rectangle(
        [(frame.width - iw) // 2, bez + int(sw * 0.03), (frame.width + iw) // 2, bez + int(sw * 0.03) + ih],
        ih // 2, fill=(0, 0, 0))
    return frame


def tile(canvas, ch, x, y, size=150):
    shadow(canvas, (x, y, x + size, y + size), 38, 18, 55, (0, 14))
    canvas.alpha_composite(rounded((size, size), 38, (255, 255, 255, 255)), (x, y))
    e = emoji(ch, int(size * 0.5))
    canvas.alpha_composite(e, (x + (size - e.width) // 2, y + (size - e.height) // 2))


def wrap(text, f, maxw, d):
    words, lines, cur = text.split(), [], ''
    for w_ in words:
        t = (cur + ' ' + w_).strip()
        if d.textlength(t, font=f) <= maxw:
            cur = t
        else:
            lines.append(cur)
            cur = w_
    lines.append(cur)
    return lines


def make(name, shot_path, line1, line2, sub, tiles, corners):
    c = Image.new('RGBA', (W, H))
    top, bot = (244, 247, 238), (255, 255, 255)
    for y in range(H):
        t = y / H
        ImageDraw.Draw(c).line([(0, y), (W, y)], fill=tuple(int(top[i] + (bot[i] - top[i]) * t) for i in range(3)))
    d = ImageDraw.Draw(c)

    # Brand row
    icon = Image.open(ICON).convert('RGBA').resize((118, 118), Image.LANCZOS)
    m = Image.new('L', icon.size, 0)
    ImageDraw.Draw(m).rounded_rectangle([0, 0, 117, 117], 27, fill=255)
    icon.putalpha(m)
    bf = font(66, 'Bold')
    bw = d.textlength('PantryPal', font=bf)
    total = 118 + 26 + bw
    x0 = int((W - total) / 2)
    c.alpha_composite(icon, (x0, 150))
    d.text((x0 + 144, 209), 'PantryPal', font=bf, fill=INK, anchor='lm')

    # Headline + subtitle
    hf = font(132, 'Heavy')
    d.text((W // 2, 420), line1, font=hf, fill=INK, anchor='mm')
    d.text((W // 2, 568), line2, font=hf, fill=ACCENT, anchor='mm')
    sf = font(50)
    y = 690
    for ln in wrap(sub, sf, 1030, d):
        d.text((W // 2, y), ln, font=sf, fill=MUTED, anchor='mm')
        y += 66

    # Corner food, behind the phone
    for ch, x, yy, size in corners:
        c.alpha_composite(emoji(ch, size), (x, yy))

    # Phone
    shot = clean_status_bar(Image.open(shot_path).convert('RGB'))
    ph = phone(shot, 820)
    px, py = (W - ph.width) // 2, 900
    shadow(c, (px, py, px + ph.width, py + ph.height), 150, 40, 90, (0, 40))
    c.alpha_composite(ph, (px, py))

    # Floating feature tiles
    for ch, x, yy in tiles:
        tile(c, ch, x, yy)

    os.makedirs(OUT, exist_ok=True)
    c.convert('RGB').save(f'{OUT}/{name}.png', optimize=True)
    print('saved', f'{OUT}/{name}.png')


make('01_use_first', f'{IMG}/18.png',
     'Know What to', 'Use First',
     "See what's expiring soon and what to cook tonight — before food goes to waste.",
     tiles=[('⏰', 1080, 1060), ('🥕', 60, 1300), ('💰', 1080, 1780)],
     corners=[('🥚', 1010, 2380, 300), ('🌿', -60, 2300, 320), ('🍅', -40, 1820, 190)])

make('02_plan', f'{IMG}/19.png',
     'Plan Meals From', 'What You Have',
     "Turn your pantry into dinners, batch cook, and buy only what's missing.",
     tiles=[('🗓️', 60, 1080), ('🍲', 1080, 1380), ('🛒', 60, 1880)],
     corners=[('🧄', 1040, 2330, 260), ('🌿', -70, 2340, 320), ('🥦', 1080, 1980, 190)])
