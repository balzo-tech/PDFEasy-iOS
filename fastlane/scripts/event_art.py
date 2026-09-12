"""The two pictures every localisation of the in-app event needs.

  EVENT_CARD          1920 x 1080, what shows up in search results
  EVENT_DETAILS_PAGE  1080 x 1920, the event's own page

Drawn rather than photographed, and drawn rather than screenshotted, for two
reasons. The templates in the app come off memegen and their rights are not
declared anywhere, so none of them can go on a store page; and a card that is a
picture of the app's own interface is what the guidelines turn down.

So the picture is the thing the tool makes: a caption over an image. The image
is a sheet of paper — what this app has always been about — and the caption is
set the way the tool sets it, white with a black outline, in the heaviest face
each script has. Impact has no Cyrillic, no Hangul, no Han and no Arabic, so
every script names its own.
"""
import os
from PIL import Image, ImageDraw, ImageFilter, ImageFont

IMPACT = "/System/Library/Fonts/Supplemental/Impact.ttf"
FONTS = {
    "default": (IMPACT, 0),
    "ru": ("/System/Library/Fonts/Supplemental/Arial Black.ttf", 0),
    # Arial Black has no Vietnamese: Ứ and Ụ came out as empty boxes. Bold is a
    # shade lighter and has the whole alphabet.
    "vi": ("/System/Library/Fonts/Supplemental/Arial Bold.ttf", 0),
    "ko": ("/System/Library/Fonts/AppleSDGothicNeo.ttc", 8),
    "zh-Hans": ("/System/Library/Fonts/STHeiti Medium.ttc", 0),
    "zh-Hant": ("/System/Library/Fonts/STHeiti Medium.ttc", 0),
    "ar-SA": ("/System/Library/Fonts/GeezaPro.ttc", 1),  # bold; Arabic only, see LINES
}

# Two lines, the way the format wants them: the set-up over the picture and the
# turn under it. Not a translation of the event's name — the store draws that
# under the card already, and repeating it there is what the guidelines call out.
LINES = {
    "en-US": ("WHEN THE PDF APP", "MAKES MEMES TOO"),
    "en-GB": ("WHEN THE PDF APP", "MAKES MEMES TOO"),
    "en-CA": ("WHEN THE PDF APP", "MAKES MEMES TOO"),
    "it": ("QUANDO L'APP DEI PDF", "FA ANCHE I MEME"),
    "es-ES": ("CUANDO LA APP DE PDF", "TAMBIÉN HACE MEMES"),
    "es-MX": ("CUANDO LA APP DE PDF", "TAMBIÉN HACE MEMES"),
    "fr-FR": ("QUAND L'APPLI PDF", "FAIT AUSSI DES MÈMES"),
    "fr-CA": ("QUAND L'APPLI PDF", "FAIT AUSSI DES MÈMES"),
    "de-DE": ("WENN DIE PDF-APP", "AUCH MEMES MACHT"),
    "nl-NL": ("ALS DE PDF-APP", "OOK MEMES MAAKT"),
    "pt-BR": ("QUANDO O APP DE PDF", "TAMBÉM FAZ MEMES"),
    "ru": ("КОГДА PDF-ПРИЛОЖЕНИЕ", "ЕЩЁ И ДЕЛАЕТ МЕМЫ"),
    "ko": ("PDF 앱이", "밈까지 만들 때"),
    "vi": ("KHI ỨNG DỤNG PDF", "CŨNG LÀM MEME"),
    "zh-Hans": ("当 PDF 应用", "也能做表情包"),
    "zh-Hant": ("當 PDF 應用程式", "也能做迷因"),
    # No "PDF" here, unlike every other line: the bold cut of Geeza Pro carries
    # no Latin at all and drew the three letters as three empty boxes. "The
    # documents app" says the same thing in the script the card is set in.
    "ar-SA": ("عندما يصنع تطبيق المستندات", "الميمات أيضاً"),
}


def font_for(locale: str, size: int) -> ImageFont.FreeTypeFont:
    path, index = FONTS.get(locale, FONTS["default"])
    return ImageFont.truetype(path, size, index=index)


def background(width: int, height: int) -> Image.Image:
    """A wash from the meme yellow into a deeper amber."""
    top, bottom = (255, 205, 20), (240, 120, 15)
    column = Image.new("RGB", (1, height))
    pixels = column.load()
    for y in range(height):
        t = y / (height - 1)
        pixels[0, y] = tuple(int(top[i] + (bottom[i] - top[i]) * t) for i in range(3))
    return column.resize((width, height))


def sheet(image: Image.Image, size: tuple[int, int], offset: int) -> None:
    """A sheet of paper, tilted, with a soft shadow under it."""
    width, height = size
    paper = Image.new("RGBA", size, (255, 255, 255, 255))
    draw = ImageDraw.Draw(paper)
    margin = int(width * 0.12)
    bar, gap = int(height * 0.027), int(height * 0.063)
    y = int(height * 0.15)
    for share in (0.68, 0.79, 0.63, 0.74, 0.39, 0.78, 0.71, 0.80, 0.55):
        if y + bar > height * 0.92:
            break
        draw.rounded_rectangle([margin, y, margin + int((width - 2 * margin) * share), y + bar],
                               radius=bar // 2, fill=(228, 231, 238))
        y += gap
    paper = paper.rotate(-8, resample=Image.BICUBIC, expand=True)

    shadow = Image.new("RGBA", paper.size, (0, 0, 0, 0))
    shadow.paste((0, 0, 0, 90), (0, 0), paper.split()[3])
    shadow = shadow.filter(ImageFilter.GaussianBlur(26))

    x = (image.width - paper.width) // 2
    y = (image.height - paper.height) // 2 + offset
    image.paste(shadow, (x + 12, y + 22), shadow)
    image.paste(paper, (x, y), paper)


def caption(image: Image.Image, text: str, locale: str, size: int, top: int) -> None:
    """Outlined text, the way the tool draws it, shrunk to fit the frame."""
    draw = ImageDraw.Draw(image)
    limit = image.width * 0.9
    rtl = locale == "ar-SA"
    while size > 20:
        font = font_for(locale, size)
        box = draw.textbbox((0, 0), text, font=font, stroke_width=max(size // 18, 1),
                            direction="rtl" if rtl else None)
        if box[2] - box[0] <= limit:
            break
        size -= 4
    stroke = max(size // 18, 1)
    x = (image.width - (box[2] - box[0])) // 2 - box[0]
    draw.text((x, top), text, font=font, fill=(255, 255, 255),
              stroke_width=stroke, stroke_fill=(0, 0, 0),
              direction="rtl" if rtl else None)


def card(locale: str) -> Image.Image:
    image = background(1920, 1080)
    sheet(image, (760, 980), 40)
    over, under = LINES[locale]
    # Both blocks stay clear of the bottom sixth: the store draws the badge and
    # the event's name under the card, and type that ends at the edge of the
    # picture reads as cropped once it is down there.
    caption(image, over, locale, 145, 64)
    caption(image, under, locale, 145, 1080 - 330)
    return image


def details(locale: str) -> Image.Image:
    image = background(1080, 1920)
    sheet(image, (720, 940), 60)
    over, under = LINES[locale]
    caption(image, over, locale, 130, 150)
    caption(image, under, locale, 130, 1920 - 460)
    return image


def main() -> None:
    out = "event-art"
    os.makedirs(out, exist_ok=True)
    for locale in LINES:
        card(locale).save(os.path.join(out, f"card-{locale}.png"))
        details(locale).save(os.path.join(out, f"details-{locale}.png"))
    print(len(LINES), "locales ×2 written to", out)


main()
