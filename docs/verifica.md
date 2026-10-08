# Verifica

> **Fonte:** «REFERENCE ENGINE», «MOVE GENERATION», «PERFT», «NULL MOVE», «NNUE», «TESTING»,
> «CROSS-PLATFORM», «POSITION CORPUS» e «PERFORMANCE GATES» della
> [specifica](specifica/specifica-originale.md). Decisioni:
> [ADR-0002](adr/0002-implementazione-di-riferimento-come-oracolo.md),
> [ADR-0008](adr/0008-perft-gate-obbligatorio.md),
> [ADR-0010](adr/0010-regole-di-indipendenza-tra-i-livelli.md),
> [ADR-0012](adr/0012-lettura-del-gate-di-perft.md).

## Principio

L'ottimizzazione non deve mai rendere impossibile la verifica della correttezza (INV-A4). Per
questo c'è un riferimento semplice che fa da oracolo e un confronto continuo con l'engine
ottimizzato.

> **Proposta** — La catena di fiducia ha tre anelli.

```
valori pubblicati di perft ──► riferimento ──► ottimizzato
```

Il riferimento è giudicato da fonti esterne (i valori pubblicati). L'ottimizzato è giudicato dal
riferimento. Se il primo anello manca, il secondo e il terzo possono concordare nello stesso
errore.

## Strumenti

La specifica elenca: unit test, perft, test su posizioni legali casuali, test differenziale tra
riferimento e ottimizzato, regressione di ricerca, regressione NNUE, regressione cross-platform,
fuzzing, regressione dei benchmark.

> **Proposta** — Gli stessi strumenti, ordinati per ciò che giudicano.

| Strumento | Che cosa giudica | Oracolo |
|---|---|---|
| Unit test | una funzione o una transizione di stato | casi scritti a mano |
| Perft | la generazione delle mosse legali e make/unmake, per conteggio | valori pubblicati; valori di regressione ([ADR-0012](adr/0012-lettura-del-gate-di-perft.md)) |
| Suite dei casi speciali | arrocco, en passant, promozioni, inchiodature, scacchi, casi limite | casi scritti a mano, con il risultato noto |
| Fuzzing | gli invarianti su posizioni legali casuali | INV-C1, INV-C2, INV-C3 |
| Test differenziale | l'ottimizzato contro il riferimento, su milioni di posizioni casuali | il riferimento |
| Regressione di ricerca | che la ricerca non cambi senza che lo si voglia | la firma di ricerca precedente |
| Suite per tecnica | i punti deboli noti di una tecnica | posizioni con risultato noto |
| Regressione NNUE | inferenza e aggiornamento incrementale | il riferimento scalare |
| Regressione cross-platform | che la logica non dipenda dalla piattaforma | gli stessi valori su ogni piattaforma |
| Regressione dei benchmark | la prestazione, non la correttezza | la baseline ([misure](misure.md)) |

## Perft

> **Deciso (specifica «PERFT» → [ADR-0008](adr/0008-perft-gate-obbligatorio.md))** — Perft è un
> gate obbligatorio.

Perft conta le foglie dell'albero delle mosse legali fino a una profondità. Prima di introdurre
ricerca aggressiva tutte le posizioni di perft devono passare (INV-C4, INV-X8). Si testano
arrocco, en passant, promozioni, inchiodature, scacchi, scacchi scoperti e casi limite.

> **Deciso (autore → [ADR-0012](adr/0012-lettura-del-gate-di-perft.md))** — Valori attesi e
> regole di esecuzione.

- **Due tipi di valori attesi.** *Pubblicati:* una fonte pubblica è citata. Giudicano il
  riferimento dall'esterno. *Di regressione:* valori che nessuna fonte pubblica riporta, per
  esempio l'output di questo engine registrato perché un cambiamento di comportamento si veda
  presto. Non sono un oracolo esterno.
- **Dove sta la provenienza.** Nel file dei test,
  [`tests/test-perft.lisp`](../tests/test-perft.lisp): le fonti nell'intestazione, e quali
  profondità di ogni posizione sono pubblicate. I numeri non si copiano in questi documenti.
- **Che cosa giudica il gate.** Il riferimento si giudica dall'esterno solo sui valori pubblicati
  (INV-C4). I valori di regressione restano nel gate: segnalano un cambiamento, ma da soli non
  dicono quale dei due valori è giusto.
- **Posizioni.** Quelle di uso comune nella comunità: posizione iniziale e posizioni scelte per
  arrocco, en passant, promozioni e inchiodature.
- **`divide`** (perft per ogni mossa radice) serve a localizzare un errore, confrontandolo con un
  valore pubblicato o con l'altro livello.
- **Profondità.** Quella del gate rapido e quella dei perft profondi si decidono nei test. I perft
  profondi sono un target a parte, `make perft-deep`, fuori da `make check`.
- **Limite del conteggio.** Due errori possono compensarsi, e due insiemi di mosse diversi possono
  avere la stessa cardinalità. Per questo il test differenziale confronta gli insiemi di mosse,
  non solo i totali.
- Oggi i valori attesi sono letti dalle stesse tabelle per i due livelli: il perft
  dell'ottimizzato ([`tests/test-optimized-perft.lisp`](../tests/test-optimized-perft.lisp)) non
  ne ha una copia.

## Suite dei casi speciali

La specifica elenca ciò che si gestisce con cura: inchiodature, scacchi scoperti, doppi scacchi,
en passant inchiodato, vincoli di attacco sull'arrocco, legalità della promozione.

> **Proposta** — Casi che la suite deve coprire, oltre all'elenco della specifica.

| Area | Casi |
|---|---|
| Arrocco | diritti persi dopo una mossa di re o di torre; diritti persi se la torre viene catturata; casa attraversata attaccata; re sotto scacco; case occupate tra re e torre |
| En passant | la casa esiste solo dopo una spinta doppia; la cattura espone il re lungo la traversa (due pedoni escono dalla linea); la cattura risolve uno scacco; un pedone inchiodato in diagonale cattura en passant solo lungo la linea dell'inchiodatura |
| Promozioni | i quattro pezzi; con cattura; che dà scacco; su ogni colonna e per entrambi i colori |
| Inchiodature | un pezzo inchiodato si muove solo lungo la linea dell'inchiodatura; inchiodatura di un pezzo che dà scacco |
| Scacchi | singolo: cattura, interposizione, mossa del re; doppio: solo il re |
| Scacchi scoperti | il pezzo che si muove scopre un attacco al re, con e senza scacco diretto |
| Casi limite | matto e stallo; il re non arretra lungo la linea di un pezzo a lunga gittata che gli dà scacco; posizioni con pochissimi pezzi; molte donne |

## Fuzzing

La specifica chiede di generare milioni di posizioni casuali e di confrontare
`optimized(posizione) == reference(posizione)`, e un fuzzer di posizioni legali.

> **Proposta**

- **Generatore.** Parte dalla posizione iniziale e dalle posizioni del corpus e avanza con mosse
  casuali scelte tra quelle legali del riferimento. Le posizioni sono legali per costruzione: ogni
  passo è una mossa legale. Il generatore pseudocasuale è deterministico ([ADR-0005](adr/0005-chiavi-zobrist-da-prng-deterministico.md)).
- **Riproducibilità.** Un fallimento stampa il seme e la FEN. Una posizione che fallisce diventa un
  test di regressione.
- **Controlli per posizione.** INV-C1 per mosse legali e valutazione; INV-C2 per ogni mossa
  legale; INV-C3 dopo ogni make e unmake.
- **Validità della posizione.** Un validatore controlla che la posizione sia legale: un solo re
  per colore, il lato che non muove non è sotto scacco, niente pedoni sulle traverse estreme,
  diritti di arrocco coerenti con i pezzi, casa en passant plausibile.
- **Scala.** Quanti milioni si eseguono in `make check` e quanti fuori si decide nei test, senza
  fissare qui un numero.

> **Aperto (QA-16)** — Le passeggiate casuali dalla posizione iniziale producono una
> distribuzione sbilanciata (molte aperture, poche posizioni di finale). La specifica chiede anche
> «rare legal states». Come bilanciare il corpus: [QA-16](limiti-e-rischi.md#qa-16).

## Test differenziale

Si confronta con la definizione di *uguale* in [architettura](architettura.md#che-cosa-significa-uguale).
Si esegue sul corpus e sul fuzzer. Vale per mosse legali, make/unmake, chiave Zobrist,
valutazione, feature NNUE e, dove applicabile, per il valore di ricerca.

Oggi il test differenziale ha quattro parti.

- **Conversione.** Riferimento → bitboard → riferimento, con le chiavi che i due livelli
  calcolano ciascuno per conto proprio ([`tests/test-bitboard.lisp`](../tests/test-bitboard.lisp)).
- **Mosse e stato** ([`tests/test-differential.lisp`](../tests/test-differential.lisp), suite
  `differential`). Su ogni posizione visitata: l'insieme delle mosse legali, confrontato come
  lista ordinata di mosse packed (flag compresi), e l'insieme delle mosse pseudo-legali, che i due
  livelli definiscono allo stesso modo; lo scacco; per ogni casa e per ciascun colore, se un pezzo
  di quel colore la attacca (`bitboard-square-attacked-p` contro `square-attacked-p` del
  riferimento); l'insieme dei pezzi che danno scacco (`bitboard-checkers`) contro quello trovato
  dal test camminando sulla scacchiera da ogni pezzo avversario con la propria geometria, che non
  è quella di nessuno dei due livelli; la chiave dell'ottimizzato, quella che calcola da zero e
  quella del riferimento. Dopo ogni mossa legale fatta su entrambi: lo stato intero (pezzi, lato
  al tratto, diritti di arrocco, casa en passant, orologi), la chiave incrementale
  dell'ottimizzato contro la sua chiave calcolata da zero e contro quella del riferimento, e la
  coerenza interna dei bitboard, che comprende lo stato incrementale della valutazione
  ricalcolato da zero (INV-C8); dopo l'unmake, lo stato esatto di prima, stato della valutazione
  compreso, e la profondità dello stack di undo (`bbp-ply`). Le posizioni: quelle delle tabelle di perft e i loro figli; quelle della suite dei
  casi speciali e dei test di make/unmake e di Zobrist (le FEN si leggono dai sorgenti dei test:
  il test `the-special-case-positions-are-found-in-the-sources` controlla che la lettura le
  trovi), quelle dei test di FEN e del fuzzer, con i loro figli; partite casuali con seme
  dichiarato in cui i due livelli fanno le stesse mosse, ciascuna disfatta per intero alla fine
  sull'ottimizzato; in più il perft dei due livelli su posizioni casuali. `make test` ne esegue
  decine di migliaia; `make differential-deep` milioni. I semi e il numero di posizioni sono nel
  file dei test, e il test li stampa.
- **Casi speciali.** La suite dei casi speciali
  ([`tests/test-movegen.lisp`](../tests/test-movegen.lisp)) si esegue su entrambi i livelli:
  suite `movegen` sul riferimento, `optimized-movegen` sull'ottimizzato.
- **Valutazione e ricerca** ([`tests/test-optimized-evaluation.lisp`](../tests/test-optimized-evaluation.lisp),
  [`tests/test-optimized-search.lisp`](../tests/test-optimized-search.lisp), suite
  `differential`). La scomposizione della valutazione per termine e colore e il punteggio, sulle
  posizioni delle tabelle di perft, dei casi speciali e del fuzzer; lo stato incrementale della
  valutazione dopo ogni make e ogni unmake; il valore della ricerca a profondità fissa (delle
  baseline e della ricerca di default della Fase 3) e il numero di nodi di negamax; le varianti
  principali dei due livelli, rigiocate dal riferimento; i valori e le varianti della firma di
  ricerca, giudicati dal riferimento. Il dettaglio è in
  [Valutazione e ricerca del livello ottimizzato](#valutazione-e-ricerca-del-livello-ottimizzato)
  e in [Ricerca della Fase 3](#ricerca-della-fase-3).

Accanto, sul solo livello ottimizzato ([`tests/test-optimized.lisp`](../tests/test-optimized.lisp),
suite `optimized`):

- le tavole di attacco di cavallo, re e pedone e le tavole delle case tra due case e delle linee
  confrontate con un cammino sulla scacchiera;
- l'interfaccia dei pezzi a lunga gittata e ciascuna delle sue tre implementazioni (raggi
  classici e due disposizioni di magic bitboard,
  [ADR-0016](adr/0016-attacchi-dei-pezzi-a-lunga-gittata.md)) confrontate con un cammino casa
  per casa, in modo esaustivo su ogni sottoinsieme delle case rilevanti di ogni casa, e su
  occupazioni casuali dell'intera scacchiera con seme dichiarato; un test controlla che ogni
  implementazione di `*slider-implementations*` sia fra quelle confrontate, e uno che il nome
  letto da `SCF_SLIDERS` scelga l'implementazione giusta e rifiuti un nome sbagliato;
- le maschere delle case rilevanti e la dimensione delle tavole magic; i numeri magici nel
  repository confrontati con quelli che la ricerca trova di nuovo dal seme; un numero non magico
  rifiutato dalla costruzione delle tavole;
- `check-compiled-choice`: un file del hot path ricaricato mentre l'immagine chiede un'altra
  implementazione degli attacchi o un'altra policy si ferma con un errore, e con le scelte
  dell'immagine si ricarica;
- i macro che scrivono il generatore: accettano dichiarazioni come `dolist` e non catturano le
  variabili del chiamante;
- i casi limite di make e unmake (il limite degli orologi uguale a quello del riferimento, lo
  stack di undo oltre la capacità iniziale, l'unmake senza mosse e una mossa di un pezzo che non
  c'è rifiutati senza cambiare la posizione, la copia indipendente, il controllo di coerenza che
  trova una tavola dei pezzi sfasata);
- i buffer di mosse: un buffer troppo piccolo dà un errore, non un conteggio sbagliato; una
  posizione con nove donne ci sta e dà il perft del riferimento; la dimensione segue la formula
  di [ADR-0015](adr/0015-generatore-di-mosse-del-livello-ottimizzato.md);
- l'allocazione: perft che fanno più di un milione di mosse, dopo un riscaldamento, devono
  allocare al più 1 MiB ([ADR-0014](adr/0014-policy-di-compilazione-del-livello-ottimizzato.md)).

La suite `optimized-perft` ([`tests/test-optimized-perft.lisp`](../tests/test-optimized-perft.lisp))
confronta anche il `divide` dell'ottimizzato con quello del riferimento, e controlla che il perft
a profondità 0 valga 1 e che una profondità negativa sia rifiutata.

`make test-checked` esegue tutte le suite con il hot path compilato a `safety 3`. Le suite si
eseguono con l'implementazione degli attacchi scelta al build; con la variabile d'ambiente
`SCF_SLIDERS` (`fixed-magic`, `magic`, `ray`) `make test`, `make test-checked`,
`make perft-deep` e `make differential-deep` le eseguono con un'altra, per esempio
`SCF_SLIDERS=ray make test`. Allo stesso modo `SCF_EVAL_STATE=recompute` le esegue con la
variante B di [EXP-0002](../research/exp-0002-stato-incrementale-della-valutazione.md), senza lo stato incrementale della
valutazione in make e unmake: tutte le suite passano, compresa la firma di ricerca; i tre test che
ispezionano lo stato (il controllo di coerenza, make e unmake, il confronto in lockstep) vi
controllano solo ciò che la variante tiene, e
`optimized-evaluation/the-evaluation-state-follows-the-build` controlla che nella variante A make
aggiorni lo stato e nella variante B lo lasci com'è. Ognuno di questi target ricompila prima ogni sistema che carica
(`tools/load.lisp`), quindi non usa i file compilati da un target precedente con un'altra scelta.

Limiti: il confronto non vede gli errori nel `core` condiviso (INV-A3), né gli errori comuni ai due
livelli (RSK-05). Per questo il `core` contiene solo definizioni e il riferimento si giudica anche
con valori pubblicati.

## Valutazione e ricerca del riferimento

La valutazione classica è definita in [valutazione](valutazione.md)
([ADR-0018](adr/0018-definizione-della-valutazione-classica.md), accettato). La
implementano il riferimento (`src/reference/classical.lisp`) e il livello ottimizzato
([sezione seguente](#valutazione-e-ricerca-del-livello-ottimizzato)). Tre suite di `make test`
giudicano il riferimento.

- **Scambio dei colori** ([`tests/test-mirror.lisp`](../tests/test-mirror.lisp), suite
  `mirror`). `mirror-position` riflette la scacchiera in verticale, scambia i colori dei pezzi, il
  lato al tratto e i diritti di arrocco e riflette la casa en passant. Su ogni posizione: applicato
  due volte restituisce la posizione; dà una posizione legale, la stessa che `mirror-fen` dà
  scambiando il testo della FEN; le mosse legali della posizione riflessa sono le mosse legali
  riflesse (`mirror-move`); il perft a profondità 1 e 2 è uguale. Le posizioni: le tabelle di
  perft, le suite dei casi speciali (le FEN lette dai sorgenti dei test, come nel test
  differenziale), le posizioni di partenza del fuzzer e posizioni legali casuali raggiunte con un
  seme dichiarato nel file.
- **Valutazione** ([`tests/test-evaluation.lisp`](../tests/test-evaluation.lisp), suite
  `evaluation`). Il codice contro la definizione: gli
  [esempi calcolati](valutazione.md#esempi-calcolati) del documento, termine per termine;
  posizioni minime (i due re e uno o due pezzi) calcolate a mano dal testo, per colore e per
  termine, con il calcolo scritto accanto a ciascuna; le piece-square tables stampate nel
  documento, casa per casa; i parametri della mobilità contro la loro regola. Sulle posizioni
  della suite `mirror`: lo scambio dei colori nega `E_W` e lascia invariato `E`, termine per
  termine (INV-C7); la riflessione fra le colonne a e h lascia invariato `E_W` (proprietà della
  definizione di oggi, non un invariante); `|E_W| ≤ 20000` (INV-C9). Una posizione con 47 donne
  arriva esattamente al limite; orologi, diritti di arrocco e casa en passant non cambiano la
  valutazione (INV-C10); la miscela tronca verso zero. I valori attesi non sono pubblicati:
  vengono dalla definizione, e un test che fallisce dice che codice e documento non concordano,
  non quale dei due sbaglia. I test che usano i valori del documento o le proprietà della
  definizione (gli esempi, le posizioni calcolate a mano, lo scambio dei colori, la riflessione
  fra le colonne, la sola posizione, il limite) sono definiti una volta e si eseguono su entrambi
  i livelli: nella suite `evaluation` sul riferimento, in `optimized-evaluation` sul livello
  ottimizzato (`deftest-evaluation`, [`tests/support.lisp`](../tests/support.lisp)).
- **Ricerca** ([`tests/test-search.lisp`](../tests/test-search.lisp), suite `search`). Le
  ricerche valutano le foglie con la valutazione classica; i test scritti per la valutazione di
  materiale la passano esplicitamente. Alpha-beta e negamax danno lo stesso valore, la stessa
  mossa migliore e la stessa variante principale, con le due valutazioni, sulle posizioni del
  file fino a profondità 3; con la valutazione classica, su quattro posizioni il cui albero a
  profondità 3 ha decine di migliaia di nodi, fino a profondità 2 (il file le nomina e dice
  perché). Il valore di alpha-beta non cambia permutando le mosse di ogni nodo con generatori a
  seme dichiarato: fino a profondità 3 con ciascuno dei tre semi di `*move-order-seeds*`, tranne
  che a profondità 3 sulle quattro posizioni dall'albero grande, dove si usa il primo; quello di
  negamax, fino a profondità 2, con il primo seme
  ([Proprietà di alpha-beta puro](#proprietà-di-alpha-beta-puro)). L'iterative
  deepening dà a ogni profondità `d` il valore, la mossa migliore, il numero di nodi e la variante
  principale della ricerca diretta a `d`. Le varianti principali le rigioca
  `principal-variation-problems`, nello stesso file, su una copia della posizione di
  riferimento e con la legalità del riferimento: ogni mossa deve essere legale dove si gioca, e
  la variante deve finire alla profondità della ricerca nella posizione la cui valutazione
  statica, vista dalla radice, è il punteggio; oppure, per un punteggio di matto, in uno scacco
  matto al ply che il punteggio dice, prima della profondità e con il segno del lato che dà
  matto; oppure prima della profondità in uno stallo, con il punteggio 0. Il test
  `principal-variation-check-finds-planted-errors` controlla che rifiuti varianti false di ogni
  tipo. In `make test` le rigioca tutte per queste ricerche del riferimento sulle posizioni di
  ricerca: alpha-beta da 0 a 3 e negamax da 0 a 3 (da 0 a 2 con la valutazione classica sulle
  quattro posizioni dall'albero grande), in ordine di generazione e con le due valutazioni
  (`principal-variation-leads-to-the-score`); alpha-beta e negamax permutati, alle profondità e
  con i semi detti sopra, con la valutazione classica
  (`alpha-beta-value-does-not-depend-on-the-move-order`). Rigioca anche la variante della
  ricerca diretta e quella dell'ultima iterazione dell'iterative deepening su quattro posizioni
  con un matto forzato, fino a profondità 5
  (`iterative-deepening-mate-stop-equals-the-full-depth-search`).

## Valutazione e ricerca del livello ottimizzato

Il livello ottimizzato implementa la valutazione classica e le ricerche baseline per conto
proprio ([ADR-0019](adr/0019-valutazione-e-ricerca-del-livello-ottimizzato.md), in stato
Proposta): `src/optimized/evaluation-tables.lisp`, `evaluation.lisp`, `search.lisp` e
`mirror.lisp` ([architettura](architettura.md#rappresentazione-e-generazione-delle-mosse)). Lo
giudicano tre suite di `make test`, e `make differential-deep` con il profilo profondo.

- **Valutazione** ([`tests/test-optimized-evaluation.lisp`](../tests/test-optimized-evaluation.lisp)
  e i test di [`tests/test-evaluation.lisp`](../tests/test-evaluation.lisp) definiti per i due
  livelli, suite `optimized-evaluation`). Gli esempi calcolati del documento e le posizioni
  calcolate a mano, termine per termine; le piece-square tables del livello contro quelle
  stampate nel documento, per i due colori; le tavole con segno dello stato incrementale contro
  `σ(c) · (V(t) + pst)`; le maschere dei termini dei pedoni (colonne, colonne vicine, case davanti,
  case dei pedoni passati, traverse relative, spazio) contro la loro definizione, casa per casa; i
  parametri della mobilità e dell'attacco al re contro la loro regola, con le funzioni d'attacco
  del livello; la miscela troncata verso zero e il limite; lo scambio dei colori
  (`bitboard-mirror`, codice del livello) contro `mirror-position` del riferimento convertita, e
  la simmetria della valutazione per termine (INV-C7); la valutazione con lo stato incrementale,
  quella calcolata da zero e la scomposizione, che devono coincidere; make e unmake di ogni mossa
  legale, a due ply dalle posizioni di partenza del fuzzer, con lo stato incrementale contro il
  ricalcolo e lo stato di prima dopo l'unmake; il controllo di coerenza, che deve trovare uno
  stato della valutazione alterato; la valutazione che non cambia la posizione. L'allocazione:
  più di 800000 valutazioni dopo un riscaldamento devono allocare al più 1 MiB.
- **Ricerca** ([`tests/test-optimized-search.lisp`](../tests/test-optimized-search.lisp), suite
  `optimized-search`). Le verifiche del gate della [Fase 2](roadmap.md#fase-2) sul livello
  ottimizzato, come quelle della suite `search` sul riferimento: alpha-beta e negamax danno lo
  stesso valore, la stessa mossa migliore e la stessa variante principale fino a profondità 3
  sulle posizioni di ricerca di [`tests/test-search.lisp`](../tests/test-search.lisp); il valore
  di alpha-beta, fino a profondità 4, non cambia permutando le mosse di ogni nodo con ciascuno
  dei tre semi di `*move-order-seeds*`, dichiarati in quel file, e quello di negamax, fino a 3,
  non cambia permutandole con il primo dei tre; un test controlla che la permutazione cambi
  davvero l'ordine di ricerca; l'iterative deepening dà a ogni profondità il valore, la
  mossa migliore, il numero di nodi e la variante principale della ricerca diretta, e si ferma su
  un punteggio di matto senza cambiare il risultato. Il riferimento rigioca le varianti
  principali del livello con `principal-variation-problems` (sopra), sulla posizione di
  riferimento letta dalla FEN e con la propria valutazione classica: in `make test`, tutte
  quelle di alpha-beta da 0 a 4 e di negamax da 0 a 3 in ordine di generazione sulle posizioni
  di ricerca, e di alpha-beta e della ricerca di default della Fase 3 a profondità 4 sulle
  dodici posizioni della firma (`principal-variation-leads-to-the-score`), e tutte quelle delle
  ricerche permutate:
  alpha-beta da 1 a 4 con i tre semi, negamax da 1 a 3 con il primo
  (`alpha-beta-value-does-not-depend-on-the-move-order`), e quelle della ricerca diretta e
  dell'ultima iterazione sulle quattro posizioni con un matto forzato, fino a profondità 5
  (`iterative-deepening-mate-stop-equals-the-full-depth-search`). Quelle che rigioca la suite
  `differential` sono nel punto seguente. Inoltre: i punteggi di matto
  relativi al ply, lo stallo, la profondità 0 e 1 ricavate dalla definizione, i nodi di negamax
  dalla posizione iniziale (la somma dei perft), gli argomenti rifiutati, la posizione lasciata
  com'era. L'allocazione: ricerche che visitano più di un milione di nodi, con un contesto
  preallocato e dopo un riscaldamento, devono allocare al più 1 MiB (INV-A5), come il perft.
  Infine la firma di ricerca ([Regressione di ricerca](#regressione-di-ricerca)).
- **Confronto con il riferimento** (suite `differential`, nei due file). La scomposizione del
  livello ottimizzato deve essere uguale a quella del riferimento, termine per termine e colore
  per colore, e le due valutazioni del livello ottimizzato devono dare il punteggio del
  riferimento (INV-C1): sulle posizioni delle tabelle di perft, dei casi speciali (le FEN lette
  dai sorgenti dei test), dei test di FEN e di partenza del fuzzer e sui loro figli; su posizioni
  legali casuali con seme dichiarato; in partite casuali con seme dichiarato giocate sui due
  livelli, dove a ogni posizione lo stato incrementale si confronta anche con il ricalcolo e con
  la somma di materiale e piece-square tables del riferimento, e per ogni mossa legale con il
  ricalcolo dopo il make e con lo stato di prima dopo l'unmake (INV-C8, INV-C2). Le posizioni
  della suite del fuzzer e quelle del test differenziale delle mosse non si valutano; nel
  secondo lo stato incrementale lo ricalcola il controllo di coerenza, dopo ogni mossa
  ([Test differenziale](#test-differenziale)). Il valore di alpha-beta, di negamax e della
  ricerca di default della Fase 3 (con la TT in modalità di verifica,
  [Ricerca della Fase 3](#ricerca-della-fase-3)) del livello ottimizzato deve essere quello di
  alpha-beta del riferimento: sulle posizioni di ricerca alle profondità da 1 a 3 (fino a 4 con
  `make differential-deep`) e su posizioni casuali con seme dichiarato a profondità 2 (3); nello
  stesso test (`search-values-equal-the-reference`) il riferimento rigioca le varianti
  principali delle quattro ricerche, la propria e le tre del livello ottimizzato. Il test `random-position-variations-are-checked-by-the-reference`
  rigioca le varianti di alpha-beta del livello ottimizzato, in ordine di generazione, su altre
  posizioni casuali con seme dichiarato, a una profondità a cui la suite non esegue la ricerca
  del riferimento: 40 posizioni a profondità 3 in `make test`, 200 a profondità 5 in
  `make differential-deep`. Il test `search-signature-is-judged-by-the-reference` giudica la
  firma di ricerca ([Regressione di ricerca](#regressione-di-ricerca)). Il numero di nodi di
  negamax, che è la dimensione dell'albero e non dipende dall'ordine delle mosse, deve essere
  quello del riferimento. La mossa migliore, la variante principale e il numero di nodi di
  alpha-beta non si confrontano con quelli del riferimento: il generatore del livello
  ottimizzato scrive le mosse in un altro ordine, e fra mosse di valore uguale, e in quanto
  alpha-beta pota, decide l'ordine. `make test` confronta migliaia di posizioni per la
  valutazione; quante, con quali semi e a quali profondità, lo dicono i file e lo stampano i
  test.

## Ricerca della Fase 3

La transposition table, l'ordinamento delle mosse, PVS e NegaScout e i tipi di nodo del livello
ottimizzato ([ADR-0021](adr/0021-transposition-table-del-livello-ottimizzato.md),
[ADR-0022](adr/0022-pvs-negascout-e-tipi-di-nodo.md),
[ADR-0023](adr/0023-ordinamento-delle-mosse-della-fase-3.md), in stato Proposta) li giudicano
due suite di `make test`. Il valore della ricerca senza TT è quello di alpha-beta del livello
ottimizzato (la baseline della Fase 2), che la suite `differential` confronta con il
riferimento; le varianti principali le rigioca il riferimento (`principal-variation-problems`,
[sopra](#valutazione-e-ricerca-del-riferimento)).

- **Transposition table** ([`tests/test-optimized-tt.lisp`](../tests/test-optimized-tt.lisp),
  suite `optimized-tt`). La parola di dati impacchetta e restituisce ogni campo; il costruttore
  rifiuta una dimensione che non è una potenza di due, una politica e una modalità sconosciute;
  ognuna delle tre politiche segue la sua regola, su una tabella di due slot e una maschera di
  chiave nulla. Dopo un iterative deepening con la TT in modalità di verifica, ogni entry di ogni
  posizione entro due ply dalla radice è un bound vero del valore della sua posizione alla sua
  profondità, punteggi di matto compresi, giudicato da alpha-beta cercato da quella posizione.
  La modalità di verifica contro la ricerca senza TT: alpha-beta, PVS e NegaScout, con e senza
  ordinamento, sulle posizioni di ricerca alle profondità da 1 a 4 e su 30 posizioni casuali con
  seme a profondità 3, e PVS ordinata sulle posizioni della firma alla sua profondità, con nessuna
  mossa TT scartata; tabelle di 2, 16, 256 e 4096 slot con ciascuna politica, dove le entry si
  sostituiscono o si rifiutano di continuo; una maschera di chiave di 8 e di 4 bit, che forza
  falsi riscontri, scartati e contati, senza che una mossa di un'altra posizione sia letta. In
  modalità normale con la stessa maschera la ricerca legge mosse di altre posizioni: si scartano,
  la ricerca finisce senza errori, lascia la posizione com'era e la sua variante è legale; il
  valore può cambiare, e il test conta quante volte. Entry alterate a mano (una mossa illegale in
  ogni posizione entro un ply) si scartano e il valore resta quello senza TT. Una posizione
  raggiunta per due percorsi, con orologi e storia diversi, ha una chiave e un valore: l'opzione
  di [QA-02](limiti-e-rischi.md#qa-02).
- **Ordinamento, PVS, NegaScout, tipi di nodo**
  ([`tests/test-optimized-pvs.lisp`](../tests/test-optimized-pvs.lisp), suite `optimized-pvs`).
  Il nodo della Fase 3 in modalità alpha-beta, senza ordinamento né TT, restituisce ciò che la
  baseline restituisce: valore, mossa migliore, numero di nodi e variante, anche con le mosse
  permutate dallo stesso seme. PVS e NegaScout, con e senza ordinamento, e alpha-beta ordinato,
  ciascuno senza TT e con una TT di 4096 slot in modalità di verifica (PVS e NegaScout anche con
  la TT e senza ordinamento), restituiscono il valore della baseline sulle posizioni di ricerca
  alle profondità da 0 a 4, su 40 posizioni casuali con seme a profondità 3, e con le mosse
  permutate da ciascuno dei semi di `*move-order-seeds*` alle profondità da 1 a 3
  ([Proprietà di alpha-beta puro](#proprietà-di-alpha-beta-puro)); il riferimento rigioca ogni
  variante. PVS e NegaScout
  sono due ricerche diverse (ri-ricerche e nodi). L'ordine delle mosse è quello che la regola dà,
  calcolato di nuovo dal test con la scacchiera del riferimento, su posizioni di ricerca, della
  firma e casuali; la mossa TT è prima e la mossa PV seconda quando sono legali, e una mossa TT
  illegale non prende posto; nell'iterative deepening ordinato la mossa PV è cercata per prima a
  ogni nodo della variante precedente, tante volte quante mosse ha; con la TT in modalità di
  verifica la mossa TT è cercata per prima e nessuna è scartata. I tipi di nodo: i conteggi dei
  nove accoppiamenti sommano ai nodi, la radice è PV osservata PV, PVS e NegaScout non osservano
  mai PV un nodo atteso Cut o All, i contatori dei tagli sono ordinati. Con un ordinamento
  perfetto (un aggancio dei test ordina le mosse di ogni nodo per il loro valore di negamax)
  alpha-beta, PVS e NegaScout visitano esattamente l'albero minimo di Knuth e Moore, che il test
  conta a parte, ogni nodo ha il tipo atteso e non c'è nessuna ri-ricerca, su undici
  posizioni a profondità da 2 a 4. L'iterative deepening ordinato con la TT in modalità di
  verifica dà a ogni profondità il valore della baseline. Gli argomenti sbagliati si rifiutano.
  L'allocazione: ricerche di PVS e NegaScout ordinate con una TT in ciascuna modalità, con un
  contesto e una tabella preallocati, che visitano più di un milione di nodi dopo un
  riscaldamento, devono allocare al più 1 MiB (INV-A5).

## Regressione di ricerca

> **Proposta** — Una *firma di ricerca* per ogni posizione di una suite: valore, mossa migliore,
> numero di nodi e variante principale a profondità fissa, con un solo thread. Non a tempo: lo
> stop a tempo non è deterministico.

La firma lega la classificazione alla verifica. Una modifica che dichiara `EXACT` non cambia la
firma.

Le ricerche dei due livelli restituiscono le quattro componenti della firma: valore, mossa
migliore, numero di nodi e variante principale.

> **Deciso (autore → [ADR-0019](adr/0019-valutazione-e-ricerca-del-livello-ottimizzato.md))** — La
> prima firma, del livello ottimizzato.

- **Che cosa è registrato.** [`tests/search-signature.sexp`](../tests/search-signature.sexp):
  per ogni posizione di `*search-signature-positions*`
  ([`tests/test-optimized-search.lisp`](../tests/test-optimized-search.lisp): le posizioni di
  perft, due posizioni di mediogioco quiete e tre tattiche, ciascuna con le mosse che la
  raggiungono dalla posizione iniziale) il valore, la mossa migliore, il numero di nodi e la
  variante principale di alpha-beta del livello ottimizzato a profondità fissa (4), un thread,
  senza TT né ordinamento, con la valutazione classica. È un valore di regressione di questo
  engine, non un oracolo esterno.
- **Il giudizio del riferimento.** Il test
  `differential/search-signature-is-judged-by-the-reference`
  ([`tests/test-optimized-search.lisp`](../tests/test-optimized-search.lisp)) giudica la firma
  con il riferimento. In `make test` il riferimento legge dalla FEN di ogni voce la variante
  principale registrata e la rigioca con `principal-variation-problems`
  ([Valutazione e ricerca del riferimento](#valutazione-e-ricerca-del-riferimento)): le mosse
  devono essere legali e portare al valore registrato, e la mossa migliore registrata deve
  esserne la prima. In `make differential-deep` il riferimento cerca anche ogni posizione con il
  proprio alpha-beta alla profondità del file, e il valore deve essere quello registrato e
  quello di alpha-beta del livello ottimizzato, cercato di nuovo; la variante principale del
  riferimento passa lo stesso controllo. In `make test` il riferimento non esegue quella
  ricerca: sulle dodici posizioni il suo alpha-beta a profondità 4 visita 897329 nodi, con la
  valutazione classica calcolata termine per termine a ogni foglia, e `make test` limita in nodi
  il lavoro delle ricerche del riferimento. Otto delle dodici posizioni sono anche posizioni di
  ricerca, i cui valori `make test` confronta con quelli del riferimento fino a profondità 3 e
  `make differential-deep` fino a 4
  ([Valutazione e ricerca del livello ottimizzato](#valutazione-e-ricerca-del-livello-ottimizzato)).
- **Provenienza.** L'intestazione del file registra la revisione da cui partiva l'albero di
  lavoro e se era pulito, la policy del hot path, l'implementazione degli attacchi dei pezzi a
  lunga gittata, il Lisp, il sistema e la data dell'esecuzione che l'ha scritto. La firma non
  dipende dall'implementazione degli attacchi né dalla policy: le tre implementazioni danno le
  stesse mosse nello stesso ordine, e la build controllata calcola le stesse cose.

> **Proposta ([ADR-0022](adr/0022-pvs-negascout-e-tipi-di-nodo.md))** — La firma della Fase 3.

- **Due ricerche.** Dal formato 2 il file registra, accanto alla parte di alpha-beta descritta
  sopra (`:entries`, invariata), la ricerca di default della Fase 3 (`:default-search`,
  `:default-entries`): iterative deepening di PVS con l'ordinamento della Fase 3 e una TT nuova
  di 65536 slot a due slot per bucket, in modalità di verifica, alla stessa profondità e sulle
  stesse posizioni; il numero di nodi è la somma delle iterazioni. La modalità normale non è
  nella firma: il suo valore a profondità fissa non è garantito.
- **Il valore.** Il test della firma controlla che le due ricerche registrino gli stessi valori.
  Il riferimento rigioca le varianti di entrambe in `make test`, e in `make differential-deep`
  ne confronta i valori con il proprio alpha-beta e con le due ricerche cercate di nuovo.
- **Il test.** `optimized-search/search-signature-is-reproduced`, in `make test`, ricalcola ogni
  voce, delle due ricerche dal formato 2, e la confronta con il file, componente per componente.
- **Come si aggiorna.** Il file lo scrive solo `make signatures`
  ([`tools/signatures.lisp`](../tools/signatures.lisp)), che nessun altro target esegue e che non
  si esegue per far passare il test. Una modifica dichiarata `[EXACT]` non cambia la firma: se il
  test fallisce dopo una modifica di quel tipo, la modifica non è `[EXACT]`, o ha un errore. Una
  modifica che deve cambiare un'uscita della ricerca (la tabella qui sotto dice quali) rigenera il
  file con `make signatures` nello stesso commit; il messaggio di commit dice quali componenti
  cambiano e perché, e per una nuova potatura, riduzione o estensione rimanda al record di
  ricerca. La differenza del file si legge prima del commit: che cambino solo le componenti che
  la modifica deve cambiare. Un cambio dell'ordine in cui il generatore scrive le mosse, anche se
  `[EXACT]` per il perft, è per la ricerca un cambio dell'ordinamento: cambia i nodi, non il
  valore. Cambia la firma anche un cambio della valutazione
  ([valutazione](valutazione.md#convenzioni-per-la-ricerca)), della profondità o delle posizioni.

| Modifica | Firma attesa |
|---|---|
| Ottimizzazione `EXACT` della stessa ricerca | identica |
| Cambio dell'ordinamento, senza TT né potature | valore uguale, nodi diversi (la parte della ricerca di default) |
| Cambio della TT (dimensione, sostituzione) | valore uguale solo in modalità di verifica; nodi diversi (la parte della ricerca di default) |
| Nuova potatura, riduzione o estensione (`HEURISTIC`) | può cambiare tutto: serve un [record di ricerca](../research/README.md) |

### Modalità di verifica della TT

> **Proposta** — Una configurazione della TT usata nei test, non nel gioco, che soddisfa le
> ipotesi TT-1…TT-4 ([classificazione](classificazione.md#ipotesi-della-transposition-table)).

- Si usano solo entry con profondità uguale a quella richiesta (TT-1).
- I punteggi che dipendono dalla storia (ripetizione, regola delle cinquanta mosse) non si
  memorizzano e non si riusano (TT-2).
- Ogni entry conserva un controllo indipendente della chiave, per esempio la posizione completa.
  Un falso riscontro si scarta e si conta (TT-3, [QA-01](limiti-e-rischi.md#qa-01)).
- I punteggi di matto si memorizzano relativi al nodo e si convertono alla lettura. Nessuna
  potatura o riduzione dipende dallo stato di ricerca (TT-4).

In questa modalità la ricerca con TT deve restituire lo stesso valore della ricerca senza TT.
Le posizioni GHI della suite della TT sono un'eccezione dichiarata: provano l'opzione scelta per
[QA-02](limiti-e-rischi.md#qa-02), non questa uguaglianza.

Oggi la modalità è implementata nel livello ottimizzato
([ADR-0021](adr/0021-transposition-table-del-livello-ottimizzato.md), Proposta): una tabella
creata con `:mode :verification` usa per un taglio solo entry della profondità del nodo; la
ricerca non rileva ripetizioni né la regola delle cinquanta mosse, e gli orologi sono fuori dalla
chiave; ogni slot conserva, oltre alla chiave intera, le bitboard per tipo di pezzo, le
occupazioni per colore, il lato al tratto, i diritti di arrocco e la casa en passant come la
chiave la conta, e un falso riscontro si scarta e si conta; i punteggi di matto si scrivono
relativi al nodo; nessuna potatura oltre ad alpha-beta. I test sono in
[Ricerca della Fase 3](#ricerca-della-fase-3). La posizione GHI della suite di oggi è una
posizione raggiunta per due percorsi, con una ripetizione nella storia: prova l'opzione di
default proposta per QA-02 (nessuna storia nel valore).

### Proprietà di alpha-beta puro

> **Proposta** — Senza TT né potature oltre ad alpha-beta, il valore a finestra piena non dipende
> dall'ordine delle mosse. Un test lo verifica permutando le mosse con un seme (gate della
> [Fase 2](roadmap.md#fase-2)). Un valore che cambia indica un errore di implementazione.

Nel riferimento il test è `alpha-beta-value-does-not-depend-on-the-move-order`
([`tests/test-search.lisp`](../tests/test-search.lisp)): le mosse di ogni nodo sono permutate
da un generatore con seme dichiarato nel file (l'argomento `:shuffle-rng` delle ricerche), e il
valore deve restare quello della ricerca in ordine di generazione; la mossa migliore e il numero
di nodi possono cambiare. Un secondo test controlla che la permutazione cambi davvero l'ordine
di ricerca. Nel riferimento alpha-beta si permuta con i tre semi fino a profondità 3 (con il solo
primo a profondità 3 sulle posizioni dall'albero grande), e negamax con il primo fino a
profondità 2. Nel livello ottimizzato i test con lo stesso nome sono nella suite
`optimized-search` ([`tests/test-optimized-search.lisp`](../tests/test-optimized-search.lisp)),
con gli stessi semi: alpha-beta con i tre fino a profondità 4, negamax con il primo fino a 3.
PVS e NegaScout, con e senza l'ordinamento della Fase 3, e alpha-beta ordinato si permutano con
i tre semi fino a profondità 3, nella suite `optimized-pvs`: l'ordinamento è stabile, quindi la
permutazione cambia l'ordine fra mosse dello stesso posto, e il valore deve restare quello della
baseline ([Ricerca della Fase 3](#ricerca-della-fase-3)).

## Suite per tecnica

La specifica chiede di testare esplicitamente gli zugzwang e le posizioni in cui il null move è
pericoloso.

> **Proposta**

| Tecnica | Che cosa si prova |
|---|---|
| Null move | posizioni di zugzwang con risultato noto: la ricerca con la tecnica non deve perdere la mossa corretta, o la perdita va registrata |
| Quiescenza | posizioni con lunghe sequenze forzate di catture, per l'effetto orizzonte |
| TT | posizioni la cui valutazione dipende dalle ripetizioni (GHI, [QA-02](limiti-e-rischi.md#qa-02)), che provano l'opzione scelta per QA-02; punteggi di matto che passano attraverso la TT. Oggi: la suite `optimized-tt` ([Ricerca della Fase 3](#ricerca-della-fase-3)) |
| LMR, potature, estensioni | suite tattiche: nodi per posizione risolta (una misura, in [misure](misure.md)) |
| Ogni tecnica | spenta da configurazione, restituisce la firma della fase precedente (reversibilità, INV-X5) |

Ogni caso con il risultato noto sta in [`tests/`](../tests/), con la fonte.

## NNUE e cross-platform

**NNUE.** La specifica chiede un riferimento scalare, backend SIMD, un aggiornamento incrementale
che modifica solo le feature necessarie, e una regressione NNUE.

> **Proposta** — Il riferimento scalare definisce l'aritmetica. Ogni backend è bit-identico al
> riferimento (INV-H3). L'accumulatore aggiornato incrementalmente è uguale a quello ricalcolato
> (INV-C3). Il formato del file della rete ha una versione.

**Cross-platform.** Il comportamento logico deve essere identico su ogni piattaforma target; le
differenze hardware riguardano solo i backend ottimizzati (INV-H5). I target sono Debian/Linux
x86-64, FreeBSD x86-64, macOS Intel, macOS Apple Silicon e la predisposizione ARM64 Linux/FreeBSD.

> **Proposta** — Tra piattaforme si confrontano perft, chiavi Zobrist, sequenze del generatore
> pseudocasuale, posizioni del fuzzer per un dato seme e firme di ricerca. Si può dire che qualcosa
> vale su una piattaforma solo se vi è stato eseguito. La CI esegue `make check` su Ubuntu x86-64
> e su macOS arm64. Le esecuzioni registrate, la prima delle quali è la run 37165773431 sul
> commit 371b205 e la prima con il livello ottimizzato la run 37180782566 sul commit 5d25099,
> con l'immagine, la versione di SBCL e l'esito di ciascuna, sono in
> [QA-12](limiti-e-rischi.md#qa-12).

## Gate di modifica

La specifica valuta ogni modifica almeno su correttezza, velocità, memoria, allocazione e forza,
e chiede di registrare regressioni e miglioramenti.

> **Proposta** — Non ogni asse si applica a ogni modifica: una modifica alla documentazione chiede
> solo i link.

| Asse | Domanda | Come si risponde |
|---|---|---|
| Correttezza | niente si è rotto? | `make check`; perft se cambia la generazione; test differenziale se cambia il livello ottimizzato; firma di ricerca se cambia la ricerca |
| Velocità | è più veloce a parità di lavoro? | microbenchmark e benchmark di engine contro la baseline ([misure](misure.md)) |
| Memoria | RSS e dimensione delle strutture | benchmark di engine |
| Allocazione | quanti byte si allocano nel hot path? | `sb-ext:get-bytes-consed` prima e dopo; disassembly dove si afferma qualcosa sul codice generato |
| Forza | è più forte per CPU-secondo? | self-play con test statistico ([misure](misure.md)) |

## Gate di fase

> **Proposta** — Una fase si chiude solo quando passa il proprio gate ([roadmap](roadmap.md)) e,
> in aggiunta:

- `make check` passa;
- ogni riduzione di lavoro introdotta ha la sua classificazione;
- ogni nuova regola inviolabile è in [invarianti](invarianti.md);
- la documentazione che la modifica rende falsa è aggiornata nello stesso commit (INV-X12).

## Comandi

Il [Makefile](../Makefile) elenca i target con `make help`.

| Comando | Fa |
|---|---|
| `make check` | compila senza avvisi, esegue i test, il linter, gli autotest degli strumenti (`make lint-selftest`: linter, controllo dei link e caricamento rigoroso) e il controllo dei link |
| `make test-checked` | i test, con il hot path del livello ottimizzato compilato a `safety 3`; fuori da `make check` |
| `make perft-deep` | i perft profondi dei due livelli, fuori da `make check` |
| `make differential-deep` | il test differenziale su milioni di posizioni, fuori da `make check` |
| `make bench` | il registro dell'ambiente e i benchmark (perft del riferimento e del livello ottimizzato con ciascuna implementazione degli attacchi dei pezzi a lunga gittata, nodi di ricerca per secondo del livello ottimizzato a profondità fissa, costo di una chiamata della valutazione nei due livelli, ricerca e perft con le due varianti dello stato della valutazione, le ricerche della Fase 3 con e senza ordinamento e TT, di più dimensioni e politiche, con l'efficienza dell'ordinamento e la hit rate, il costo della lookup della TT, utilità sui bit, attacchi dei pezzi a lunga gittata), fuori da `make check` |
| `make hot-path` | note di efficienza di SBCL, disassemblato delle funzioni di ogni nodo del perft e delle ricerche, dell'ordinamento e della TT, allocazione e tempi di perft per policy del hot path del livello ottimizzato, fuori da `make check` |
| `make magics` | ripete la ricerca dei numeri magici dal seme, senza costruire prima le tavole dai numeri nel file, e riscrive `src/optimized/magic-numbers.lisp` ([ADR-0016](adr/0016-attacchi-dei-pezzi-a-lunga-gittata.md)), fuori da `make check`; il test dei numeri, in `make test`, fallisce se il file non è il suo output |
| `make signatures` | ricalcola la firma di ricerca, delle due ricerche, e riscrive `tests/search-signature.sexp` con la sua intestazione di provenienza ([Regressione di ricerca](#regressione-di-ricerca)), fuori da `make check`; il test della firma, in `make test`, fallisce se il file non è ciò che le ricerche calcolano |

SBCL è l'unico requisito Lisp. I target usano make (è stato usato solo GNU make). Per parte del
registro dell'ambiente `make bench` esegue anche git, ps, uname, sysctl e nproc, e legge
`/proc/cpuinfo` e `/proc/loadavg`. Nessuno è obbligatorio: una voce il cui programma non
risponde passa a un'altra fonte o dice unknown ([misure](misure.md#registro-dellambiente)).

## Che cosa la verifica non prova

- Perft e test differenziali non dicono che l'engine giochi bene, né che una potatura sia sicura.
- Il confronto differenziale non vede errori nel `core` condiviso, né errori comuni ai due livelli.
- Un valore di perft di regressione non è un oracolo esterno.
- Il fuzzing e il test differenziale provano per campioni, non per esaustione: sono evidenza, non
  dimostrazione.
- Una prova eseguita su una piattaforma non dice nulla sulle altre.
- Un test che passa non è una dimostrazione: la classe `THEOREM` richiede una dimostrazione.
