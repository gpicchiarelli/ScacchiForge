# ADR-0017 — Percorso di ricerca per le alternative `EXACT` con le stesse uscite

- **Stato:** Accettata
- **Data:** 2026-10-04; scritta e accettata lo stesso giorno, per decisione dell'autore in sessione
- **Rapporto con la specifica:** chiude [QA-17](../limiti-e-rischi.md#qa-17). Riguarda
  «RESEARCH METHODOLOGY», che chiede a «ogni nuova tecnica» la sequenza ipotesi, razionale
  matematico, implementazione, microbenchmark, benchmark di engine, self-play, validazione
  statistica, accettazione o rifiuto (INV-X3), e «MOVE GENERATION» («Ogni alternativa deve
  essere benchmarkata»). Per le alternative del punto 1 dichiara che le tappe del self-play e
  della validazione statistica non si applicano: il testo della specifica non cambia, cambia
  come la sequenza si applica a questa classe, e questo campo lo dichiara. È la decisione
  dell'autore, Giacomo Picchiarelli, presa il 2026-10-04 fra le opzioni di QA-17 («ADR per le
  EXACT»).
- **Riferimenti:** INV-X3, INV-X11, INV-C1, INV-C4,
  [classificazione](../classificazione.md#regole-duso),
  [misure](../misure.md#due-livelli-di-benchmark), [research](../../research/README.md),
  [EXP-0001](../../research/exp-0001-attacchi-dei-pezzi-a-lunga-gittata.md),
  [ADR-0014](0014-policy-di-compilazione-del-livello-ottimizzato.md),
  [ADR-0015](0015-generatore-di-mosse-del-livello-ottimizzato.md),
  [ADR-0016](0016-attacchi-dei-pezzi-a-lunga-gittata.md), [QA-17](../limiti-e-rischi.md#qa-17)

## Contesto

INV-X3 (Deciso, dalla «RESEARCH METHODOLOGY») accetta una tecnica solo dopo ipotesi, razionale
matematico, implementazione, microbenchmark, benchmark di engine, self-play e validazione
statistica. Nella Fase 1 il livello ottimizzato non ha una ricerca. Tre scelte fatte anche per
la velocità vi sono entrate prima che quella sequenza si potesse completare, e
[QA-17](../limiti-e-rischi.md#qa-17) le registrava come scostamento da INV-X3:

- il default `:fixed-magic` degli attacchi dei pezzi a lunga gittata
  ([ADR-0016](0016-attacchi-dei-pezzi-a-lunga-gittata.md)), con il suo record,
  [EXP-0001](../../research/exp-0001-attacchi-dei-pezzi-a-lunga-gittata.md), allora In corso;
- il filtro di legalità per maschere
  ([ADR-0015](0015-generatore-di-mosse-del-livello-ottimizzato.md), punto 5), scelto anche per
  il costo per mossa;
- l'espansione delle funzioni di nodo nel perft
  ([ADR-0014](0014-policy-di-compilazione-del-livello-ottimizzato.md), punto 6).

Ognuna restituisce le stesse uscite dell'implementazione che sostituisce, o del riferimento, e
cambia solo il tempo. Per una sostituzione del genere un self-play a nodi fissi giocherebbe le
stesse partite da entrambi i lati. La questione era come INV-X3 le si applica.

## Decisione

1. **Campo.** Un'implementazione alternativa classificata `[EXACT]` le cui uscite sono identiche
   a quelle dell'implementazione esistente o del riferimento. L'identità è provata da
   un'equivalenza esaustiva o differenziale contro l'implementazione esistente o contro il
   riferimento, e dal perft.
2. **Che cosa soddisfa INV-X3.** Per un'alternativa del punto 1 la metodologia di INV-X3 è
   soddisfatta dalla prova di equivalenza, dal microbenchmark e dal benchmark di engine:
   `make bench`, con il suo registro dell'ambiente
   ([misure](../misure.md#registro-dellambiente)) e una regola di decisione.
3. **Self-play e validazione statistica non si applicano.** A nodi fissi, uscite identiche
   danno partite identiche. A tempo fisso, una differenza di forza è una differenza di
   velocità, che il benchmark ha già misurato.
4. **Limiti.**
   - Non copre una tecnica che cambia un'uscita qualsiasi: il valore di una ricerca, la mossa
     scelta, il numero di nodi di una ricerca. Per quella vale la metodologia intera.
   - L'equivalenza deve essere un test in `make check` oppure in un target profondo documentato.
   - Il benchmark deve essere eseguito su una revisione committata e pulita.

**Che cosa è `make bench` oggi.** Il benchmark del punto 2 è `make bench`, come l'ha nominato
l'autore. Oggi `make bench` non ha righe di una ricerca, perché il livello ottimizzato non ne
ha una: misura le utilità sui bit, gli attacchi dei pezzi a lunga gittata e il perft dei due
livelli, e [misure](../misure.md#due-livelli-di-benchmark) chiama le righe di perft un
microbenchmark composto, non un benchmark di engine. Per un'alternativa della Fase 1 la
condizione del punto 2 è quindi `make bench` com'è sulla revisione misurata.

**Classificazione:** nessuna riduzione di lavoro introdotta. Il campo del punto 1 è definito
dall'etichetta `[EXACT]` ([classificazione](../classificazione.md#le-sette-etichette)) e
dall'identità delle uscite.

**Invarianti:** INV-X3, di cui dice come si applica a questa classe. INV-C1 e INV-C4 danno la
prova di equivalenza (test differenziale, perft).

**Verifica:** per ogni alternativa, il test di equivalenza in `make check` o nel target
profondo, il perft, e l'output di `make bench` con il registro dell'ambiente, eseguito su una
revisione committata e pulita e letto con la regola di decisione.

## Applicazione ai casi di QA-17

Per ciascuno dei tre casi, le condizioni dei punti 1-4 e l'evidenza che c'è. Gli identificativi
dei test sono `suite/nome`, come li stampa `make test`.

### Default `:fixed-magic` (ADR-0016, EXP-0001)

| Condizione | Evidenza |
|---|---|
| `[EXACT]` | [ADR-0016](0016-attacchi-dei-pezzi-a-lunga-gittata.md) (Classificazione); docstring di `initialise-magic-tables` e `find-magic-number` ([`src/optimized/magic.lisp`](../../src/optimized/magic.lisp)) e di `magic-bishop-attacks` ([`src/optimized/sliders.lisp`](../../src/optimized/sliders.lisp)) |
| Uscite identiche | le tre implementazioni restituiscono lo stesso attacco per ogni casa e ogni occupazione; ne seguono le stesse mosse, nello stesso ordine, e lo stesso perft ([EXP-0001](../../research/exp-0001-attacchi-dei-pezzi-a-lunga-gittata.md), sezione 2) |
| Equivalenza esaustiva, in `make check` | `optimized/every-slider-implementation-matches-a-naive-walk-on-every-relevant-occupancy`: per ogni casa e ogni sottoinsieme delle sue case rilevanti, da solo e con bit casuali fuori dalla maschera, ogni implementazione deve dare l'attacco di un cammino casa per casa e quello di `:ray`, l'implementazione esistente. In più `optimized/slider-implementations-agree-on-random-occupancies` e `optimized/slider-attacks-match-a-naive-walk` ([`tests/test-optimized.lisp`](../../tests/test-optimized.lisp)) |
| Perft | `optimized-perft` in `make check`, con `:fixed-magic`, anche nella CI (run 37183294754 sul commit c15291e, sulle due immagini: [QA-12](../limiti-e-rischi.md#qa-12)); `SCF_SLIDERS=fixed-magic make test`, `SCF_SLIDERS=magic make test` e `SCF_SLIDERS=ray make test` su un clone pulito di 5d25099 (EXP-0001, sezione 10); `make perft-deep` con il default, sulla macchina dell'autore |
| Microbenchmark e `make bench`, con il registro e una regola | `make bench`: le righe degli attacchi di torre e alfiere di ogni implementazione e le righe di perft del livello ottimizzato in passate `fixed-magic magic ray ray magic fixed-magic`, dopo il registro dell'ambiente. La regola di decisione è in EXP-0001, sezione 1, nel commit 5d25099, scritta prima dell'esecuzione confermativa |
| Revisione committata e pulita | l'esecuzione confermativa di EXP-0001 è su un clone di 5d25099, e il registro dell'ambiente dice «5d25099, working tree clean» (EXP-0001, sezione 10) |

Esito: le condizioni sono soddisfatte. EXP-0001 è chiuso con esito Accettato (sezione 9 del
record). Restano scritti nel record i limiti della misura: una macchina (Apple M4, macOS,
SBCL 2.6.9), x86-64 non misurato, il carico della macchina salito durante l'esecuzione, la
regola scritta dopo le misure esplorative e prima dell'esecuzione confermativa. Questo ADR non
pone condizioni su questi punti; che cosa porterebbe a rivedere il default è in ADR-0016
(Valutazione).

### Filtro di legalità per maschere (ADR-0015, punto 5)

| Condizione | Evidenza |
|---|---|
| `[EXACT]` | [ADR-0015](0015-generatore-di-mosse-del-livello-ottimizzato.md) (Classificazione); docstring di `filter-legal` ([`src/optimized/legal.lisp`](../../src/optimized/legal.lisp)) |
| Uscite identiche | l'insieme delle mosse legali, uguale a quello del riferimento, che decide la legalità facendo la mossa e controllando il re |
| Equivalenza differenziale, in `make check` e in un target profondo | la suite `differential` di `make check` confronta la lista ordinata delle mosse legali, e quella delle pseudo-legali, su ogni posizione visitata, decine di migliaia ([`tests/test-differential.lisp`](../../tests/test-differential.lisp)); `make differential-deep` lo fa su milioni di posizioni; la suite `optimized-movegen` esegue sul livello ottimizzato la suite dei casi speciali |
| Perft | `optimized-perft` in `make check`; `make perft-deep` |
| Microbenchmark e `make bench`, con il registro e una regola | **Mancano.** Nel livello ottimizzato non c'è un'altra implementazione della legalità con cui misurare il filtro (ADR-0015, Valutazione). `make bench` misura il perft del livello ottimizzato, che contiene il filtro, e quello del riferimento, che ha un'altra rappresentazione oltre a un altro algoritmo: nessuna riga confronta il filtro con un'alternativa. Nessuna regola di decisione è dichiarata |
| Revisione committata e pulita | nessuna misura del filtro da collocare su una revisione |

Esito: le condizioni di equivalenza sono soddisfatte, quelle di misura no. Mancano un
microbenchmark e `make bench` che confrontino il filtro con un'alternativa con le stesse uscite,
letti con una regola di decisione dichiarata ed eseguiti su una revisione committata e pulita.
Finché mancano, la ragione di velocità di ADR-0015 (fare e disfare ogni mossa pseudo-legale
costa di più: Alternative considerate) non ha l'evidenza che questo ADR chiede. L'altra ragione
di ADR-0015, un algoritmo diverso da quello dell'oracolo (RSK-05), non è una ragione di velocità,
e questo ADR non la riguarda.

### Espansione delle funzioni di nodo nel perft (ADR-0014, punto 6)

| Condizione | Evidenza |
|---|---|
| `[EXACT]` | regola 7 della [classificazione](../classificazione.md#regole-duso): un'ottimizzazione che calcola lo stesso valore con meno istruzioni, l'inlining fra gli esempi, è `EXACT` se le dichiarazioni sono vere; l'evidenza è `make test-checked` (ADR-0014, punto 3) |
| Uscite identiche | lo stesso sorgente, espanso o chiamato (`with-node-functions` e `node-legal-moves`, [`src/optimized/perft.lisp`](../../src/optimized/perft.lisp)); l'uscita è il conteggio di perft |
| Equivalenza differenziale, in `make check` | la variante espansa, quella del build, contro il riferimento: `differential/perft-of-random-positions` (il perft dei due livelli su posizioni casuali) e il `divide` di `optimized-perft`, confrontato con quello del riferimento. La variante chiamata la compila ed esegue solo `make hot-path`, target documentato fuori da `make check`, che ne controlla i tre perft con i conteggi attesi; le funzioni che chiama sono quelle che la suite `differential` confronta con il riferimento |
| Perft | `optimized-perft` in `make check`; `make perft-deep`; per la variante chiamata, i tre perft di `make hot-path` |
| Microbenchmark | `make hot-path`, parte 4: il tempo CPU di tre perft con le funzioni di nodo espanse e chiamate, in due passate, in ordine e in ordine inverso ([`tools/hot-path.lisp`](../../tools/hot-path.lisp); ADR-0014, Conseguenze) |
| `make bench`, con il registro e una regola | **Mancano.** `make bench` non misura la variante chiamata. `make hot-path` stampa l'implementazione e la versione di SBCL, il sistema e l'architettura, non il registro dell'ambiente (né la revisione, né lo stato dell'albero di lavoro, né il carico). Nessuna regola di decisione è dichiarata |
| Revisione committata e pulita | non registrata: ADR-0014 non dice su quale revisione è stato eseguito `make hot-path` |

Esito: le condizioni di equivalenza sono soddisfatte, quelle di misura no. Manca una misura delle
due varianti con il registro dell'ambiente, letta con una regola di decisione dichiarata ed
eseguita su una revisione committata e pulita.

## Conseguenze

- [QA-17](../limiti-e-rischi.md#qa-17) è chiusa; la voce resta, marcata «Risolta da ADR-0017».
- [EXP-0001](../../research/exp-0001-attacchi-dei-pezzi-a-lunga-gittata.md) è chiuso, Accettato.
- Per questa classe la decisione si prende sulla prova di equivalenza e sul tempo. Per il
  punto 3 le metriche della [gerarchia](../misure.md#gerarchia-delle-metriche) sopra l'NPS
  cambiano solo attraverso il tempo per nodo; la decisione non poggia sul solo NPS (INV-X11).
- Una tecnica che cambia un'uscita (una potatura, una riduzione, un'estensione, un ordinamento
  che cambia i nodi di una ricerca) segue ancora l'intera sequenza (punto 4).
- Due dei tre casi di QA-17, il filtro per maschere e l'espansione delle funzioni di nodo, non
  soddisfano ancora le condizioni. Sono in uso perché li decidono ADR-0015 e ADR-0014,
  accettati il 2026-10-04; che cosa manca a ciascuno è scritto sopra.
- Rimandano a questo ADR INV-X3 ([invarianti](../invarianti.md#metodo)), la
  [guida del repository](../../CLAUDE.md), [research](../../research/README.md),
  [misure](../misure.md#due-livelli-di-benchmark) e [CONTRIBUTING](../../CONTRIBUTING.md).

## Alternative considerate

- *Tenere come default la baseline `:ray` finché EXP-0001 non si chiude* (la prima opzione di
  QA-17): non scelta dall'autore.
- *Un ADR che rimandi benchmark di engine, self-play e validazione statistica a quando la
  ricerca esiste, con il record aperto* (l'esempio che QA-17 dava della seconda opzione): non
  scelta; l'autore ha deciso che per questa classe self-play e validazione statistica non si
  applicano (punto 3).

## Valutazione

- Questione chiusa: [QA-17](../limiti-e-rischi.md#qa-17).
- Si verifica con i test di equivalenza di `make check` e dei target profondi: se uno fallisce,
  l'alternativa non ha più le stesse uscite ed esce dal campo del punto 1.
- La misura di `make bench` è di una macchina in un momento (INV-X2): un'altra macchina può
  ordinare diversamente le alternative. Per il default `:fixed-magic`, che cosa porterebbe a
  rivederlo è in [ADR-0016](0016-attacchi-dei-pezzi-a-lunga-gittata.md) (Valutazione).
