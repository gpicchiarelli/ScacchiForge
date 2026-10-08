# Architettura

> **Fonte:** «ARCHITETTURA GENERALE», «REFERENCE ENGINE», «BOARD REPRESENTATION», «MOVE
> REPRESENTATION», «MOVE GENERATION», «SEARCH FOUNDATION», «SEARCH TREE CLASSIFICATION»,
> «DEDUPLICATION», «EVALUATION», «NNUE», «SEARCH + EVALUATION», «PARAMETER OPTIMIZATION», «CPU
> OPTIMIZATION», «COMMON LISP / SBCL», «MULTI-THREAD», «NUMA», «SERVER ARCHITECTURE» e
> «PHILOSOPHY» della [specifica](specifica/specifica-originale.md).

## Idea

Il progetto non è un engine con molte ottimizzazioni. È un sistema sperimentale in cui algoritmi
esatti, euristiche e modelli appresi competono, e si misura quanto lavoro eliminano e quanto
valore producono. L'architettura serve a tenere questa misura onesta.

La specifica lo dice anche così: ridurre il lavoro prima di accelerarlo; riusare il lavoro già
fatto invece di usare più memoria; ridurre il problema prima di accelerare il kernel che resta;
spendere la profondità dove ha più valore informativo; non trattare le euristiche come teoremi;
misurare e classificare ogni tecnica.

Per questo il riferimento semplice e l'engine ottimizzato restano separati e confrontabili per
sempre.

## Sette separazioni

> **Deciso (specifica «ARCHITETTURA GENERALE» →
> [ADR-0002](adr/0002-implementazione-di-riferimento-come-oracolo.md))** — La specifica chiede di
> separare rigorosamente sette cose.

| # | Livello | Ruolo |
|---|---|---|
| 1 | Reference implementation | Semplice e leggibile. È l'oracolo per mosse legali, make/unmake, transizioni di stato, stato Zobrist, valutazione, aggiornamenti NNUE e risultati di ricerca dove applicabile. |
| 2 | Optimized engine | Bitboard, make/unmake su stack preallocati, `Move` packed, ricerca. Deve restare confrontabile con il riferimento. |
| 3 | Experimental research layer | Laboratorio per tecniche alternative; ogni esperimento è riproducibile, configurabile, confrontabile, misurabile, reversibile ([research](../research/README.md)). |
| 4 | Hardware-specific backends | Rilevamento delle funzioni della CPU, dispatch, SIMD. Sempre con un fallback generico. |
| 5 | Benchmark infrastructure | Microbenchmark e benchmark di engine ([misure](misure.md)). |
| 6 | Training infrastructure | Addestramento della NNUE e dei parametri. |
| 7 | Test infrastructure | Unit test, perft, fuzzing, test differenziali, regressioni ([verifica](verifica.md)). |

## Struttura concettuale della specifica

La specifica la dà così, come struttura concettuale, non come elenco di directory da creare:

```
engine/
  reference/  core/  search/  evaluation/  nnue/  transposition/
  movegen/  cpu/  simd/  platform/
  benchmarks/  tests/  research/  training/
```

> **Proposta** — Mappa sul repository. Oggi il codice sta in `src/` con tre moduli: `core/`
> (definizioni condivise), `reference/` (oracolo) e `optimized/`. Gli altri nomi della specifica
> (`search/`, `evaluation/`, `nnue/`, `transposition/`, `cpu/`, `simd/`, `platform/`,
> `training/`) diventano moduli quando la fase corrispondente ([roadmap](roadmap.md)) li
> richiede, non prima. I test stanno in [`tests/`](../tests/), i benchmark in `benchmarks/`, gli
> esperimenti in [`research/`](../research/README.md).

## Che cosa esiste oggi e che cosa è previsto

Questa sezione descrive lo stato del repository, non la specifica.

| Componente | Stato |
|---|---|
| Modello di riferimento: posizione, FEN, generazione legale, make/unmake, perft, chiavi Zobrist | esiste |
| Ricerca e valutazione semplici del riferimento, come oracolo: negamax, alpha-beta, iterative deepening con valore, mossa migliore, numero di nodi e variante principale; valutazione di materiale | esistono |
| Valutazione classica nel riferimento, con la scomposizione per termine e colore, e lo scambio dei colori di una posizione ([valutazione](valutazione.md), [ADR-0018](adr/0018-definizione-della-valutazione-classica.md)) | esistono |
| Livello ottimizzato: utilità sui bit, posizione bitboard con conversione da e verso il riferimento | esiste |
| Generatore di mosse ottimizzato, make/unmake su bitboard, perft del livello ottimizzato ([ADR-0015](adr/0015-generatore-di-mosse-del-livello-ottimizzato.md)) | esistono |
| Test | esistono |
| Benchmark | esistono |
| Attacchi dei pezzi a lunga gittata con magic bitboard, a spostamento fisso e per casa, accanto ai raggi classici ([ADR-0016](adr/0016-attacchi-dei-pezzi-a-lunga-gittata.md)) | esistono |
| Attacchi dei pezzi a lunga gittata con PEXT | previsti |
| Ricerche baseline dell'engine ottimizzato: negamax, alpha-beta fail-soft e iterative deepening a profondità fissa, con valore, mossa migliore, numero di nodi e variante principale, senza allocazione per nodo; la prima firma di ricerca ([ADR-0019](adr/0019-valutazione-e-ricerca-del-livello-ottimizzato.md)) | esistono |
| PVS, NegaScout e le altre ricerche dell'engine ottimizzato | previste |
| Transposition table, ordinamento delle mosse | previsti |
| Quiescenza, SEE, potature e riduzioni | previste |
| Valutazione classica nel livello ottimizzato, con materiale, piece-square tables e fase incrementali, e lo scambio dei colori su bitboard ([valutazione](valutazione.md), [ADR-0018](adr/0018-definizione-della-valutazione-classica.md) e [ADR-0019](adr/0019-valutazione-e-ricerca-del-livello-ottimizzato.md)) | esistono |
| NNUE | prevista |
| Backend CPU, dispatch, SIMD | previsti |
| Multi-thread, NUMA | previsti |
| Tuning dei parametri, self-play | previsti |
| Addestramento | previsto |
| Server | previsto |

«Esiste» vuol dire che il codice è nel repository. Non vuol dire che sia corretto: lo dice
`make check` sulla revisione in esame, non questo documento.

Il riferimento contiene versioni semplici di ricerca e valutazione perché la specifica gli chiede
di fare da oracolo anche per i «search results dove applicabile» («REFERENCE ENGINE») e di avere
minimax, negamax, alpha-beta e iterative deepening «come baseline» («SEARCH FOUNDATION»). Che le
ricerche e la valutazione di materiale non siano lavoro della Fase 2 lo decide
[ADR-0012](adr/0012-lettura-del-gate-di-perft.md), accettato dall'autore il 2026-10-04. La
valutazione classica del riferimento è invece lavoro della Fase 2: è l'oracolo con cui il gate
della [Fase 2](roadmap.md#fase-2) giudica la valutazione e la ricerca del livello ottimizzato.

Il repository definisce tre sistemi ASDF in `scacchiforge.asd`: `scacchiforge`,
`scacchiforge/test`, che dipende da `scacchiforge`, e `scacchiforge/bench`, che dipende da
entrambi perché legge i conteggi attesi di perft dalle tabelle dei test
([`tests/test-perft.lisp`](../tests/test-perft.lisp)). SBCL è l'unico requisito Lisp
([ADR-0004](adr/0004-nessuna-dipendenza-esterna-e-harness-proprio.md)); i target del Makefile
usano anche make. Ogni target che carica il sistema ricompila ogni sistema di `scacchiforge.asd`
che carica ([`tools/load.lisp`](../tools/load.lisp)), così che nessun file compilato con un
altro `SCF_SLIDERS` o con un'altra policy del hot path venga riusato.

### Il livello di riferimento

Il riferimento (`src/reference/`) è scritto per essere letto: una scacchiera di 64 case, liste e
vettori semplici, compilazione a `safety 3`. Non dipende dal livello ottimizzato (INV-A2).

| File | Che cosa contiene |
|---|---|
| `tables.lisp` | le tavole di passi e di raggi del riferimento, vettori di case costruiti al caricamento |
| `position.lisp` | la posizione: 64 codici di pezzo, i campi di stato, la chiave, le case dei re, lo stack di undo |
| `attacks.lisp` | se una casa è attaccata, guardando dalla casa verso l'esterno; lo scacco |
| `key.lisp` | la chiave Zobrist calcolata da zero; la costruzione di una posizione dalle sue parti |
| `fen.lisp` | lettura e scrittura della FEN, con i controlli di legalità della posizione |
| `make.lisp` | make e unmake con lo stack di undo e la chiave incrementale |
| `movegen.lisp`, `legal.lisp` | generazione pseudo-legale e filtro di legalità (fa la mossa e guarda il re) |
| `perft.lisp` | perft, divide e le posizioni con nome |
| `outcome.lisp` | matto e stallo |
| `mirror.lisp` | lo scambio dei colori di una posizione e di una mossa (`mirror-position`, `mirror-move`) |
| `eval.lisp` | la valutazione di materiale, la baseline (`evaluate-material`) |
| `classical.lisp` | la valutazione classica di [valutazione](valutazione.md): una funzione per termine, ciascuna per un colore, con gli insiemi d'attacco calcolati dalle tavole del riferimento; tutto da zero a ogni chiamata; `evaluate-classical` e la scomposizione per termine e colore `classical-breakdown` |
| `search.lisp` | negamax, alpha-beta fail-soft e iterative deepening, senza ordinamento né TT; restituiscono valore, mossa migliore, numero di nodi e variante principale (una lista); la valutazione delle foglie è un argomento (`:evaluator`, di default la classica), e un generatore con seme (`:shuffle-rng`) può permutare le mosse di ogni nodo per i test |
| `invariants.lisp` | gli invarianti di una posizione, controllati con algoritmi indipendenti dal lettore FEN e dal filtro di legalità |
| `fuzz.lisp` | partite casuali con seme che controllano gli invarianti |

Oggi il riferimento ferma i due orologi della posizione, il contatore delle semimosse e il numero
di mossa, a `+MAX-CLOCK+` = 9999999: è il valore più alto che `PARSE-FEN` accetta, perché un campo
orologio ha al massimo sette cifre. Così la FEN di ogni posizione raggiunta giocando si rilegge.
Lo prova il test `clocks-stop-at-the-largest-value-a-fen-can-hold`
([`tests/test-make-unmake.lisp`](../tests/test-make-unmake.lisp)). Nessuna regola dipende da un
orologio così alto.

## Regole tra i livelli

> **Deciso (autore → [ADR-0010](adr/0010-regole-di-indipendenza-tra-i-livelli.md))** — Rendono
> vera la separazione.

```
tests, benchmarks ──► optimized ─────────► core
        │                 │                 ▲
        │                 │ (conversione)   │
        │                 ▼                 │
        └───────────► reference ────────────┘
```

- Il riferimento non dipende dall'ottimizzato (INV-A2) e non ha dipendenze esterne (INV-A1). Non
  vede mai la struttura dell'ottimizzato.
- `core` contiene solo definizioni: costanti, codifica della mossa, tavole di chiavi, generatore
  pseudocasuale (INV-A3). Ciò che è condiviso non è giudicato dal confronto differenziale: se è
  sbagliato, lo è per entrambi. Per questo non vi sta alcun algoritmo.
- Una regola che entrambi i livelli applicano si documenta nel `core`, ma ciascun livello la
  implementa per conto proprio, così che il confronto la giudichi.
- L'ottimizzato usa il riferimento solo per convertire una posizione da e verso la propria
  struttura, mai per calcolare ciò che il confronto giudica. Oggi la conversione sta in
  [`src/optimized/bitboard-position.lisp`](../src/optimized/bitboard-position.lisp) e legge la
  struttura del riferimento: è la freccia «conversione» del disegno.
- Il server non è visto dall'engine (INV-A7, dalla specifica, non da ADR-0010).

### Che cosa significa uguale

INV-C1 dice `optimized(posizione) == reference(posizione)`. L'uguaglianza si definisce per
funzione.

> **Proposta**

| Funzione | Si confronta | Nota |
|---|---|---|
| Mosse legali | l'insieme delle mosse in forma canonica (coordinate e promozione) | l'ordine di generazione può differire |
| make/unmake | lo stato canonico: disposizione dei pezzi, lato al tratto, diritti di arrocco, casa en passant, semimosse, chiave | la politica con cui la casa en passant entra nella chiave è scritta nel `core`; ciascun livello implementa per conto proprio il test di disponibilità, e il confronto lo giudica |
| Chiave Zobrist | l'intero a 64 bit | stesse tavole, stessa politica, calcolo indipendente |
| Valutazione | il punteggio intero | definito in [valutazione](valutazione.md); per localizzare una differenza, anche la scomposizione per termine e colore |
| Feature e accumulatore NNUE | l'insieme delle feature attive e il vettore dell'accumulatore | |
| Ricerca | il valore a profondità fissa; la mossa migliore può differire tra mosse di valore uguale | solo dove la classe lo garantisce: senza potature, e con la TT in modalità di verifica (TT-1…TT-4 in [classificazione](classificazione.md#ipotesi-della-transposition-table)). Oggi si confrontano anche i nodi di negamax, che non dipendono dall'ordine delle mosse; quelli di alpha-beta no ([ADR-0019](adr/0019-valutazione-e-ricerca-del-livello-ottimizzato.md)) |

## Rappresentazione e generazione delle mosse

Dalla specifica, per il livello ottimizzato.

- Bitboard a 64 bit. Separati: bitboard dei pezzi, occupazione per colore, occupazione totale,
  lato al tratto, diritti di arrocco, en passant, contatore delle semimosse, stato incrementale,
  chiave Zobrist.
- make/unmake, senza copiare la `Position` durante la ricerca; stack preallocati per lo stato
  precedente.
- `Move` come valore packed. Nessun oggetto Lisp allocato per mossa. Buffer di mosse
  preallocati.
- Quattro fasi separate: generazione pseudo-legale, filtro di legalità, ordinamento, esecuzione.
- Si generano: mosse di pedone, catture, promozioni, en passant, arrocco, mosse di cavallo,
  alfiere, torre, donna e re.
- Da gestire con cura: inchiodature, scacchi scoperti, doppi scacchi, en passant inchiodato,
  vincoli di attacco sull'arrocco, legalità della promozione.
- Ottimizzazioni successive, ciascuna da misurare: tabelle di attacco precalcolate, magic
  bitboard, PEXT/BMI2, tabelle di lookup, bit tricks, POPCNT.

> **Proposta** — La forma concreta del riferimento (per esempio un array di 64 case) e il formato
> di `Move` non sono prescritti dalla specifica. Si decidono con un ADR quando servono.

Oggi il livello ottimizzato (`src/optimized/`) è fatto così; le scelte sono decise in
[ADR-0015](adr/0015-generatore-di-mosse-del-livello-ottimizzato.md),
[ADR-0014](adr/0014-policy-di-compilazione-del-livello-ottimizzato.md) e
[ADR-0016](adr/0016-attacchi-dei-pezzi-a-lunga-gittata.md), accettati dall'autore il 2026-10-04.

| File | Che cosa contiene |
|---|---|
| `bits.lisp` | utilità sui bit: popcount, bit meno e più significativo, PEXT e PDEP software |
| `evaluation-tables.lisp` | i parametri della valutazione classica, copia propria del livello con i nomi del [riepilogo](valutazione.md#riepilogo-dei-parametri); le tavole generate dalle formule al caricamento: piece-square tables per codice di pezzo e casa, le tavole con segno dello stato incrementale, i pesi di fase, le maschere dei termini dei pedoni; lo stato incrementale calcolato da zero |
| `bitboard-position.lisp` | la posizione: dodici bitboard di pezzi, occupazione per colore e totale, una tavola di 64 codici di pezzo, i campi di stato, la chiave, lo stato incrementale della valutazione (`psq-mg`, `psq-eg`, `phase-raw`), lo stack di undo di vettori tipizzati preallocati; la conversione da e verso il riferimento, la chiave e lo stato della valutazione calcolati da zero, il controllo di coerenza |
| `tables.lisp` | le tavole precalcolate di `(unsigned-byte 64)`: attacchi di cavallo, re e pedone, raggi, case tra due case allineate, linee |
| `rays.lisp` | gli attacchi classici per raggi con ricerca del bloccante, `ray-bishop-attacks` e `ray-rook-attacks` |
| `magic-numbers.lisp` | i numeri magici delle due disposizioni, scritti da `tools/generate-magics.lisp` (`make magics`); non si modifica a mano |
| `magic.lisp` | le maschere delle case rilevanti, la ricerca dei numeri magici da un seme, le tavole magic costruite e controllate a ogni caricamento, tranne il primo di `make magics`, che cerca senza usare i numeri nel file |
| `sliders.lisp` | le letture delle tavole magic e l'interfaccia dei pezzi a lunga gittata, `bishop-attacks` e `rook-attacks` di una casa e di un'occupazione, compilata con l'implementazione che `SCF_SLIDERS` sceglie (`fixed-magic` se non è impostata) |
| `attacks.lisp` | gli attaccanti di una casa, lo scacco |
| `make.lisp` | make e unmake sul posto, con chiave incrementale e politica dell'en passant implementata qui; make aggiorna lo stato della valutazione con le tavole con segno, unmake lo rilegge dallo stack di undo |
| `movegen.lisp` | i buffer di mosse impilati e la generazione pseudo-legale; l'arrocco con la stessa regola del riferimento |
| `legal.lisp` | il filtro di legalità con maschere di scacco e di inchiodatura; la generazione legale |
| `perft.lisp` | perft e divide: `perft-node` espande inline generazione pseudo-legale, filtro di legalità, make e unmake ([ADR-0014](adr/0014-policy-di-compilazione-del-livello-ottimizzato.md), punto 6); `bitboard-perft-with-buffer` usa un buffer ricevuto e non alloca; `bitboard-perft` e `bitboard-perft-divide`, che allocano il proprio buffer o una lista, stanno fuori dal hot path, con la policy degli altri file del livello |
| `evaluation.lisp` | la valutazione classica su bitboard: `bitboard-evaluate`, con materiale, piece-square tables e fase dallo stato incrementale e gli altri termini calcolati dagli insiemi d'attacco a ogni chiamata, e `bitboard-evaluate-from-scratch`, nel hot path e senza allocazione; fuori dal hot path la scomposizione per termine e colore `bitboard-classical-breakdown`, nella forma di quella del riferimento |
| `search.lisp` | negamax, alpha-beta fail-soft e iterative deepening con le convenzioni della ricerca del riferimento; un contesto preallocato con il buffer delle mosse, la tavola triangolare delle varianti principali e il contatore dei nodi; le funzioni di nodo nel hot path; le funzioni che restituiscono la variante come lista e le iterazioni fuori |
| `mirror.lisp` | lo scambio dei colori di una posizione bitboard (`bitboard-mirror`), fuori dal hot path |
| `policy.lisp` | la policy di compilazione dei file del hot path e la build controllata; l'elenco dei file del hot path (`*hot-path-files*`, che comprende `evaluation` e `search`); l'implementazione degli attacchi dei pezzi a lunga gittata, letta da `SCF_SLIDERS`; se make e unmake tengano lo stato incrementale della valutazione, letto da `SCF_EVAL_STATE` (le macro `when-incremental-evaluation` e `if-incremental-evaluation`, [EXP-0002](../research/exp-0002-stato-incrementale-della-valutazione.md)); se `perft-node` espande inline le funzioni di nodo (`*inline-node-functions*`); `check-compiled-choice`, con cui ogni file del hot path, quando si carica, si ferma con un errore se è stato compilato con una policy o un'implementazione diversa da quella che l'immagine chiede |

Le quattro fasi della specifica sono funzioni separate, tranne l'ordinamento, che non esiste
ancora: generazione pseudo-legale, filtro di legalità, esecuzione (make e unmake). `Move` è il
valore packed del `core`. Il perft del livello ottimizzato, dopo un riscaldamento, alloca al più
1 MiB su più di un milione di mosse, cioè meno di un byte per mossa, e lo controlla un test
([verifica](verifica.md#test-differenziale),
[ADR-0014](adr/0014-policy-di-compilazione-del-livello-ottimizzato.md), punto 5). Il test stampa
i byte allocati: su SBCL 2.6.9, macOS arm64, sono 0, e 0 anche nella CI sul commit 5d25099, su
x86-64 con SBCL 2.2.9 e su arm64 con SBCL 2.6.8 ([QA-03](limiti-e-rischi.md#qa-03)).

Lo stesso vale per la valutazione e per la ricerca del livello ottimizzato: due test chiedono al
più 1 MiB allocato su più di 800000 valutazioni e su ricerche con un contesto preallocato che
visitano più di un milione di nodi, dopo un riscaldamento
([verifica](verifica.md#valutazione-e-ricerca-del-livello-ottimizzato)). Su SBCL 2.6.9, macOS
arm64, stampano 0 byte, e 0 anche nella CI sui commit cc6fceb e b3190dc, su x86-64 con SBCL
2.2.9 e su arm64 con SBCL 2.6.8 (run 37198250566 e 37215795264,
[QA-12](limiti-e-rischi.md#qa-12)). Le funzioni di nodo della ricerca chiamano generazione,
make, unmake e valutazione: l'espansione inline del punto 6 di
[ADR-0014](adr/0014-policy-di-compilazione-del-livello-ottimizzato.md) resta del solo
`perft-node`.

## Ricerca

Dalla specifica.

- Baseline: minimax, negamax, alpha-beta, iterative deepening. Poi, da implementare e
  confrontare: PVS, NegaScout, ricerca a finestra nulla, MTD(f), transposition-driven search,
  SSS*, DUAL*.
- Nessun algoritmo si assume migliore a priori. Si confrontano con benchmark scientifici su nodi,
  tempo, profondità, hit rate della TT, cutoff rate, forza e stabilità ([misure](misure.md)).
- I nodi si classificano esplicitamente come nodi PV, Cut e All
  ([glossario](glossario.md#ricerca)). Il tipo di nodo modula potature, riduzioni, estensioni,
  ordinamento delle mosse e finestra di ricerca.

> **Proposta** — Il tipo atteso di un nodo si assegna prima di cercarlo, dal tipo del padre e
> dalla posizione della mossa; il tipo osservato si conosce dopo. Si registrano entrambi, così si
> misura quanto spesso la previsione sbaglia. Una tecnica che dipende dal tipo di nodo lo dichiara
> nella sua classificazione. In quale fase entra: [roadmap](roadmap.md#senza-fase).

## Deduplicazione

> **Deciso (specifica «DEDUPLICATION» →
> [ADR-0003](adr/0003-classificazione-delle-riduzioni-di-lavoro.md))** — La specifica tratta la
> deduplicazione come principio architetturale e ne distingue sei forme.

La colonna «Classe tipica» è una proposta.

| Forma | Esempi | Classe tipica | Che cosa si misura |
|---|---|---|---|
| Memoization | TT | `BOUNDED`; `EXACT` sotto TT-1…TT-4 | hit rate, costo della lookup, occupazione |
| Calcolo incrementale | Zobrist, materiale, pawn state, accumulatore NNUE | `EXACT` | costo dell'aggiornamento contro il ricalcolo; uguaglianza al ricalcolo (INV-C3) |
| Precalcolo | tabelle di attacco, tabelle magic/PEXT, tabelle di valutazione | `EXACT` | tempo di costruzione, memoria, cache miss |
| Riuso | mossa TT, PV, killer, history, continuation history | `EXACT` sul valore, efficacia `EMPIRICAL` | efficienza dell'ordinamento |
| Compressione | `Move` packed, entry TT compatta, feature compatte | `EXACT` se senza perdita; `PROBABILISTIC` se si perdono bit di chiave | byte per entry, falsi riscontri |
| Località di cache | array contigui, strutture compatte, accessi prevedibili | `EXACT` (stesso valore); efficacia `EMPIRICAL` | cache miss, banda di memoria |

**Regola.** Non si fa una lookup o un'operazione di cache se il suo costo supera quello del
calcolo. Si misurano sempre hit rate e costo della lookup.

> **Proposta** — Un criterio per applicarla. Sia `h` la frazione di sonde che trovano il
> risultato, `C_calc` il costo del calcolo, `C_lookup` quello della sonda, `C_store` quello
> dell'inserimento. Il meccanismo conviene se `h · C_calc > C_lookup + (1 − h) · C_store`. I tre
> costi si misurano nello stesso benchmark, comprese le cache miss che la sonda causa; non si
> stimano.

## Valutazione e NNUE

Dalla specifica.

- Prima una valutazione classica: materiale, piece-square tables, mobilità, sicurezza del re,
  struttura pedonale, pedoni passati, spazio, iniziativa, minacce. Rappresentazioni incrementali
  dove conviene.
- Poi una rete NNUE originale. Separati: estrazione delle feature, rappresentazione sparsa,
  accumulatore, aggiornamento incrementale, inferenza, addestramento. Una mossa modifica solo le
  feature necessarie.
- Backend, progressivamente: riferimento scalare, AVX2, AVX-512, VNNI, ARM NEON, SVE/SVE2. Non si
  assume che AVX-512 sia sempre più veloce di AVX2.
- Si misurano inferenza, aggiornamento dell'accumulatore, banda di memoria, latenza, throughput
  ed effetti sulla frequenza della CPU ([misure](misure.md)).

Come si verificano: [verifica](verifica.md#nnue-e-cross-platform).

> **Deciso (autore → ADR-0018)** — La valutazione classica ha una definizione unica, in
> [valutazione](valutazione.md) ([ADR-0018](adr/0018-definizione-della-valutazione-classica.md)):
> formule intere per i nove termini, una fase e una miscela fra mediogioco e finale con il
> troncamento verso zero, il punteggio dal Bianco restituito da chi muove, la simmetria dei
> colori per costruzione. Il riferimento e il livello ottimizzato la implementano ciascuno per
> conto proprio; il livello ottimizzato tiene incrementali materiale, piece-square tables e fase.

Oggi la implementano il riferimento, in `src/reference/classical.lisp`, senza stato
incrementale, e il livello ottimizzato, in `src/optimized/evaluation-tables.lisp` e
`src/optimized/evaluation.lisp`, con materiale, piece-square tables e fase incrementali in make e
unmake. Gli esempi del documento e le posizioni calcolate a mano giudicano i due livelli, e il
test differenziale li confronta termine per termine
([verifica](verifica.md#valutazione-e-ricerca-del-riferimento),
[verifica](verifica.md#valutazione-e-ricerca-del-livello-ottimizzato)). Ciascun livello tiene i
parametri in cima al proprio file, con il nome e la regola di ciascuno: sono due copie, che il
test differenziale confronta ([ADR-0019](adr/0019-valutazione-e-ricerca-del-livello-ottimizzato.md)).
Non sono nel `core` né in un file di dati: per decisione dell'autore INV-X7 si applica alla
valutazione dalla Fase 10 ([ADR-0020](adr/0020-parametri-della-valutazione-dalla-fase-10.md), che
chiude [QA-19](limiti-e-rischi.md#qa-19)). Lo stato incrementale è un
calcolo incrementale della tabella di [Deduplicazione](#deduplicazione): l'uguaglianza al
ricalcolo è provata (INV-C8), e l'aggiornamento è stato misurato contro il ricalcolo con una
regola di decisione: nella ricerca la variante con lo stato è più rapida
([EXP-0002](../research/exp-0002-stato-incrementale-della-valutazione.md), Accettato; misura di una macchina).

## Ricerca e valutazione come sistemi accoppiati

La specifica definisce la valutazione `Eθ(s)` e i parametri di ricerca `θsearch` (LMR, null
move, aspiration, pruning, estensioni, ordinamento, futility, ProbCut) e chiede di ottimizzare
`θ* = argmax Strength(θ)` con il vincolo `CPU-time ≤ T`
([ADR-0006](adr/0006-gerarchia-delle-metriche.md)). Non chiede solo l'addestramento della NNUE,
ma anche il tuning automatico della ricerca.

Gli strumenti che elenca: grid search, coordinate descent, SPSA, tuning alla Texel,
ottimizzazione bayesiana quando appropriata, ottimizzazione con self-play, regressione
automatica.

Conseguenza: ogni parametro importante vive in una configurazione, non nel codice (INV-X7). Un
esperimento cambia dati, non programma.

## Hardware e dispatch

- Rilevamento a runtime delle funzioni della CPU. x86: POPCNT, BMI2, PEXT, AVX2, AVX-512, VNNI.
  ARM: NEON, SVE, SVE2.
- Fallback generico sempre presente (INV-H1). Dispatch isolato dal resto (INV-H4).
- Ordine delle priorità, dall'alto: algoritmo, layout dei dati, località di cache, traffico di
  memoria, comportamento dei branch, SIMD, micro-ottimizzazioni. Non si usa SIMD per accelerare
  un algoritmo o un layout sbagliati.
- Non si assume che AVX-512 sia sempre più veloce di AVX2: si misura, anche l'effetto sulla
  frequenza.

Che cosa SBCL consenta di tutto questo, su quali piattaforme, è in parte aperto:
[QA-03](limiti-e-rischi.md#qa-03), [QA-04](limiti-e-rischi.md#qa-04),
[QA-06](limiti-e-rischi.md#qa-06).

## Common Lisp e SBCL

> **Deciso (specifica «COMMON LISP / SBCL» → [ADR-0001](adr/0001-common-lisp-sbcl.md))** —
> Common Lisp, SBCL primaria, GC mantenuto, kernel nativi solo a cinque condizioni.

- Il GC resta. È libero in server, tooling, configurazione, logging, orchestrazione e test.
- Nel hot path di ricerca: allocazione quasi nulla, stack e buffer di mosse preallocati, array
  tipizzati, strutture compatte, niente boxing e consing dove possibile, nessuna chiusura
  allocata. Il comportamento reale si verifica con profiling e disassembly.
- «Non trasformare Common Lisp in una caricatura di C»: si usa il linguaggio dove dà sicurezza e
  produttività e si specializzano solo i kernel critici.
- Il nucleo resta Common Lisp. Un kernel nativo è ammesso solo a cinque condizioni
  ([limiti](limiti-e-rischi.md#microkernel-nativi)).

## Multi-thread e NUMA

Prima single-thread. Poi stato di ricerca e stack locali al thread, ricerca parallela, Lazy SMP,
TT condivisa o opportunistica. Si evitano lock globali nel percorso critico (INV-A6). Da studiare:
scalabilità, contesa, coerenza di cache, false sharing, banda di memoria.

Per i sistemi multi-socket la specifica chiede di preparare l'architettura e di preferire, quando
conviene, TT locale, stato di ricerca locale, memoria locale al worker e dati replicati in sola
lettura, a strutture globali contese.

## Server

```
Browser/WebSocket
        ↓
   Game Actor
        ↓
   Bot Scheduler
        ↓
Engine Worker Pool
        ↓
   Chess Engine
```

Il Game Actor non si blocca durante la ricerca del bot. La prima versione è single-node ma
pronta per il cloud. L'architettura si predispone a scalabilità orizzontale, partizionamento per
partita, proprietà degli attori, isolamento dei guasti, backpressure, idempotenza e osservabilità,
senza introdurre database o sistemi distribuiti nel percorso critico dell'engine.

> **Aperto (QA-11)** — La specifica descrive il server ma non gli assegna una fase.
> [QA-11](limiti-e-rischi.md#qa-11).
