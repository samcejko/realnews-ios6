# RealNews pro iOS 6

Univerzální RSS a Atom čtečka pro **iOS 6.x zařízení s jailbreakem** (armv7, např. iPad 2, iPhone 4S),
s druhým sestavením pro **64bitová zařízení s iOS 14–17** (iPhone X a novější: rootless jailbreaky a TrollStore),
která zachovává klasický lesklý skeuomorfní vzhled iOS 6.

Vychází z návrhu [RealNews](https://github.com/OlivierGuinart/RealNews). Čtečka extrahuje a zpřístupňuje **veškerá metadata a pole** z výstupu feedu – nejen běžné titulky a anotace, ale každý vlastní atribut, tag s namespacem (`dc:creator`, `content:encoded`, `media:content`, `guid`, `category`) i autorská metadata.

Dnešní feedy a weby vyžadují TLS 1.2/1.3 s moderními šiframi, které původní síťový stack iOS 6 neumí vyjednat. Aplikace proto obsahuje vlastní vestavěný TLS stack (Mbed TLS) a HTTP klienta: vše běží přímo na zařízení bez nutnosti jakéhokoliv proxy serveru.

## Funkce

- **Inspektor všech polí a metadat**: Samostatná obrazovka odhalující každý XML tag, atribut a autorské pole s možností zkopírování hodnoty na jedno klepnutí a otevíráním odkazů.
- **Tabulka metadat RealNews**: Články se vykreslují v responzivním HTML s integrovanou tabulkou `<table class="extradata">` pro podrobné vlastnosti feedu.
- **Univerzální rozhraní**:
  - iPad: Plnohodnotný `UISplitViewController` (kanály a seznam zpráv vlevo, čtečka a metadata vpravo).
  - iPhone: Klasický 3-stupňový navigační zásobník s plynulými přechody.
- **Chytrá správa mezipaměti**:
  - Mezipaměť obrázků s LRU limity, zobrazením obsazeného místa a promazáním na jedno klepnutí.
  - Nastavitelná doba uchovávání článků (7, 14, 30 dní nebo trvale) a limit počtu článků na feed.
- **Přílohy a média**: Miniatury, podcasty a přílohy se zobrazením velikosti souboru.
- **Vyhledávání a chytré pohledy**: Rychlé vyhledávání podle titulku, autora i textu, plus vyhrazené pohledy „Všechny nepřečtené“ a „S hvězdičkou“.
- **Autentický iOS 6 vzhled**: Lesklý navigační pruh, modré odznáčky nepřečtených zpráv, plátěné pozadí a skeuomorfní ikona.
- **Dvojjazyčnost**: Kompletní lokalizace do češtiny i angličtiny.
