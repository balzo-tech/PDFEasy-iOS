#!/usr/bin/env python3
"""I tre «fogli fotografati» delle slide, nelle lingue diverse dall'inglese.

L'inglese sta a mano in 1.html 2.html 3.html (modulo della gita, scontrino,
appunti del sopralluogo) e en/*.png. Qui ogni lingua riscrive gli stessi tre
fogli con nomi, indirizzi, valuta, IVA e convenzioni del suo paese: la stessa
famiglia di seed-docs/make.py. Gli HTML finiscono in <lingua>/N.html (col CSS
di ../photo.css) e i PNG, 1200x1600 come quelli inglesi, in <lingua>/N.png.

    ./make.py            # tutte le lingue
    ./make.py it de      # solo queste
"""
import os, subprocess, sys

CHROME = "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
here = os.path.dirname(os.path.abspath(__file__))


def cents(s):
    """«1.234,56» o «1,234.56» → centesimi."""
    s = s.strip()
    sep = max(s.rfind(","), s.rfind("."))
    whole = "".join(c for c in s[:sep] if c.isdigit())
    return int(whole) * 100 + int(s[sep + 1:])


def fmt(c, dec, thou):
    w, f = divmod(c, 100)
    ws = f"{w:,}".replace(",", thou)
    return f"{ws}{dec}{f:02d}"


# ---------------------------------------------------------------- 1: il modulo
FORM_CSS = """ h1 { font: 700 30px "Helvetica Neue"; letter-spacing: 1px; text-transform: uppercase; text-align:center; }
 .school { text-align:center; font-size: 22px; color:#444; margin-bottom: 10px; }
 hr { border:0; border-top: 3px solid #1d1d1f; margin: 26px 0 34px; }
 p { font-size: 24px; line-height: 1.55; margin-bottom: 22px; }
 .row { display:flex; align-items:flex-end; gap: 14px; font-size: 24px; margin: 30px 0; }
 .row span.l { white-space: nowrap; }
 .line { flex:1; border-bottom: 2px solid #333; min-height: 46px; padding: 0 10px 2px; font-size: 34px; line-height: 1; white-space: nowrap; }
 .box { display:inline-block; width: 30px; height: 30px; border: 2px solid #333; margin-right: 12px; vertical-align: middle; position: relative; }
 .box.x::after { content:"✓"; position:absolute; left:2px; top:-14px; font: 44px "Bradley Hand"; color:#1f3a8a; }
 .check { font-size: 24px; margin: 14px 0; }
 .sig { font-size: 46px; }
 .paper > :not(.foot) { zoom: 1.22; }
 .foot { position:absolute; bottom: 70px; left: 96px; right: 96px; font-size: 18px; color:#666; border-top: 1px solid #aaa; padding-top: 14px; }"""


def form(d):
    return f"""<!doctype html><html lang="{d['lang']}"><head><meta charset="utf-8"><link rel="stylesheet" href="../photo.css">
<style>
{FORM_CSS}
</style></head><body><div class="paper">
 <div class="school">{d['school']}</div>
 <h1>{d['title']}</h1>
 <hr>
 <p>{d['p1']}</p>
 <p>{d['p2']}</p>
 <div class="row"><span class="l">{d['l_name']}</span><div class="line hand">{d['v_name']}</div></div>
 <div class="row"><span class="l">{d['l_class']}</span><div class="line hand">{d['v_class']}</div></div>
 <div class="row"><span class="l">{d['l_emerg']}</span><div class="line hand">{d['v_emerg']}</div></div>
 <div class="check"><span class="box x"></span>{d['c1']}</div>
 <div class="check"><span class="box x"></span>{d['c2']}</div>
 <div class="check"><span class="box"></span>{d['c3']}</div>
 <div class="row" style="margin-top:56px"><span class="l">{d['l_sig']}</span><div class="line hand sig">{d['v_sig']}</div><span class="l">{d['l_date']}</span><div class="line hand" style="flex:.45">{d['v_date']}</div></div>
 <div class="foot">{d['foot']}</div>
</div></body></html>
"""


# ------------------------------------------------------------- 2: lo scontrino
RECEIPT_CSS = """ body { background:#cfc8bb; }
 .paper { inset: 60px 250px 50px 230px; padding: 70px 56px; font-family: "Courier New", monospace; font-size: 25px; line-height: 1.5; background:#faf8f2; transform: rotate(.6deg); }
 .c { text-align:center; } .b { font-weight:700; font-size: 32px; }
 .r { display:flex; justify-content:space-between; }
 .dash { border-top: 2px dashed #555; margin: 18px 0; }"""


def receipt(d):
    dec, thou = d["dec"], d["thou"]
    items = [(n, cents(p)) for n, p in d["items"]]
    total = sum(p for _, p in items)
    rows = "\n".join(f' <div class="r"><span>{n}</span><span>{fmt(p, dec, thou)}</span></div>' for n, p in items)
    # i prezzi dei negozi europei, messicani e brasiliani comprendono già
    # l'imposta: la riga la scorpora, non la somma
    tax = round(total * d["tax_rate"] / (100 + d["tax_rate"]))
    net = total - tax
    # (l_net=None: il cupom brasiliano riporta solo i tributi, non l'imponibile)
    sub_lines = (f' <div class="r"><span>{d["l_net"]}</span><span>{fmt(net, dec, thou)}</span></div>\n' if d["l_net"] else "") + \
                 f' <div class="r"><span>{d["l_tax"]}</span><span>{fmt(tax, dec, thou)}</span></div>'
    return f"""<!doctype html><html lang="{d['lang']}"><head><meta charset="utf-8"><link rel="stylesheet" href="../photo.css">
<style>
{RECEIPT_CSS}
</style></head><body><div class="paper">
 <div class="c b">{d['store']}</div>
 <div class="c">{d['addr']}</div>
 <div class="dash"></div>
 <div class="r"><span>{d['date']}</span><span>{d['time']}</span></div>
 <div class="r"><span>{d['reg']}</span><span>{d['trans']}</span></div>
 <div class="dash"></div>
{rows}
 <div class="dash"></div>
{sub_lines}
 <div class="r b"><span>{d['l_total']}</span><span>{d['cur_pre']}{fmt(total, dec, thou)}{d['cur_post']}</span></div>
 <div class="dash"></div>
 <div class="r"><span>{d['card']}</span><span>{fmt(total, dec, thou)}</span></div>
 <div class="r"><span>{d['auth']}</span><span>{d['approved']}</span></div>
 <div class="dash"></div>
 <div class="c">{d['footer']}</div>
</div></body></html>
"""


# --------------------------------------------------------------- 3: gli appunti
NOTES_CSS = """ .paper { background: #fbf9f1 repeating-linear-gradient(#fbf9f1 0 63px, #b9cde6 63px 65px); background-position: 0 138px; padding: 76px 100px 80px 150px; }
 .paper::before { content:""; position:absolute; top:0; bottom:0; left:110px; border-left: 2px solid #e5a3a3; }
 .hand { font-size: 44px; line-height: 65px; }
 h2 { font-size: 54px; margin-bottom: 0; }"""


def notes(d):
    bullets = "\n".join(f" <div>– {b}</div>" for b in d["bullets"])
    return f"""<!doctype html><html lang="{d['lang']}"><head><meta charset="utf-8"><link rel="stylesheet" href="../photo.css">
<style>
{NOTES_CSS}
</style></head><body><div class="paper"><div class="hand">
 <h2>{d['h']}</h2>
 <div>{d['when']}</div>
 <div>&nbsp;</div>
{bullets}
 <div>&nbsp;</div>
 <div>{d['deposit']}</div>
 <div>{d['move']}</div>
</div></div></body></html>
"""


LANGS = {
 "it": dict(
  form=dict(lang="it", school="Scuola primaria Giovanni Pascoli · Classe 3ª B", title="Autorizzazione gita",
   p1="La classe visiterà il <b>Museo della Scienza</b> <b>giovedì 16 ottobre</b>. Il pullman parte alle 8:45 e rientra entro le 14:30. Gli alunni portano il pranzo al sacco e una borraccia.",
   p2="Compilare il modulo e riconsegnarlo all'insegnante entro <b>venerdì 10 ottobre</b>.",
   l_name="Nome dell'alunno", v_name="Sofia Marchi", l_class="Classe / Insegnante", v_class="3ª B — Maestra Rossi",
   l_emerg="Contatto di emergenza", v_emerg="Chiara Marchi 347 555 0142",
   c1="Mia figlia può partecipare alla gita.", c2="Posso accompagnare la classe come volontaria.", c3="Mia figlia ha allergie (indicare sotto).",
   l_sig="Firma del genitore", v_sig="Chiara Marchi", l_date="Data", v_date="6/10",
   foot="Informazioni: segreteria 02 555 0100 oppure classe3b@pascoli.example.it"),
  receipt=dict(lang="it", dec=",", thou=".", store="FERRAMENTA NAVIGLI", addr="Via Vigevano 41<br>20144 Milano MI<br>Tel. 02 555 0187<br>P.IVA 01234567890",
   date="04/10/2026", time="11:42", reg="Cassa 2", trans="Scontr. n. 0881",
   items=[("Rullo pittura 25 cm", "8,99"), ("Vaschette x3", "5,97"), ("Nastro carta", "6,49"), ("Idropittura 2,5 L", "42,99"),
          ("Telo coprente 4x5", "11,49"), ("Carta vetrata 220", "4,79"), ("Tasselli", "3,29")],
   tax_rate=22, l_net="IMPONIBILE", l_tax="IVA 22%", l_total="TOTALE", cur_pre="€", cur_post="",
   card="CARTA ****4417", auth="AUT 044912", approved="APPROVATA",
   footer="Cambi entro 30 giorni<br>con lo scontrino.<br><br>GRAZIE!"),
  notes=dict(lang="it", h="Sopralluogo appartamento", when="Sab 4 ott — via Tortona 18, int. 3",
   bullets=["La finestra della camera si blocca", "Segno sul muro del corridoio (foto)", "Il rubinetto della cucina gocciola",
            "2 chiavi + chiave cassetta posta", "Rilevatore di fumo OK", "Chiedere del posto auto"],
   deposit="Cauzione: 2.400 € — ricevuta?", move="Ingresso: 1 novembre")),
 "es": dict(
  form=dict(lang="es", school="Escuela Primaria Benito Juárez · Grupo 3° B", title="Permiso de excursión",
   p1="Nuestro grupo visitará el <b>Museo de Ciencias</b> el <b>jueves 16 de octubre</b>. El autobús sale a las 8:45 y regresa a las 14:30. Los alumnos deben llevar lunch y una botella de agua.",
   p2="Favor de llenar este formato y entregarlo a la maestra a más tardar el <b>viernes 10 de octubre</b>.",
   l_name="Nombre del alumno", v_name="Mateo Marchena", l_class="Grado / Maestra", v_class="3° B — Mtra. Salazar",
   l_emerg="Contacto de emergencia", v_emerg="Daniela Marchena 55 5555 0142",
   c1="Mi hijo puede asistir a la excursión.", c2="Puedo acompañar al grupo como voluntaria.", c3="Mi hijo tiene alergias (anótelas abajo).",
   l_sig="Firma de la madre", v_sig="Daniela Marchena", l_date="Fecha", v_date="6/10",
   foot="Dudas: llame a la dirección al 55 5555 0100 o escriba a grupo3b@juarez.example.mx"),
  receipt=dict(lang="es", dec=".", thou=",", store="FERRETERÍA LA ESQUINA", addr="Av. Álvaro Obregón 418<br>Col. Roma Norte, CDMX 06700<br>Tel. 55 5555 0187<br>RFC FES010101AB1",
   date="04/10/2026", time="11:42", reg="Caja 2", trans="Ticket 08817",
   items=[("Rodillo 9 pulg", "89.90"), ("Charolas x3", "59.70"), ("Cinta masking", "64.90"), ("Pintura vinílica 4 L", "429.90"),
          ("Plástico protector", "114.90"), ("Lija 220", "47.90"), ("Taquetes", "32.90")],
   tax_rate=16, l_net="SUBTOTAL", l_tax="IVA 16%", l_total="TOTAL", cur_pre="$", cur_post=" MXN",
   card="TARJETA ****4417", auth="AUT 044912", approved="APROBADA",
   footer="Cambios en 30 días<br>con su ticket.<br><br>¡GRACIAS POR SU COMPRA!"),
  notes=dict(lang="es", h="Revisión del depa", when="Sáb 4 oct — Bellani 122 int. 4B",
   bullets=["La ventana de la recámara se atora", "Mancha en la pared del pasillo (foto)", "La llave de la cocina gotea",
            "2 llaves + llave del buzón", "Detector de humo OK", "Preguntar por el estacionamiento"],
   deposit="Depósito: $24,000 — ¿recibo?", move="Mudanza: 1 de nov")),
 "de": dict(
  form=dict(lang="de", school="Grundschule am Kiesteich · Klasse 3b", title="Einverständniserklärung Ausflug",
   p1="Unsere Klasse besucht am <b>Donnerstag, 16. Oktober</b> das <b>Technikmuseum</b>. Der Bus fährt um 8:45 Uhr ab und ist gegen 14:30 Uhr zurück. Bitte Rucksackverpflegung und eine Trinkflasche mitgeben.",
   p2="Bitte füllen Sie den Abschnitt aus und geben Sie ihn bis <b>Freitag, 10. Oktober</b> bei der Klassenlehrerin ab.",
   l_name="Name des Kindes", v_name="Leon Markwart", l_class="Klasse / Lehrkraft", v_class="3b — Frau Becker",
   l_emerg="Notfallkontakt", v_emerg="Julia Markwart 0176 555 0142",
   c1="Mein Kind darf am Ausflug teilnehmen.", c2="Ich kann als Begleitperson mitkommen.", c3="Mein Kind hat Allergien (bitte unten angeben).",
   l_sig="Unterschrift der Eltern", v_sig="Julia Markwart", l_date="Datum", v_date="6.10.",
   foot="Rückfragen: Sekretariat 030 555 0100 oder klasse3b@kiesteich.example.de"),
  receipt=dict(lang="de", dec=",", thou=".", store="HOBBYMARKT LINDNER", addr="Sonnenallee 87<br>12045 Berlin<br>Tel. 030 555 0187<br>USt-IdNr. DE123456789",
   date="04.10.2026", time="11:42", reg="Kasse 2", trans="Beleg 08817",
   items=[("Farbroller 25 cm", "8,99"), ("Farbwannen x3", "5,97"), ("Malerkrepp", "6,49"), ("Wandfarbe seidenm. 2,5 L", "42,99"),
          ("Abdeckfolie 4x5 m", "11,49"), ("Schleifpapier 220", "4,79"), ("Dübel", "3,29")],
   tax_rate=19, l_net="NETTO", l_tax="MwSt 19%", l_total="SUMME", cur_pre="", cur_post=" EUR",
   card="EC-KARTE ****4417", auth="AUTH 044912", approved="GENEHMIGT",
   footer="Umtausch innerhalb von<br>30 Tagen mit Kassenbon.<br><br>VIELEN DANK!"),
  notes=dict(lang="de", h="Wohnungsbegehung", when="Sa 4. Okt — Lenaustraße 9, Whg. 3",
   bullets=["Schlafzimmerfenster klemmt", "Kratzer an der Flurwand (Foto)", "Küchenhahn tropft",
            "2 Schlüssel + Briefkastenschl.", "Rauchmelder OK", "Nach Parkausweis fragen"],
   deposit="Kaution: 2.200 € — Quittung?", move="Einzug: 1. Nov")),
 "fr": dict(
  form=dict(lang="fr", school="École élémentaire Les Capucins · CE2 B", title="Autorisation de sortie scolaire",
   p1="Notre classe visitera le <b>Musée des Sciences</b> le <b>jeudi 16 octobre</b>. Le car part à 8 h 45 et revient avant 14 h 30. Les élèves apportent un pique-nique et une gourde.",
   p2="Merci de remplir ce talon et de le rendre à l'enseignante avant le <b>vendredi 10 octobre</b>.",
   l_name="Nom de l'élève", v_name="Léa Marchand", l_class="Classe / Enseignante", v_class="CE2 B — Mme Dubois",
   l_emerg="Contact d'urgence", v_emerg="Claire Marchand 06 39 98 01 42",
   c1="Ma fille peut participer à la sortie.", c2="Je peux accompagner la classe.", c3="Ma fille a des allergies (à préciser ci-dessous).",
   l_sig="Signature du parent", v_sig="Claire Marchand", l_date="Date", v_date="6/10",
   foot="Renseignements : secrétariat 04 78 55 01 00 ou ce2b@capucins.example.fr"),
  receipt=dict(lang="fr", dec=",", thou=" ", store="QUINCAILLERIE DU COIN", addr="27 cours Gambetta<br>69003 Lyon<br>Tél. 04 78 55 01 87<br>SIRET 123 456 789 00012",
   date="04/10/2026", time="11:42", reg="Caisse 2", trans="Ticket 08817",
   items=[("Rouleau peinture 25 cm", "8,99"), ("Bacs à peinture x3", "5,97"), ("Ruban de masquage", "6,49"), ("Peinture satin 2,5 L", "42,99"),
          ("Bâche protection 4x5", "11,49"), ("Papier de verre 220", "4,79"), ("Chevilles", "3,29")],
   tax_rate=20, l_net="TOTAL HT", l_tax="TVA 20%", l_total="TOTAL TTC", cur_pre="", cur_post=" €",
   card="CB ****4417", auth="AUTO 044912", approved="ACCEPTÉ",
   footer="Échange sous 30 jours<br>avec le ticket.<br><br>MERCI DE VOTRE VISITE !"),
  notes=dict(lang="fr", h="Visite de l'appartement", when="Sam. 4 oct. — 14 rue Sainte-Catherine",
   bullets=["La fenêtre de la chambre coince", "Marque sur le mur du couloir (photo)", "Le robinet de la cuisine goutte",
            "2 clés + clé de la boîte aux lettres", "Détecteur de fumée OK", "Demander pour le parking"],
   deposit="Caution : 950 € — reçu ?", move="Entrée : 1er novembre")),
 "nl": dict(
  form=dict(lang="nl", school="Basisschool De Regenboog · Groep 5", title="Toestemming schoolreisje",
   p1="Onze klas bezoekt het <b>Wetenschapsmuseum</b> op <b>donderdag 16 oktober</b>. De bus vertrekt om 8.45 uur en is om 14.30 uur terug. Geef lunch en drinken mee in een rugzak.",
   p2="Vul dit formulier in en lever het uiterlijk <b>vrijdag 10 oktober</b> in bij de juf.",
   l_name="Naam leerling", v_name="Daan Markwijk", l_class="Groep / Leerkracht", v_class="Groep 5 — juf Bakker",
   l_emerg="Noodnummer", v_emerg="Sanne Markwijk 06 5550 0142",
   c1="Mijn zoon mag mee op schoolreisje.", c2="Ik kan meegaan als begeleider.", c3="Mijn zoon heeft allergieën (hieronder vermelden).",
   l_sig="Handtekening ouder", v_sig="Sanne Markwijk", l_date="Datum", v_date="6-10",
   foot="Vragen? Bel de school: 030 555 0100 of mail groep5@regenboog.example.nl"),
  receipt=dict(lang="nl", dec=",", thou=".", store="BOUWMARKT DE HOEK", addr="Voorstraat 65<br>3512 AH Utrecht<br>Tel. 030 555 0187<br>BTW NL123456789B01",
   date="04-10-2026", time="11:42", reg="Kassa 2", trans="Bon 08817",
   items=[("Verfroller 25 cm", "8,99"), ("Verfbakjes x3", "5,97"), ("Afplaktape", "6,49"), ("Muurverf zijdeglans 2,5 L", "42,99"),
          ("Afdekfolie 4x5 m", "11,49"), ("Schuurpapier 220", "4,79"), ("Pluggen", "3,29")],
   tax_rate=21, l_net="EXCL. BTW", l_tax="BTW 21%", l_total="TOTAAL", cur_pre="€", cur_post="",
   card="PIN ****4417", auth="AUTH 044912", approved="GOEDGEKEURD",
   footer="Ruilen binnen 30 dagen<br>met de bon.<br><br>BEDANKT!"),
  notes=dict(lang="nl", h="Woning opnemen", when="Za 4 okt — Oudegracht 112, 2e",
   bullets=["Slaapkamerraam klemt", "Kras op de gangmuur (foto)", "Keukenkraan druppelt",
            "2 sleutels + brievenbussleutel", "Rookmelder OK", "Vragen naar parkeervergunning"],
   deposit="Borg: € 2.500 — bewijs?", move="Oplevering: 1 nov")),
 "pt-BR": dict(
  form=dict(lang="pt-BR", school="Escola Municipal Jardim das Flores · 3º ano B", title="Autorização de passeio",
   p1="Nossa turma visitará o <b>Museu da Ciência</b> na <b>quinta-feira, 16 de outubro</b>. O ônibus sai às 8h45 e volta até as 14h30. Os alunos devem levar lanche e uma garrafinha de água.",
   p2="Preencha esta autorização e devolva à professora até <b>sexta-feira, 10 de outubro</b>.",
   l_name="Nome do aluno", v_name="Beatriz Marques", l_class="Turma / Professora", v_class="3º B — Prof.ª Almeida",
   l_emerg="Contato de emergência", v_emerg="Camila Marques (11) 95550-0142",
   c1="Minha filha pode ir ao passeio.", c2="Posso acompanhar a turma como voluntária.", c3="Minha filha tem alergias (descrever abaixo).",
   l_sig="Assinatura do responsável", v_sig="Camila Marques", l_date="Data", v_date="6/10",
   foot="Dúvidas: secretaria (11) 5550-0100 ou 3anob@jardimdasflores.example.br"),
  receipt=dict(lang="pt-BR", dec=",", thou=".", store="FERRAGENS DA ESQUINA", addr="Rua Teodoro Sampaio 418<br>Pinheiros, São Paulo - SP<br>Tel. (11) 5550-0187<br>CNPJ 12.345.678/0001-90",
   date="04/10/2026", time="11:42", reg="Caixa 2", trans="Cupom 08817",
   items=[("Rolo de pintura 23 cm", "24,90"), ("Bandejas x3", "17,90"), ("Fita crepe", "14,90"), ("Tinta acrílica 3,6 L", "189,90"),
          ("Lona plástica 4x5", "29,90"), ("Lixa 220", "6,90"), ("Buchas", "9,90")],
   tax_rate=18, l_net=None, l_tax="Trib. aprox. (18%)", l_total="TOTAL", cur_pre="R$ ", cur_post="",
   card="CARTÃO ****4417", auth="AUT 044912", approved="APROVADO",
   footer="Trocas em até 30 dias<br>com o cupom.<br><br>OBRIGADO!"),
  notes=dict(lang="pt-BR", h="Vistoria do apê", when="Sáb 4 out — Rua Augusta 1250, ap. 42",
   bullets=["Janela do quarto emperra", "Marca na parede do corredor (foto)", "Torneira da cozinha pinga",
            "2 chaves + chave da caixa de correio", "Detector de fumaça OK", "Perguntar da vaga"],
   deposit="Caução: R$ 4.800 — recibo?", move="Mudança: 1º nov")),
}

if __name__ == "__main__":
    for lang in (sys.argv[1:] or LANGS):
        os.makedirs(os.path.join(here, lang), exist_ok=True)
        for n, fn, key in ((1, form, "form"), (2, receipt, "receipt"), (3, notes, "notes")):
            src = os.path.join(here, lang, f"{n}.html")
            with open(src, "w") as f:
                f.write(fn(LANGS[lang][key]))
            out = os.path.join(here, lang, f"{n}.png")
            subprocess.run([CHROME, "--headless", "--disable-gpu", "--hide-scrollbars",
                            f"--screenshot={out}", "--window-size=1200,1600", "file://" + src],
                           stderr=subprocess.DEVNULL, check=True)
            print(out)
