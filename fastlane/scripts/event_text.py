"""What the in-app event says, in every language the store page speaks.

Three fields, and they are short: 30 characters for the name, 50 for the short
description, 120 for the long one. Apple counts them per localisation and
refuses the lot if one is over.
"""

EVENT = {
"en-US": ("The meme maker is here", "Put your words on any picture",
          "Pick a template or your own photo, write the caption, drag it where the joke needs it, then share it."),
"en-GB": ("The meme maker is here", "Put your words on any picture",
          "Pick a template or your own photo, write the caption, drag it where the joke needs it, then share it."),
"en-CA": ("The meme maker is here", "Put your words on any picture",
          "Pick a template or your own photo, write the caption, drag it where the joke needs it, then share it."),
"it": ("Ora puoi fare i meme", "Le tue parole sopra una foto",
       "Scegli un template o una tua foto, scrivi la battuta, trascinala dove serve e condividila."),
"es-ES": ("Ya puedes hacer memes", "Tus palabras sobre cualquier imagen",
          "Elige una plantilla o una foto tuya, escribe el chiste, ponlo donde haga falta y compártelo."),
"es-MX": ("Ya puedes hacer memes", "Tus palabras sobre cualquier imagen",
          "Elige una plantilla o una foto tuya, escribe el chiste, ponlo donde haga falta y compártelo."),
"fr-FR": ("Le créateur de mèmes", "Vos mots sur n'importe quelle image",
          "Choisissez un modèle ou une photo, écrivez la blague, placez-la où il faut et partagez."),
"fr-CA": ("Le créateur de mèmes", "Vos mots sur n'importe quelle image",
          "Choisissez un modèle ou une photo, écrivez la blague, placez-la où il faut et partagez."),
"de-DE": ("Der Meme-Maker ist da", "Deine Worte auf jedem Bild",
          "Vorlage oder eigenes Foto wählen, den Spruch schreiben, hinziehen, wo er hingehört, und teilen."),
"nl-NL": ("De meme-maker is er", "Jouw woorden op elke foto",
          "Kies een sjabloon of eigen foto, schrijf de grap, sleep hem waar hij hoort en deel hem."),
"pt-BR": ("O criador de memes chegou", "Suas palavras em qualquer imagem",
          "Escolha um modelo ou uma foto sua, escreva a piada, arraste para onde precisa e compartilhe."),
"ru": ("Конструктор мемов", "Ваши слова на любой картинке",
       "Выберите шаблон или своё фото, напишите шутку, перетащите её куда нужно и отправьте друзьям."),
"ko": ("밈 만들기가 왔습니다", "어떤 사진에든 당신의 말을",
       "템플릿이나 직접 찍은 사진을 고르고, 농담을 쓰고, 필요한 자리로 끌어다 놓고, 공유하세요."),
"vi": ("Trình tạo meme đã có", "Lời của bạn trên bất kỳ tấm ảnh nào",
       "Chọn mẫu hoặc ảnh của bạn, viết câu đùa, kéo vào đúng chỗ rồi chia sẻ."),
"zh-Hans": ("表情包制作来了", "把你的话写在任何一张图上",
            "挑个模板或你自己的照片，写下笑点，拖到该放的位置，然后分享。"),
"zh-Hant": ("迷因製作來了", "把你的話寫在任何一張圖上",
            "挑個模板或你自己的照片，寫下笑點，拖到該放的位置，然後分享。"),
"ar-SA": ("صانع الميمات وصل", "كلماتك على أي صورة",
          "اختر قالباً أو صورة من عندك، واكتب النكتة، واسحبها إلى مكانها، ثم شاركها."),
}

LIMITS = (30, 50, 120)

if __name__ == "__main__":
    bad = False
    for locale, fields in EVENT.items():
        marks = []
        for value, limit in zip(fields, LIMITS):
            over = len(value) > limit
            bad = bad or over
            marks.append(f"{len(value):3}/{limit}{'  OVER' if over else ''}")
        print(f"{locale:8} " + "  ".join(marks))
    print("FAIL" if bad else "all within the limits")
