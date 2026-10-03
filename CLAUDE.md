# PDF Pro (PDFEasy-iOS)

App iOS e Mac (Catalyst) per creare, modificare, firmare e convertire PDF. SwiftUI + PDFKit, abbonamenti StoreKit, backend analitico in Grogu (`~/Development/Balzo/grogu`).

## Come si lavora qui

### Come si verifica l'esito
- **Test**: `bundle exec fastlane test`, che fa partire prima il lint dei cataloghi. Per il Mac: `fastlane test_mac`.
- **Interfaccia**: screenshot dal simulatore, guardato davvero. Un test verde può controllare il percorso e non l'esito, vedi `docs/trappole/test-e-verifica.md`.
- **Prezzi, testi, prodotti**: rilettura via API ASC dello stato finale **in tutti i territori e in tutte le lingue**, non solo dove è stata presa la decisione. Una foto del paywall da un simulatore con storefront diverso (USA) è il controllo più economico.
- **Dati**: query sul DB di Grogu dopo il cambio, con `DISTINCT` sulle chiavi e attenzione a fusi e date di rinnovo.
- **Push**: `git ls-remote`, non l'output di `git push`.

### Azioni irreversibili o verso l'esterno (chiedere sempre prima)
Passano dall'agente `operatore-store`: dry-run, conferma, rilettura.
- `fastlane beta | release | release_mac | upload_ipa | metadata*`
- `fastlane/scripts/` (`push_texts`, `push_screenshots`, `create_event`, `submit_review`)
- gli script dei prezzi e delle offerte
- le scritture su Search Ads (campagne, bid, budget)
- i deploy di Grogu

### Trappole già pagate
In `docs/trappole/`. L'indice è `docs/trappole/README.md`, e i file sono divisi per area: prezzi e ASC, firma e release, cataloghi e lingue, SwiftUI e PDFKit, test e verifica, dati e metriche. Leggi quello dell'area che tocchi prima di iniziare.

### Agenti specifici
- `operatore-store` (`.claude/agents/`): tutte le scritture verso Apple.
