#!/usr/bin/env python3
"""PDF di testo per l'archivio della slide «Search inside every document».

Ogni documento è una pagina HTML stampata in PDF da Chrome, così ha testo vero
che l'app indicizza al salvataggio. Il numero davanti al nome fissa l'ordine
(l'ultimo finisce in cima all'archivio) e l'app lo toglie.

    ./make.py            # → <lingua>/*.pdf per tutte le lingue
    ./make.py it de      # solo queste

La parola che la slide cerca sta nel TESTO del contratto (n. 6) e non nel suo
nome file, così il risultato è davvero una ricerca nel contenuto:
en deposit, it cauzione, es depósito, de Kaution, fr caution, nl borg,
pt-BR caução. Carta A4 ovunque tranne en e es (letter).
"""
import os, subprocess, sys, tempfile

CHROME = "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
CSS = """<style>@page{size:%s;margin:0.8in}body{font:12pt 'Helvetica Neue',Arial;color:#222}
h1{font-size:20pt;margin:0 0 6pt}h2{font-size:13pt;margin:18pt 0 4pt}.m{color:#666}
table{border-collapse:collapse;width:100%%;margin-top:10pt}td,th{border-bottom:1px solid #ccc;padding:5pt;text-align:left}
td.r,th.r{text-align:right}</style>"""
PAGE = {"en": "letter", "es": "letter"}   # gli altri: A4

DOCS = {
 "en": {
  "1 Car insurance card": """<h1>Evidence of Insurance</h1><p class=m>Harbor Mutual Auto · Policy HM-5530-8812</p>
   <table><tr><th>Insured</th><td>Dana Thompson</td></tr><tr><th>Vehicle</th><td>2019 Honda CR-V · VIN 7FARW2H5XKE0X1234</td></tr>
   <tr><th>Effective</th><td>08/01/2026 – 01/31/2027</td></tr><tr><th>Agent</th><td>(617) 555-0199</td></tr></table>""",
  "2 Pay stub September": """<h1>Earnings Statement</h1><p class=m>Brightline Clinics · Pay period 09/01/2026 – 09/15/2026</p>
   <table><tr><th>Description</th><th class=r>Current</th><th class=r>YTD</th></tr>
   <tr><td>Regular pay</td><td class=r>2,640.00</td><td class=r>44,880.00</td></tr>
   <tr><td>Federal income tax</td><td class=r>-301.20</td><td class=r>-5,120.40</td></tr>
   <tr><td>Social Security</td><td class=r>-163.68</td><td class=r>-2,782.56</td></tr>
   <tr><td><b>Net pay</b></td><td class=r><b>2,175.12</b></td><td class=r></td></tr></table>""",
  "3 Vet records Biscuit": """<h1>Patient Record — Biscuit</h1><p class=m>Riverside Animal Hospital · Canine, Beagle, 4 yrs</p>
   <h2>Vaccinations</h2><table><tr><td>Rabies (3-year)</td><td>03/12/2026</td></tr><tr><td>DHPP</td><td>03/12/2026</td></tr><tr><td>Bordetella</td><td>09/02/2026</td></tr></table>
   <h2>Notes</h2><p>Healthy weight. Next annual exam March 2027.</p>""",
  "4 Security deposit receipt": """<h1>Receipt</h1><p class=m>Linden Street Properties LLC · Receipt #2026-0417</p>
   <p>Received from <b>Dana Thompson</b> the sum of <b>$2,400.00</b> as security deposit for 22 Linden Street, Apt. 3, Somerville, MA 02143.</p>
   <p>The deposit is held in a separate interest-bearing account at Cambridge Savings Bank, as required by Massachusetts law.</p>
   <p>Date: October 3, 2026 · Received by: M. Ortega, Property Manager</p>""",
  "5 Move-in checklist": """<h1>Apartment Condition Statement</h1><p class=m>22 Linden Street, Apt. 3 · Move-in November 1, 2026</p>
   <table><tr><th>Room</th><th>Condition</th></tr><tr><td>Bedroom</td><td>Window sticks when opening</td></tr>
   <tr><td>Hallway</td><td>Scuff on wall near closet</td></tr><tr><td>Kitchen</td><td>Faucet drips</td></tr>
   <tr><td>Keys</td><td>2 apartment keys, 1 mailbox key</td></tr></table>
   <p>Return this statement within 15 days to protect your security deposit.</p>""",
  "6 Lease 22 Linden St": """<h1>Residential Lease</h1><p class=m>Linden Street Properties LLC (Landlord) and Dana Thompson (Tenant)</p>
   <h2>1. Premises</h2><p>22 Linden Street, Apt. 3, Somerville, MA 02143.</p>
   <h2>2. Term</h2><p>Twelve months, from November 1, 2026 to October 31, 2027.</p>
   <h2>3. Rent</h2><p>$2,400 per month, due on the first day of each month.</p>
   <h2>4. Security deposit</h2><p>Tenant pays a security deposit of $2,400, to be returned within 30 days after the end of the tenancy, less any lawful deductions.</p>
   <h2>5. Utilities</h2><p>Tenant pays electricity and internet. Landlord pays water and heat.</p>""",
  "7 Field trip form": """<h1>Field Trip Permission Form</h1><p class=m>Jefferson Park Elementary School · Room 14</p>
   <p>Our class will visit the Museum of Science on Thursday, October 16. Please return this form by Friday, October 10.</p>
   <p>Student: Maya Thompson · Grade 3 · Ms. Alvarez</p>""",
 },

 "it": {
  "1 Assicurazione auto": """<h1>Certificato di assicurazione</h1><p class=m>Alba Assicurazioni · Polizza RC Auto 5530-8812</p>
   <table><tr><th>Contraente</th><td>Chiara Marchi</td></tr><tr><th>Veicolo</th><td>Utilitaria 2019 · Targa FK 482 AB</td></tr>
   <tr><th>Validità</th><td>01/08/2026 – 31/01/2027</td></tr><tr><th>Agenzia</th><td>02 555 0199</td></tr></table>""",
  "2 Busta paga settembre": """<h1>Cedolino paga</h1><p class=m>Studio Medico Riva · Periodo 01/09/2026 – 30/09/2026</p>
   <table><tr><th>Voce</th><th class=r>Mese</th><th class=r>Progressivo</th></tr>
   <tr><td>Retribuzione lorda</td><td class=r>2.640,00</td><td class=r>23.760,00</td></tr>
   <tr><td>Contributi previdenziali</td><td class=r>-251,76</td><td class=r>-2.265,84</td></tr>
   <tr><td>IRPEF</td><td class=r>-318,20</td><td class=r>-2.863,80</td></tr>
   <tr><td><b>Netto in busta</b></td><td class=r><b>2.070,04</b></td><td class=r></td></tr></table>""",
  "3 Libretto Briciola": """<h1>Libretto sanitario — Briciola</h1><p class=m>Ambulatorio Veterinario Navigli · Cane, Beagle, 4 anni</p>
   <h2>Vaccinazioni</h2><table><tr><td>Rabbia</td><td>12/03/2026</td></tr><tr><td>Polivalente</td><td>12/03/2026</td></tr><tr><td>Tosse dei canili</td><td>02/09/2026</td></tr></table>
   <h2>Note</h2><p>Peso nella norma. Prossima visita annuale a marzo 2027.</p>""",
  "4 Ricevuta cauzione": """<h1>Ricevuta</h1><p class=m>Immobiliare Tortona S.r.l. · Ricevuta n. 2026-0417</p>
   <p>Ricevuto da <b>Chiara Marchi</b> la somma di <b>€ 2.400,00</b> a titolo di cauzione per l'immobile di via Tortona 18, int. 3, 20144 Milano.</p>
   <p>La cauzione produce interessi legali a favore del conduttore, come previsto dall'art. 11 della legge 392/1978.</p>
   <p>Data: 3 ottobre 2026 · Ricevuto da: M. Ortega, amministratore</p>""",
  "5 Verbale di consegna": """<h1>Verbale di consegna dell'immobile</h1><p class=m>Via Tortona 18, int. 3 · Ingresso 1° novembre 2026</p>
   <table><tr><th>Locale</th><th>Stato</th></tr><tr><td>Camera</td><td>La finestra si blocca quando si apre</td></tr>
   <tr><td>Corridoio</td><td>Segno sul muro vicino all'armadio</td></tr><tr><td>Cucina</td><td>Il rubinetto gocciola</td></tr>
   <tr><td>Chiavi</td><td>2 chiavi dell'appartamento, 1 della cassetta postale</td></tr></table>
   <p>Restituire il verbale entro 15 giorni per tutelare la cauzione.</p>""",
  "6 Contratto via Tortona 18": """<h1>Contratto di locazione ad uso abitativo</h1><p class=m>Immobiliare Tortona S.r.l. (Locatore) e Chiara Marchi (Conduttore)</p>
   <h2>1. Immobile</h2><p>Via Tortona 18, int. 3, 20144 Milano.</p>
   <h2>2. Durata</h2><p>Quattro anni, dal 1° novembre 2026 al 31 ottobre 2030, rinnovabili per altri quattro.</p>
   <h2>3. Canone</h2><p>€ 1.200 al mese, da pagare entro il giorno 5 di ogni mese.</p>
   <h2>4. Deposito cauzionale</h2><p>Il Conduttore versa una cauzione di € 2.400, pari a due mensilità, da restituire entro 30 giorni dalla riconsegna dell'immobile, salvo trattenute dovute a danni.</p>
   <h2>5. Spese</h2><p>Il Conduttore paga luce e internet. Acqua e riscaldamento sono a carico del condominio.</p>""",
  "7 Autorizzazione gita": """<h1>Autorizzazione gita</h1><p class=m>Scuola primaria Giovanni Pascoli · Classe 3ª B</p>
   <p>La classe visiterà il Museo della Scienza giovedì 16 ottobre. Riconsegnare il modulo entro venerdì 10 ottobre.</p>
   <p>Alunna: Sofia Marchi · Classe 3ª B · Maestra Rossi</p>""",
 },

 "es": {
  "1 Seguro del auto": """<h1>Póliza de seguro de auto</h1><p class=m>Aseguradora Alba · Póliza AU-5530-8812</p>
   <table><tr><th>Asegurada</th><td>Daniela Marchena</td></tr><tr><th>Vehículo</th><td>Sedán 2019 · Placas NXB-482-A</td></tr>
   <tr><th>Vigencia</th><td>01/08/2026 – 31/01/2027</td></tr><tr><th>Agente</th><td>55 5555 0199</td></tr></table>""",
  "2 Recibo de nómina septiembre": """<h1>Recibo de nómina</h1><p class=m>Clínica Horizonte S.A. de C.V. · Quincena 01/09/2026 – 15/09/2026</p>
   <table><tr><th>Concepto</th><th class=r>Quincena</th><th class=r>Acumulado</th></tr>
   <tr><td>Sueldo</td><td class=r>9,200.00</td><td class=r>156,400.00</td></tr>
   <tr><td>ISR</td><td class=r>-820.40</td><td class=r>-13,946.80</td></tr>
   <tr><td>IMSS</td><td class=r>-226.58</td><td class=r>-3,851.86</td></tr>
   <tr><td><b>Neto a pagar</b></td><td class=r><b>8,153.02</b></td><td class=r></td></tr></table>""",
  "3 Cartilla de Canela": """<h1>Cartilla de salud — Canela</h1><p class=m>Clínica Veterinaria Condesa · Perro, Beagle, 4 años</p>
   <h2>Vacunas</h2><table><tr><td>Antirrábica</td><td>12/03/2026</td></tr><tr><td>Múltiple</td><td>12/03/2026</td></tr><tr><td>Tos de las perreras</td><td>02/09/2026</td></tr></table>
   <h2>Notas</h2><p>Peso adecuado. Próxima revisión anual en marzo de 2027.</p>""",
  "4 Recibo del depósito": """<h1>Recibo</h1><p class=m>Inmobiliaria Condesa S.A. de C.V. · Recibo núm. 2026-0417</p>
   <p>Recibí de <b>Daniela Marchena</b> la cantidad de <b>$24,000.00 MXN</b> como depósito en garantía por el departamento ubicado en calle Bellani 122 int. 4B, col. Condesa, Ciudad de México.</p>
   <p>El depósito se devolverá al terminar el contrato, previa revisión del inmueble.</p>
   <p>Fecha: 3 de octubre de 2026 · Recibió: M. Ortega, administrador</p>""",
  "5 Acta de entrega": """<h1>Acta de entrega del departamento</h1><p class=m>Bellani 122 int. 4B, col. Condesa · Entrada 1 de noviembre de 2026</p>
   <table><tr><th>Área</th><th>Estado</th></tr><tr><td>Recámara</td><td>La ventana se atora al abrirla</td></tr>
   <tr><td>Pasillo</td><td>Mancha en la pared junto al clóset</td></tr><tr><td>Cocina</td><td>La llave gotea</td></tr>
   <tr><td>Llaves</td><td>2 llaves del departamento, 1 del buzón</td></tr></table>
   <p>Devuelva esta acta en un plazo de 15 días para proteger su depósito.</p>""",
  "6 Contrato Bellani 122": """<h1>Contrato de arrendamiento de casa habitación</h1><p class=m>Inmobiliaria Condesa S.A. de C.V. (Arrendador) y Daniela Marchena (Arrendataria)</p>
   <h2>1. Inmueble</h2><p>Calle Bellani 122 int. 4B, col. Condesa, Ciudad de México.</p>
   <h2>2. Plazo</h2><p>Doce meses, del 1 de noviembre de 2026 al 31 de octubre de 2027.</p>
   <h2>3. Renta</h2><p>$24,000 mensuales, pagaderos dentro de los primeros cinco días de cada mes.</p>
   <h2>4. Depósito en garantía</h2><p>La Arrendataria entrega un depósito de $24,000, que se devolverá dentro de los 30 días posteriores a la entrega del inmueble, previa deducción de los daños que existan.</p>
   <h2>5. Servicios</h2><p>La Arrendataria paga luz e internet. El mantenimiento del edificio corre por cuenta del Arrendador.</p>""",
  "7 Permiso de excursión": """<h1>Permiso de excursión</h1><p class=m>Escuela Primaria Benito Juárez · Grupo 3° B</p>
   <p>Nuestro grupo visitará el Museo de Ciencias el jueves 16 de octubre. Favor de entregar este formato a más tardar el viernes 10 de octubre.</p>
   <p>Alumno: Mateo Marchena · 3° B · Mtra. Salazar</p>""",
 },

 "de": {
  "1 Kfz-Versicherung": """<h1>Versicherungsbestätigung</h1><p class=m>Alba Versicherung · Police KH-5530-8812</p>
   <table><tr><th>Versicherungsnehmerin</th><td>Julia Markwart</td></tr><tr><th>Fahrzeug</th><td>Kleinwagen 2019 · Kennzeichen B-JM 4821</td></tr>
   <tr><th>Gültig</th><td>01.08.2026 – 31.01.2027</td></tr><tr><th>Vermittler</th><td>030 555 0199</td></tr></table>""",
  "2 Gehaltsabrechnung September": """<h1>Gehaltsabrechnung</h1><p class=m>Praxis Brandt GmbH · Abrechnungszeitraum 01.09.2026 – 30.09.2026</p>
   <table><tr><th>Bezeichnung</th><th class=r>Monat</th><th class=r>Kumuliert</th></tr>
   <tr><td>Bruttogehalt</td><td class=r>3.150,00</td><td class=r>28.350,00</td></tr>
   <tr><td>Lohnsteuer</td><td class=r>-398,50</td><td class=r>-3.586,50</td></tr>
   <tr><td>Sozialversicherung</td><td class=r>-638,12</td><td class=r>-5.743,08</td></tr>
   <tr><td><b>Auszahlungsbetrag</b></td><td class=r><b>2.113,38</b></td><td class=r></td></tr></table>""",
  "3 Impfpass Keks": """<h1>Impfpass — Keks</h1><p class=m>Tierarztpraxis am Park · Hund, Beagle, 4 Jahre</p>
   <h2>Impfungen</h2><table><tr><td>Tollwut (3 Jahre)</td><td>12.03.2026</td></tr><tr><td>Staupe/Hepatitis/Parvovirose</td><td>12.03.2026</td></tr><tr><td>Zwingerhusten</td><td>02.09.2026</td></tr></table>
   <h2>Hinweise</h2><p>Normalgewicht. Nächste Jahreskontrolle im März 2027.</p>""",
  "4 Kautionsquittung": """<h1>Quittung</h1><p class=m>Lenau Hausverwaltung GmbH · Quittung Nr. 2026-0417</p>
   <p>Erhalten von <b>Julia Markwart</b> den Betrag von <b>2.200,00 €</b> als Mietkaution für die Wohnung Lenaustraße 9, 3. OG, 12047 Berlin.</p>
   <p>Die Kaution wird getrennt vom Vermögen des Vermieters verzinslich angelegt (§ 551 BGB).</p>
   <p>Datum: 3. Oktober 2026 · Entgegengenommen von: M. Ortega, Hausverwaltung</p>""",
  "5 Übergabeprotokoll": """<h1>Wohnungsübergabeprotokoll</h1><p class=m>Lenaustraße 9, 3. OG · Einzug 1. November 2026</p>
   <table><tr><th>Raum</th><th>Zustand</th></tr><tr><td>Schlafzimmer</td><td>Fenster klemmt beim Öffnen</td></tr>
   <tr><td>Flur</td><td>Kratzer an der Wand neben dem Schrank</td></tr><tr><td>Küche</td><td>Wasserhahn tropft</td></tr>
   <tr><td>Schlüssel</td><td>2 Wohnungsschlüssel, 1 Briefkastenschlüssel</td></tr></table>
   <p>Bitte innerhalb von 15 Tagen zurücksenden, um die Kaution zu schützen.</p>""",
  "6 Mietvertrag Lenaustraße 9": """<h1>Wohnraummietvertrag</h1><p class=m>Lenau Hausverwaltung GmbH (Vermieter) und Julia Markwart (Mieterin)</p>
   <h2>1. Mietsache</h2><p>Lenaustraße 9, 3. OG, 12047 Berlin.</p>
   <h2>2. Mietzeit</h2><p>Unbefristet, beginnend am 1. November 2026.</p>
   <h2>3. Miete</h2><p>1.100 € Kaltmiete pro Monat, zahlbar bis zum dritten Werktag eines Monats.</p>
   <h2>4. Kaution</h2><p>Die Mieterin leistet eine Kaution von 2.200 €, die spätestens sechs Monate nach Ende des Mietverhältnisses zurückgezahlt wird, abzüglich berechtigter Forderungen.</p>
   <h2>5. Nebenkosten</h2><p>Strom und Internet trägt die Mieterin. Wasser und Heizung sind in den Nebenkosten enthalten.</p>""",
  "7 Einverständnis Ausflug": """<h1>Einverständniserklärung Ausflug</h1><p class=m>Grundschule am Kiesteich · Klasse 3b</p>
   <p>Unsere Klasse besucht am Donnerstag, 16. Oktober das Technikmuseum. Bitte bis Freitag, 10. Oktober zurückgeben.</p>
   <p>Kind: Leon Markwart · Klasse 3b · Frau Becker</p>""",
 },

 "fr": {
  "1 Assurance auto": """<h1>Attestation d'assurance</h1><p class=m>Alba Assurances · Contrat AU-5530-8812</p>
   <table><tr><th>Assurée</th><td>Claire Marchand</td></tr><tr><th>Véhicule</th><td>Citadine 2019 · Immatriculation GK-482-AB</td></tr>
   <tr><th>Validité</th><td>01/08/2026 – 31/01/2027</td></tr><tr><th>Agence</th><td>04 78 55 01 99</td></tr></table>""",
  "2 Bulletin de salaire septembre": """<h1>Bulletin de paie</h1><p class=m>Cabinet médical Rivière · Période du 01/09/2026 au 30/09/2026</p>
   <table><tr><th>Rubrique</th><th class=r>Mois</th><th class=r>Cumul</th></tr>
   <tr><td>Salaire brut</td><td class=r>2 900,00</td><td class=r>26 100,00</td></tr>
   <tr><td>Cotisations salariales</td><td class=r>-638,00</td><td class=r>-5 742,00</td></tr>
   <tr><td>Prélèvement à la source</td><td class=r>-174,00</td><td class=r>-1 566,00</td></tr>
   <tr><td><b>Net à payer</b></td><td class=r><b>2 088,00</b></td><td class=r></td></tr></table>""",
  "3 Carnet de Biscotte": """<h1>Carnet de santé — Biscotte</h1><p class=m>Clinique vétérinaire des Pentes · Chien, Beagle, 4 ans</p>
   <h2>Vaccinations</h2><table><tr><td>Rage</td><td>12/03/2026</td></tr><tr><td>CHPPi</td><td>12/03/2026</td></tr><tr><td>Toux de chenil</td><td>02/09/2026</td></tr></table>
   <h2>Remarques</h2><p>Poids normal. Prochain contrôle annuel en mars 2027.</p>""",
  "4 Reçu de la caution": """<h1>Reçu</h1><p class=m>SCI Sainte-Catherine · Reçu n° 2026-0417</p>
   <p>Reçu de <b>Claire Marchand</b> la somme de <b>950,00 €</b> au titre de caution (dépôt de garantie) pour le logement situé 14 rue Sainte-Catherine, 69001 Lyon.</p>
   <p>La caution sera restituée dans un délai maximal de deux mois après la remise des clés.</p>
   <p>Date : 3 octobre 2026 · Reçu par : M. Ortega, gestionnaire</p>""",
  "5 État des lieux": """<h1>État des lieux d'entrée</h1><p class=m>14 rue Sainte-Catherine, Lyon · Entrée le 1er novembre 2026</p>
   <table><tr><th>Pièce</th><th>État</th></tr><tr><td>Chambre</td><td>La fenêtre coince à l'ouverture</td></tr>
   <tr><td>Couloir</td><td>Marque sur le mur près du placard</td></tr><tr><td>Cuisine</td><td>Le robinet goutte</td></tr>
   <tr><td>Clés</td><td>2 clés du logement, 1 clé de la boîte aux lettres</td></tr></table>
   <p>Renvoyez ce document sous 15 jours pour protéger votre dépôt de garantie.</p>""",
  "6 Bail rue Sainte-Catherine": """<h1>Contrat de location d'un logement vide</h1><p class=m>SCI Sainte-Catherine (Bailleur) et Claire Marchand (Locataire)</p>
   <h2>1. Logement</h2><p>14 rue Sainte-Catherine, 69001 Lyon.</p>
   <h2>2. Durée</h2><p>Trois ans, du 1er novembre 2026 au 31 octobre 2029.</p>
   <h2>3. Loyer</h2><p>950 € par mois hors charges, payable le 5 de chaque mois.</p>
   <h2>4. Caution</h2><p>Le Locataire verse une caution (dépôt de garantie) de 950 €, restituée dans un délai maximal de deux mois après la remise des clés, déduction faite des sommes dues.</p>
   <h2>5. Charges</h2><p>Le Locataire paie l'électricité et internet. L'eau froide et le chauffage collectif sont en charges provisionnelles.</p>""",
  "7 Autorisation de sortie": """<h1>Autorisation de sortie scolaire</h1><p class=m>École élémentaire Les Capucins · CE2 B</p>
   <p>Notre classe visitera le Musée des Sciences le jeudi 16 octobre. Merci de rendre ce talon avant le vendredi 10 octobre.</p>
   <p>Élève : Léa Marchand · CE2 B · Mme Dubois</p>""",
 },

 "nl": {
  "1 Autoverzekering": """<h1>Verzekeringsbewijs</h1><p class=m>Alba Verzekeringen · Polisnummer AU-5530-8812</p>
   <table><tr><th>Verzekerde</th><td>Sanne Markwijk</td></tr><tr><th>Voertuig</th><td>Kleine auto 2019 · Kenteken RX-482-B</td></tr>
   <tr><th>Looptijd</th><td>01-08-2026 – 31-01-2027</td></tr><tr><th>Adviseur</th><td>030 555 0199</td></tr></table>""",
  "2 Loonstrook september": """<h1>Loonstrook</h1><p class=m>Huisartsenpraktijk De Linde · Periode 01-09-2026 – 30-09-2026</p>
   <table><tr><th>Omschrijving</th><th class=r>Maand</th><th class=r>Cumulatief</th></tr>
   <tr><td>Brutoloon</td><td class=r>3.100,00</td><td class=r>27.900,00</td></tr>
   <tr><td>Loonheffing</td><td class=r>-712,30</td><td class=r>-6.410,70</td></tr>
   <tr><td>Pensioenpremie</td><td class=r>-155,00</td><td class=r>-1.395,00</td></tr>
   <tr><td><b>Netto uitbetaald</b></td><td class=r><b>2.232,70</b></td><td class=r></td></tr></table>""",
  "3 Dierenarts Koekie": """<h1>Patiëntkaart — Koekie</h1><p class=m>Dierenkliniek Lombok · Hond, Beagle, 4 jaar</p>
   <h2>Vaccinaties</h2><table><tr><td>Rabiës</td><td>12-03-2026</td></tr><tr><td>DHPP</td><td>12-03-2026</td></tr><tr><td>Kennelhoest</td><td>02-09-2026</td></tr></table>
   <h2>Opmerkingen</h2><p>Gezond gewicht. Volgende jaarlijkse controle in maart 2027.</p>""",
  "4 Bewijs van borg": """<h1>Ontvangstbewijs</h1><p class=m>Gracht Vastgoed B.V. · Bewijs nr. 2026-0417</p>
   <p>Ontvangen van <b>Sanne Markwijk</b> het bedrag van <b>€ 2.500,00</b> als borg voor de woning aan de Oudegracht 112, 3511 AP Utrecht.</p>
   <p>De borg wordt binnen 14 dagen na het einde van de huurovereenkomst terugbetaald, onder aftrek van eventuele schade.</p>
   <p>Datum: 3 oktober 2026 · Ontvangen door: M. Ortega, beheerder</p>""",
  "5 Opleveringsrapport": """<h1>Opleveringsrapport woning</h1><p class=m>Oudegracht 112 · Ingangsdatum 1 november 2026</p>
   <table><tr><th>Ruimte</th><th>Staat</th></tr><tr><td>Slaapkamer</td><td>Raam klemt bij het openen</td></tr>
   <tr><td>Gang</td><td>Kras op de muur bij de kast</td></tr><tr><td>Keuken</td><td>Kraan druppelt</td></tr>
   <tr><td>Sleutels</td><td>2 woningsleutels, 1 brievenbussleutel</td></tr></table>
   <p>Stuur dit rapport binnen 15 dagen terug om uw borg te beschermen.</p>""",
  "6 Huurcontract Oudegracht 112": """<h1>Huurovereenkomst woonruimte</h1><p class=m>Gracht Vastgoed B.V. (Verhuurder) en Sanne Markwijk (Huurder)</p>
   <h2>1. Woning</h2><p>Oudegracht 112, 3511 AP Utrecht.</p>
   <h2>2. Duur</h2><p>Twaalf maanden, van 1 november 2026 tot en met 31 oktober 2027.</p>
   <h2>3. Huurprijs</h2><p>€ 1.250 per maand, te betalen vóór de eerste dag van elke maand.</p>
   <h2>4. Waarborgsom</h2><p>De huurder betaalt een borg van € 2.500, twee maanden kale huur, die binnen 14 dagen na het einde van de huur wordt terugbetaald, onder aftrek van schade.</p>
   <h2>5. Servicekosten</h2><p>De huurder betaalt gas, water en licht. De verhuurder betaalt de gemeentelijke heffingen.</p>""",
  "7 Toestemming schoolreisje": """<h1>Toestemming schoolreisje</h1><p class=m>Basisschool De Regenboog · Groep 5</p>
   <p>Onze klas bezoekt het Wetenschapsmuseum op donderdag 16 oktober. Lever dit formulier uiterlijk vrijdag 10 oktober in.</p>
   <p>Leerling: Daan Markwijk · Groep 5 · juf Bakker</p>""",
 },

 "pt-BR": {
  "1 Seguro do carro": """<h1>Comprovante de seguro</h1><p class=m>Alba Seguros · Apólice AU-5530-8812</p>
   <table><tr><th>Segurada</th><td>Camila Marques</td></tr><tr><th>Veículo</th><td>Hatch 2019 · Placa FKR-4B82</td></tr>
   <tr><th>Vigência</th><td>01/08/2026 – 31/01/2027</td></tr><tr><th>Corretor</th><td>(11) 5550-0199</td></tr></table>""",
  "2 Holerite setembro": """<h1>Recibo de pagamento</h1><p class=m>Clínica Horizonte Ltda. · Competência 09/2026</p>
   <table><tr><th>Descrição</th><th class=r>Mês</th><th class=r>Acumulado</th></tr>
   <tr><td>Salário</td><td class=r>5.200,00</td><td class=r>46.800,00</td></tr>
   <tr><td>INSS</td><td class=r>-572,00</td><td class=r>-5.148,00</td></tr>
   <tr><td>IRRF</td><td class=r>-403,50</td><td class=r>-3.631,50</td></tr>
   <tr><td><b>Líquido a receber</b></td><td class=r><b>4.224,50</b></td><td class=r></td></tr></table>""",
  "3 Carteira de Biscoito": """<h1>Carteira de vacinação — Biscoito</h1><p class=m>Clínica Veterinária Consolação · Cão, Beagle, 4 anos</p>
   <h2>Vacinas</h2><table><tr><td>Antirrábica</td><td>12/03/2026</td></tr><tr><td>V10</td><td>12/03/2026</td></tr><tr><td>Tosse dos canis</td><td>02/09/2026</td></tr></table>
   <h2>Observações</h2><p>Peso saudável. Próxima consulta anual em março de 2027.</p>""",
  "4 Recibo da caução": """<h1>Recibo</h1><p class=m>Imobiliária Augusta Ltda. · Recibo nº 2026-0417</p>
   <p>Recebi de <b>Camila Marques</b> a quantia de <b>R$ 4.800,00</b> a título de caução, equivalente a dois meses de aluguel, referente ao imóvel na Rua Augusta 1250, ap. 42, São Paulo - SP.</p>
   <p>A caução em dinheiro fica depositada em caderneta de poupança, conforme a Lei do Inquilinato (art. 38, § 2º).</p>
   <p>Data: 3 de outubro de 2026 · Recebido por: M. Ortega, administrador</p>""",
  "5 Termo de vistoria": """<h1>Termo de vistoria de entrada</h1><p class=m>Rua Augusta 1250, ap. 42 · Entrada em 1º de novembro de 2026</p>
   <table><tr><th>Cômodo</th><th>Estado</th></tr><tr><td>Quarto</td><td>Janela emperra ao abrir</td></tr>
   <tr><td>Corredor</td><td>Marca na parede perto do armário</td></tr><tr><td>Cozinha</td><td>Torneira pinga</td></tr>
   <tr><td>Chaves</td><td>2 chaves do apartamento, 1 da caixa de correio</td></tr></table>
   <p>Devolva este termo em até 15 dias para proteger a sua caução.</p>""",
  "6 Contrato Rua Augusta 1250": """<h1>Contrato de locação residencial</h1><p class=m>Imobiliária Augusta Ltda. (Locador) e Camila Marques (Locatária)</p>
   <h2>1. Imóvel</h2><p>Rua Augusta 1250, ap. 42, São Paulo - SP.</p>
   <h2>2. Prazo</h2><p>Trinta meses, de 1º de novembro de 2026 a 30 de abril de 2029.</p>
   <h2>3. Aluguel</h2><p>R$ 2.400 por mês, com vencimento no dia 5 de cada mês.</p>
   <h2>4. Garantia</h2><p>A Locatária entrega uma caução de R$ 4.800, equivalente a dois meses de aluguel, que será devolvida em até 30 dias após a entrega das chaves, descontados eventuais danos.</p>
   <h2>5. Encargos</h2><p>A Locatária paga luz e internet. O condomínio e o IPTU ficam por conta do Locador.</p>""",
  "7 Autorização de passeio": """<h1>Autorização de passeio</h1><p class=m>Escola Municipal Jardim das Flores · 3º ano B</p>
   <p>Nossa turma visitará o Museu da Ciência na quinta-feira, 16 de outubro. Devolva esta autorização até sexta-feira, 10 de outubro.</p>
   <p>Aluna: Beatriz Marques · 3º ano B · Prof.ª Almeida</p>""",
 },
}

here = os.path.dirname(os.path.abspath(__file__))
for lang in (sys.argv[1:] or DOCS):
    docs = DOCS[lang]
    css = CSS % PAGE.get(lang, "A4")
    os.makedirs(os.path.join(here, lang), exist_ok=True)
    for name, body in docs.items():
        with tempfile.NamedTemporaryFile("w", suffix=".html", delete=False) as f:
            f.write(f"<!doctype html><html lang={lang}><meta charset=utf-8>{css}{body}")
        out = os.path.join(here, lang, name + ".pdf")
        subprocess.run([CHROME, "--headless", "--disable-gpu", "--no-pdf-header-footer",
                        f"--print-to-pdf={out}", "file://" + f.name],
                       stderr=subprocess.DEVNULL, check=True)
        os.unlink(f.name)
        print(out)
