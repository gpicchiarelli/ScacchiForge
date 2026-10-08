# Changelog

Formato basato su [Keep a Changelog](https://keepachangelog.com/it-IT/1.1.0/). Il progetto non
ha ancora rilasci: il sistema ASDF dichiara la versione `0.0.0`.

Questo file elenca ciò che esiste nel repository. Che funzioni lo dice `make check` sulla
revisione in esame, non questo file.

## [Non rilasciato]

### Aggiunto

- **Sistemi ASDF** `scacchiforge`, `scacchiforge/test` e `scacchiforge/bench`. SBCL, con l'ASDF
  che contiene, è l'unico requisito Lisp: nessuna libreria Lisp di terzi.
- **`core`:** caselle, pezzi, mossa packed in un fixnum, generatore pseudocasuale splitmix64 e
  tavole delle chiavi Zobrist generate da un seme fisso.
- **`reference`** (il modello di riferimento, l'oracolo):
  - lettura rigorosa e scrittura di FEN: rifiuta, per esempio, un pedone sulla prima o
    sull'ultima traversa e un diritto di arrocco senza re e torre al loro posto;
  - generazione pseudo-legale separata dal filtro di legalità;
  - make/unmake con uno stack di annullamento al posto delle copie della posizione;
  - perft e divide;
  - matto e stallo (non le patte per ripetizione, per la regola delle cinquanta mosse o per
    materiale insufficiente);
  - la valutazione di materiale (`evaluate-material`) e la valutazione classica di
    [valutazione](docs/valutazione.md) (`evaluate-classical`, con la scomposizione per termine e
    per colore `classical-breakdown`), calcolata da zero a ogni chiamata, con i parametri in
    costanti con nome in cima a `src/reference/classical.lisp`;
  - lo scambio dei colori di una posizione e di una mossa (`mirror-position`, `mirror-move`);
  - negamax, alpha-beta e iterative deepening come baseline, che restituiscono valore, mossa
    migliore, numero di nodi e variante principale; la valutazione delle foglie è un argomento
    (`:evaluator`, la classica se manca), e per i test un generatore con seme può permutare le
    mosse di ogni nodo (`:shuffle-rng`);
  - un fuzzer di posizioni legali con un verificatore di invarianti.
- **`optimized`**, il livello ottimizzato, con il proprio generatore di mosse
  ([ADR-0015](docs/adr/0015-generatore-di-mosse-del-livello-ottimizzato.md)):
  - utilità sui bit: popcount, lsb, msb, pext e pdep in software, inline;
  - una posizione bitboard: dodici bitboard di pezzi, occupazione per colore e totale, una
    tavola di 64 codici di pezzo, uno stack di undo di vettori tipizzati preallocati; la
    conversione da e verso la posizione di riferimento, la chiave calcolata da zero
    (`bitboard-compute-key`) e un controllo di coerenza;
  - tavole di attacco precalcolate di `(unsigned-byte 64)`: cavallo, re, pedone, raggi, case tra
    due case allineate, linee;
  - gli attacchi dei pezzi a lunga gittata dietro un'interfaccia sola, `bishop-attacks` e
    `rook-attacks`, con tre implementazioni: magic bitboard a spostamento fisso
    (`fixed-magic`, il default) e per casa (`magic`), e raggi classici con ricerca del bloccante
    (`ray`). La variabile d'ambiente `SCF_SLIDERS` sceglie quale si compila
    ([ADR-0016](docs/adr/0016-attacchi-dei-pezzi-a-lunga-gittata.md));
  - numeri magici cercati dal progetto da un seme dichiarato, `+magic-seed+`, con il generatore
    splitmix64 del `core`, e scritti in `src/optimized/magic-numbers.lisp` da `make magics`.
    Nessun numero viene da un altro engine. Le tavole si costruiscono a ogni caricamento e un
    numero che non è magico ferma il caricamento;
  - make/unmake sul posto con chiave incrementale; la politica dell'en passant scritta nel
    `core` è implementata in questo livello due volte, in make e nella chiave calcolata da zero;
  - generazione pseudo-legale, filtro di legalità per maschere di scacco e di inchiodatura
    (`[EXACT]`, un algoritmo diverso da quello del riferimento), buffer di mosse impilati;
  - perft e divide;
  - la valutazione classica, con una copia propria dei parametri in
    `src/optimized/evaluation-tables.lisp` e le tavole costruite dalle formule al caricamento
    ([ADR-0019](docs/adr/0019-valutazione-e-ricerca-del-livello-ottimizzato.md), in stato
    Proposta). Materiale, piece-square tables e fase sono tenuti incrementali in tre campi della
    posizione (`bbp-psq-mg`, `bbp-psq-eg`, `bbp-phase-raw`): make li aggiorna, unmake li rilegge
    dallo stack di undo. `bitboard-evaluate` legge lo stato incrementale,
    `bitboard-evaluate-from-scratch` lo ricalcola, `bitboard-classical-breakdown` dà la
    scomposizione nella forma di quella del riferimento;
  - lo scambio dei colori sulle bitboard (`bitboard-mirror`);
  - negamax, alpha-beta fail-soft e iterative deepening a profondità fissa, con le convenzioni
    della ricerca del riferimento e un contesto preallocato (buffer delle mosse, tavola
    triangolare delle varianti principali, contatore dei nodi);
  - dalla Fase 3, una transposition table (`src/optimized/transposition.lisp`,
    [ADR-0021](docs/adr/0021-transposition-table-del-livello-ottimizzato.md), in stato Proposta):
    entry di 16 byte in vettori tipizzati, chiave intera confrontata, dimensione, politica di
    sostituzione (`:always`, `:depth-preferred`, `:two-slot`) e modalità come argomenti; una
    modalità di verifica che soddisfa TT-1…TT-4, con un controllo indipendente della posizione in
    ogni slot e i falsi riscontri scartati e contati;
  - l'ordinamento delle mosse della Fase 3 (`src/optimized/ordering.lisp`,
    [ADR-0023](docs/adr/0023-ordinamento-delle-mosse-della-fase-3.md), in stato Proposta): mossa
    TT, mossa PV, catture MVV/LVA, promozioni, le altre; la mossa TT solo se legale;
  - PVS e NegaScout in un nodo della Fase 3 accanto alle baseline invariate, con i tipi di nodo
    PV, Cut e All attesi e osservati e contati, le statistiche di una ricerca, l'iterative
    deepening che passa variante e TT all'iterazione seguente, e la ricerca di default della
    Fase 3 (`bitboard-default-search`, [ADR-0022](docs/adr/0022-pvs-negascout-e-tipi-di-nodo.md),
    in stato Proposta).

  Usa il riferimento solo per convertire una posizione
  ([ADR-0010](docs/adr/0010-regole-di-indipendenza-tra-i-livelli.md)). Non ha quiescenza,
  killer, history, potature oltre ad alpha-beta e ai tagli della TT, PEXT in hardware, SIMD né
  rilevamento della CPU.
- **Policy di compilazione del hot path del livello ottimizzato**
  ([ADR-0014](docs/adr/0014-policy-di-compilazione-del-livello-ottimizzato.md)):
  `(speed 3) (safety 1) (debug 0)`, scritta una volta sola in `src/optimized/policy.lisp` e
  proclamata dai file elencati in `*hot-path-files*`; una build controllata a `safety 3`
  (`make test-checked`). Un file del hot path compilato con un'altra policy o un'altra
  implementazione degli attacchi rifiuta di caricarsi (`check-compiled-choice`). `perft-node`
  espande inline generazione, filtro di legalità, make e unmake (`*inline-node-functions*`).
  Con la Fase 2 il hot path comprende anche la valutazione e la ricerca.
- **Test** su un harness del repository, senza dipendenze: perft contro valori pubblicati dove
  esistono, casi speciali (inchiodature, scacchi scoperti, en passant, arrocco, promozioni),
  make/unmake, chiavi Zobrist, utilità sui bit, conversione bitboard, baseline di ricerca,
  fuzzing. Per il livello ottimizzato:
  - `optimized-perft`: gli stessi valori attesi del riferimento, letti dalle stesse tabelle, e
    divide confrontato con quello del riferimento;
  - `optimized-movegen`: la suite dei casi speciali eseguita su questo livello;
  - `differential`: su ogni posizione visitata, gli insiemi ordinati delle mosse legali e
    pseudo-legali, lo scacco, le case attaccate e i pezzi che danno scacco; dopo ogni mossa fatta
    sui due livelli, lo stato intero e la chiave incrementale contro la chiave calcolata da zero e
    contro quella del riferimento; dopo l'unmake, lo stato di prima. Posizioni dalle tabelle di
    perft, dalle FEN dei test dei casi speciali, da partite casuali con seme dichiarato giocate
    mossa per mossa sui due livelli e da posizioni casuali confrontate con perft;
  - `optimized`: tavole contro la geometria della scacchiera; ogni implementazione degli
    attacchi contro un cammino casa per casa, su ogni occupazione rilevante di ogni casa; i
    numeri magici nel repository contro una nuova ricerca dal seme; casi limite di make/unmake;
    limiti dei buffer; allocazione del perft dopo un riscaldamento, al più 1 MiB su più di un
    milione di mosse.

  Per la valutazione e la ricerca della Fase 2:
  - `mirror`, sul riferimento: lo scambio dei colori applicato due volte restituisce la
    posizione, dà una posizione legale, la stessa di `mirror-fen`, con le mosse legali riflesse
    e lo stesso perft;
  - `evaluation` sul riferimento e `optimized-evaluation` sul livello ottimizzato: il codice
    contro la definizione (gli esempi calcolati del documento e posizioni calcolate a mano,
    termine per termine; le piece-square tables stampate; i parametri contro le loro regole), lo
    scambio dei colori che nega il punteggio dal Bianco (INV-C7), la riflessione fra le colonne a
    e h, il limite (INV-C9), la sola posizione (INV-C10). I test che usano i valori del documento
    sono definiti una volta e si eseguono sui due livelli (`deftest-evaluation`). Sul livello
    ottimizzato anche: le tavole con segno, le maschere dei termini dei pedoni, il termine delle
    minacce con valori dei pezzi cambiati, le due valutazioni e la scomposizione fra loro, make e
    unmake con lo stato incrementale, il controllo di coerenza, `bitboard-mirror` contro
    `mirror-position`, l'allocazione (più di 800000 valutazioni, al più 1 MiB);
  - `search` sul riferimento e `optimized-search` sul livello ottimizzato: alpha-beta e negamax
    con lo stesso valore, la stessa mossa migliore e la stessa variante principale; il valore che
    non cambia permutando le mosse di ogni nodo con semi dichiarati, e un test che la
    permutazione cambi davvero l'ordine; l'iterative deepening uguale alla ricerca diretta a ogni
    profondità; le varianti principali rigiocate dal riferimento, con la sua legalità, fino al
    punteggio, e un test che il controllo rifiuti varianti false di ogni tipo (quali ricerche,
    a quali profondità e su quali posizioni lo dice [verifica](docs/verifica.md)). Sul livello
    ottimizzato anche l'allocazione (ricerche di più di un milione di nodi, al più 1 MiB) e la
    firma di ricerca (`search-signature-is-reproduced`);
  - `differential`, in più: la scomposizione della valutazione per termine e per colore e il
    punteggio delle due valutazioni del livello ottimizzato contro il riferimento, sulle
    posizioni delle tabelle di perft, dei casi speciali e del fuzzer, su posizioni casuali con
    seme dichiarato e in partite casuali sui due livelli, dove lo stato incrementale si
    confronta con il ricalcolo dopo ogni make e con quello di prima dopo ogni unmake; il valore
    di alpha-beta e di negamax del livello ottimizzato contro alpha-beta del riferimento a
    profondità fissa, e il numero di nodi di negamax. La mossa migliore, la variante principale
    e i nodi di alpha-beta non si confrontano con quelli del riferimento: i due generatori
    scrivono le mosse in ordini diversi. Il riferimento rigioca invece le varianti principali
    delle ricerche confrontate e quelle di alpha-beta del livello ottimizzato su altre posizioni
    casuali, e giudica la firma di ricerca (`search-signature-is-judged-by-the-reference`).

  Quanti test e quante asserzioni sono lo stampa `make test`.
- **Firma di ricerca** in [`tests/search-signature.sexp`](tests/search-signature.sexp): valore,
  mossa migliore, numero di nodi e variante principale di alpha-beta del livello ottimizzato a
  profondità 4, un thread, su dodici posizioni (le sette di perft, due di mediogioco quiete e tre
  tattiche), con un'intestazione di provenienza. La scrive solo `make signatures`
  (`tools/signatures.lisp`), che la rilegge e la confronta con ciò che ha calcolato; `make test`
  la ricalcola. È un valore di regressione di questo engine, non un oracolo
  ([verifica](docs/verifica.md#regressione-di-ricerca)). La giudica il riferimento: `make test`
  ne rigioca le varianti principali, `make differential-deep` ne confronta anche i valori con
  quelli del suo alpha-beta a profondità 4. Dal formato 2 registra anche la ricerca di default
  della Fase 3, con la TT in modalità di verifica, sulle stesse posizioni: i valori sono quelli
  di alpha-beta, e un test lo controlla.
- **Benchmark:** un harness che stampa il registro dell'ambiente (data, comando esatto,
  revisione e stato dell'albero di lavoro, SBCL, macchina, policy di compilazione,
  implementazione degli attacchi, semi, carico medio) e poi misura in tempo CPU, con i byte
  allocati e il tempo del GC di ogni riga, in quest'ordine: perft del riferimento e del livello
  ottimizzato compilato con ciascuna implementazione degli attacchi, in passate nell'ordine
  `fixed-magic magic ray ray magic fixed-magic` con campioni di circa mezzo secondo di CPU e la
  tabella di ogni passata; due gruppi di righe di un benchmark di engine
  (`benchmarks/search-bench.lisp`); le utilità sui bit; gli attacchi dei pezzi a lunga gittata
  di ogni implementazione. I conteggi attesi di perft vengono da `tests/test-perft.lisp`. Del
  benchmark di engine, cinque righe danno i nodi di ricerca per secondo di CPU di alpha-beta del
  livello ottimizzato alla profondità della firma, una per ciascuna di cinque delle sue
  posizioni, con ogni chiamata confrontata con il valore e i nodi registrati nella firma; tre
  righe danno i nanosecondi per chiamata della valutazione del livello ottimizzato, con lo stato
  incrementale e da zero, e di quella del riferimento, sulle stesse posizioni casuali con seme
  dichiarato, dopo il controllo che diano la stessa somma, in passate A B C C B A con la mediana
  di ogni passata. Dalla Fase 3, le ricerche della Fase 3 con undici configurazioni (con e senza
  ordinamento e TT, tre dimensioni, tre politiche, due modalità) in due passate, con nodi, tempo,
  efficienza dell'ordinamento, cutoff rate, tipi di nodo e hit rate, e il costo di inserimento e
  sonda della TT (`benchmarks/search-variants-bench.lisp`). Il tempo reale è stampato solo
  accanto alle righe di perft e per l'intera esecuzione. Sono misure di una macchina, non
  risultati; nessuna dice qualcosa sulla forza.
- **Strumenti** in Common Lisp: build senza avvisi con autotest del controllo degli avvisi,
  linter con autotest, controllo di link e ancore con autotest (portato da ArcDocDB), perft
  profondo, test differenziale profondo, benchmark, ispezione del hot path (note di efficienza,
  scansione del disassemblato delle funzioni di nodo del perft e delle ricerche, di
  `bitboard-evaluate`, dell'ordinamento e di sonda e inserimento nella TT, provata prima su
  funzioni piantate, allocazione, tempi per policy),
  generatore dei numeri magici e scrittore della firma di ricerca.
- **Makefile** con i target `help`, `build`, `test`, `test-checked`, `lint`, `lint-selftest`,
  `links`, `check`, `perft-deep`, `differential-deep`, `bench`, `hot-path`, `magics` e
  `signatures`.
- **Documentazione** in [`docs/`](docs/README.md): classificazione, architettura, verifica,
  misure, roadmap (le fasi 0…12 della specifica), invarianti (35, di cui quattro, da INV-C7 a
  INV-C10, proposti per la valutazione), glossario, limiti e rischi con 19 questioni, di cui 18
  aperte e una, QA-17, risolta, valutazione, e diciannove [ADR](docs/adr/README.md) più il
  modello: diciassette Accettati (dieci erano Proposta fino al 2026-10-04: vedi *Cambiato*) e
  due, 0018 e 0019, in stato Proposta. Tra questi, 0010…0013 raccolgono le regole per applicare
  0002, 0003, 0008 e 0007, 0014…0016 il disegno del livello ottimizzato, 0017 il percorso di
  ricerca per le alternative `[EXACT]` con le stesse uscite, 0018 la definizione della
  valutazione classica e 0019 la valutazione e la ricerca del livello ottimizzato.
- **Definizione della valutazione classica** in [`docs/valutazione.md`](docs/valutazione.md),
  proposta con [ADR-0018](docs/adr/0018-definizione-della-valutazione-classica.md): i nove
  termini della specifica (materiale, piece-square tables, mobilità, sicurezza del re, struttura
  pedonale, pedoni passati, spazio, iniziativa, minacce) come formule intere in centipawn, con
  quali pezzi e case contano e come si definisce un attacco; una fase dal materiale non di pedone
  (al più 62) e una miscela fra mediogioco e finale troncata verso zero, che conserva la
  simmetria dei colori; il punteggio dal Bianco restituito da chi muove, limitato a ±20000; lo
  stato incrementale del livello ottimizzato (materiale, piece-square tables, fase); le
  convenzioni per la ricerca; esempi calcolati da usare come valori attesi. Nessun peso è
  tarato dal repository; ognuno ha accanto una regola semplice. La regola non fissa i sei pesi
  della struttura pedonale, e il documento lo dice: il repository non registra come siano stati
  scelti. La sezione
  [Provenienza](docs/valutazione.md#provenienza) elenca le coincidenze note con il sorgente
  pubblicato di Fruit 2.1 e con la valutazione classica di Stockfish 11: cinque dei sei pesi
  della struttura pedonale sono costanti di Fruit 2.1 negli stessi ruoli, il caso dubbio che
  decide l'autore ([QA-18](docs/limiti-e-rischi.md#qa-18)). Gli invarianti INV-C7…INV-C10, in
  stato Proposta. La implementano i due livelli (sopra).
- **Metodo di ricerca** in [`research/`](research/README.md): la sequenza della specifica, un
  modello di esperimento e due record:
  [EXP-0001](research/exp-0001-attacchi-dei-pezzi-a-lunga-gittata.md) (magic bitboard contro
  raggi), Accettato il 2026-10-04 secondo ADR-0017, e
  [EXP-0002](research/exp-0002-stato-incrementale-della-valutazione.md) (stato incrementale
  della valutazione contro ricalcolo), Proposto: la variante senza stato che deve misurare non
  esiste ancora.
- **Superficie GitHub:** CI che esegue `make check` su Ubuntu e macOS, Dependabot, CODEOWNERS,
  moduli per issue, modello di pull request, `SECURITY.md`, `SUPPORT.md`, `CODE_OF_CONDUCT.md`,
  e lo script `.github/labels.sh`, che crea le etichette usate dai moduli e da Dependabot. Lo
  esegue il maintainer con la CLI di GitHub.
- **Linguaggio visivo** ([assets/README.md](assets/README.md)), lo stesso di ArcDocDB con
  l'ambra riservata a ciò che può ancora cambiare. Il marchio è una forchetta: il ramo ambra è
  la variante principale; c'è anche una versione disegnata per i 16 px. L'illustrazione è
  l'albero minimo di Knuth e Moore (due mosse per posizione, cinque semimosse: undici foglie
  cercate su trentadue), contabile e non decorativo. Il diagramma mostra le verifiche che ogni
  modifica deve superare. Tutto in vettoriale, in variante chiara e scura; l'anteprima per i
  social è una sola variante con lo sfondo opaco, in SVG e in PNG (1280 × 640). Scelta tra tre
  direzioni grafiche, ciascuna disegnata, renderizzata e giudicata.
- `README.md`, `CLAUDE.md` e questo file, riscritti.

### Cambiato

- **Il modello di riferimento è riscritto da zero.** La posizione è un vettore piatto di 64 byte,
  non un array di coppie. La struttura si chiama `chess-position`.
- **Nessuna dipendenza esterna.** La prima bozza dichiarava Alexandria e trivial-features per il
  sistema principale e FiveAM per i test. Ora l'harness di test è del repository
  ([ADR-0004](docs/adr/0004-nessuna-dipendenza-esterna-e-harness-proprio.md)). I
  sistemi `scacchiforge-test` e `scacchiforge-bench` diventano `scacchiforge/test` e
  `scacchiforge/bench`.
- **`CONTRIBUTING.md`, il modello di pull request e `.gitignore` sono riscritti.** La CI è
  sostituita da un flusso che esegue `make check`.
- **La roadmap segue la specifica:** le fasi 0…12, con un gate per fase e senza date né durate.
- **Dopo il commit 371b205**, a seguito di quattro revisioni indipendenti (verità delle
  affermazioni, motore, documentazione, superficie GitHub):
  - *Motore.* `PARSE-FEN` accetta solo le cifre ASCII 0…9: le altre cifre decimali Unicode, che
    `DIGIT-CHAR-P` accetta, sono rifiutate. I due orologi si fermano a `+MAX-CLOCK+`, 9999999,
    il valore più alto che una FEN accetta (sette cifre); `UNMAKE-MOVE` ripristina il numero di
    mossa dal record di annullamento invece di ricalcolarlo. `RNG-BELOW` rifiuta un `N` maggiore
    di 2^64 con un `TYPE-ERROR`: un'estrazione di 64 bit non copre un intervallo più grande.
  - *Classificazione nel codice.* I docstring delle funzioni che riducono lavoro hanno i campi
    `Classification:`, `Basis:` ed `Evidence:`.
  - *Build.* `tools/load.lisp` lascia passare solo la ridefinizione dallo stesso file; una
    ridefinizione da un altro file fa fallire la build. `tools/build.lisp --self-test` lo prova
    su cinque casi piantati, dentro `make lint-selftest`.
  - *Provenienza dei valori di perft*, nell'intestazione di `tests/test-perft.lisp`, riscritta con
    fonti datate: la pagina *Perft Results* della Chess Programming Wiki per sei posizioni, il file
    `src/perft/standard.epd` di Ethereal per la posizione di promozione e per l'arrocco con i
    quattro diritti, la lista di Peter Ellis Jones per una profondità di ogni altro caso
    speciale. Gli altri conteggi sono dichiarati valori di regressione, output di questo engine.
    Nei test di splitmix64 i primi valori attesi vengono da una fonte pubblicata (rand_xoshiro);
    gli altri sono dichiarati output di questa implementazione.
  - *Durate.* Tolte quelle scritte nel Makefile e in `tools/perft-deep.lisp`.
  - *ADR.* Il testo degli ADR accettati 0002, 0003, 0006, 0007 e 0008 è cambiato, la loro
    decisione no. ADR-0002 e ADR-0003 hanno un solo Stato, «Accettata». I blocchi Proposta di
    0002, 0003, 0007 e 0008 sono passati in quattro ADR nuovi, in stato Proposta: 0010 (regole di
    indipendenza tra i livelli), 0011 (convenzioni di classificazione), 0012 (lettura del gate di
    perft e provenienza dei valori attesi), 0013 (interpretazione operativa dell'originalità).
    In ADR-0006 il blocco su «Elo per CPU-secondo» è marcato Aperto (QA-08). Nelle conseguenze
    di ADR-0002 e ADR-0008 è corretto il testo che andava oltre la specifica. ADR-0004, 0005 e
    0009, in stato Proposta, sono corretti dove non corrispondevano al repository: come si
    eseguono gli strumenti, che le chiavi distinte e non nulle le controlla un test, e che
    l'elenco dei termini inglesi è uno solo, nel glossario.
  - *CI.* Le immagini dei runner sono fissate (`ubuntu-24.04`, `macos-26`) al posto delle
    etichette `-latest`. `.github/labels.yml`, che nessuno strumento applicava, è sostituito da
    `.github/labels.sh`.
  - *LICENSE.* Il titolare del copyright è Giacomo Picchiarelli, come in ADR-0007, nel README
    e in `scacchiforge.asd`. La prima bozza scriveva «ScacchiForge Contributors».
  - *Registro dell'ambiente.* `make bench` stampa le voci del
    [registro dell'ambiente](docs/misure.md#registro-dellambiente): data, comando esatto,
    revisione e stato dell'albero di lavoro, SBCL e ASDF, parametri del GC, sistema operativo,
    CPU, policy di compilazione, semi, posizioni. La politica di frequenza della CPU è dichiarata
    non registrata. Prima di misurare ricompila nello stesso processo i sistemi che misura. Le
    misure sono in tempo CPU, con i byte allocati e il tempo del GC; il tempo reale è stampato
    solo accanto alle righe di perft e per l'intera esecuzione. Era la voce del gate della Fase 0
    proposto dalla roadmap che mancava.
  - *Livelli.* Un test controlla che il livello ottimizzato nomini del riferimento solo il tipo
    della posizione, i suoi accessori e il costruttore (punto 4 di ADR-0010, in stato Proposta).
- **Dopo il commit 340515a**, con il lavoro della Fase 1 (il generatore del livello ottimizzato,
  in *Aggiunto*):
  - *Casi speciali sui due livelli.* `tests/test-movegen.lisp` definisce i suoi test con
    `deftest-movegen`: ognuno si esegue sul riferimento (suite `movegen`) e sull'ottimizzato
    (suite `optimized-movegen`). Le funzioni `layer-` di `tests/support.lisp`, sul riferimento,
    chiamano le funzioni del riferimento.
  - *Perft profondo.* `make perft-deep` esegue i perft profondi dei due livelli.
  - *Livelli.* Il livello ottimizzato calcola da sé la chiave della posizione convertita
    (`bitboard-compute-key`): l'accessore della chiave non è più tra i nomi del riferimento che
    può usare (test `optimized-level-names-only-the-reference-position-interface`).
  - *`do-set-bits`* accetta dichiarazioni all'inizio del corpo, come `dolist`.
  - *Benchmark.* Il sistema `scacchiforge/bench` dipende da `scacchiforge/test`, da cui legge i
    conteggi attesi di perft: ogni conteggio è scritto una volta sola, in
    `tests/test-perft.lisp`.
  - *Documenti.* Aggiornati per il nuovo livello: architettura (che cosa esiste, i file del
    livello ottimizzato), verifica (test differenziale, perft dei due livelli, comandi),
    classificazione (righe per il filtro di legalità per maschere e per le magic bitboard),
    misure, limiti e rischi (QA-03 misurato su una macchina, QA-04, l'osservazione su PEXT e
    PDEP, la nuova [QA-17](docs/limiti-e-rischi.md#qa-17) sullo scostamento da INV-X3 del
    default di ADR-0016), l'indice degli ADR, `research/README.md`, `CONTRIBUTING.md`,
    `README.md` e `CLAUDE.md`. Il gate della Fase 1 non è dichiarato chiuso: il README dice
    quale comando mostra ogni sua voce e che cosa resta aperto.
- **Dopo il commit 5d25099**, a seguito di revisioni indipendenti del lavoro della Fase 1 (il
  difetto del build è in *Corretto*):
  - *`make magics`* non dipende più dai numeri nel file. Carica il sistema con la feature
    `:scacchiforge-magic-search`, che salta la costruzione delle tavole alla fine di
    `src/optimized/magic.lisp`, controlla che le tavole siano ancora vuote, cerca, scrive e
    ricarica il sistema senza la feature, così che le tavole si costruiscano dai numeri appena
    scritti. Prima un file con un numero non magico, o scritto per disposizioni diverse,
    fermava lo strumento al caricamento: su una copia con il primo numero di `:magic`
    sostituito da 1 e l'ultimo di `:fixed-magic` tolto, lo strumento di 5d25099 si ferma con
    l'errore della costruzione delle tavole, quello nuovo riscrive un file identico byte per
    byte a quello del commit. Sull'albero di lavoro `make magics` riscrive il file identico.
    L'intestazione dello strumento e ADR-0016 (punti 5 e 6, Conseguenze) lo descrivono.
  - *`make perft-deep` e `make differential-deep`* stampano, dopo il caricamento, la policy e
    l'implementazione degli attacchi con cui è compilato il hot path, come il build
    (`scf-tools:report-build-choices`).
  - *Registro dell'ambiente.* Un file che fa due volte la stessa proclamazione `optimize`,
    come `perft.lisp` prima e dopo la sua parte calda, è nominato una volta: prima la riga di
    `(optimize (speed 1) (safety 2))` diceva `perft perft`.
  - *Benchmark.* Tolta da `benchmarks/perft-bench.lisp` una durata scritta senza il comando
    che la misura.
  - *CI.* Registrate in [QA-12](docs/limiti-e-rischi.md#qa-12) la run 37171203140 sul commit
    340515a e la run 37180782566 sul commit 5d25099, la prima con il lavoro della Fase 1: su
    `ubuntu-24.04` (x86-64, SBCL 2.2.9.debian) e su `macos-26-arm64` (SBCL 2.6.8), 191 test,
    4068483 asserzioni, 0 fallimenti. QA-03 e l'architettura riportano che il test di
    allocazione vi ha stampato 0 byte su entrambe le immagini.
  - *EXP-0001.* L'esecuzione confermativa è ripetuta su un clone pulito del commit 5d25099
    (`make bench`, poi i tre `make test` con `SCF_SLIDERS`, uno alla volta): la provenienza e
    gli esiti del record vengono da lì. La regola di decisione e ciò che resta aperto
    (benchmark di engine, self-play, validazione statistica) non cambiano; la prima esecuzione,
    su un albero non committato, è dichiarata sostituita. ADR-0016 (Valutazione) cita la nuova
    esecuzione e il carico della macchina, salito durante la misura.
  - *Documenti.* ADR-0014 (punto 1: le funzioni fuori dal hot path dopo la sua parte calda;
    punto 3: i file compilati a `safety 3` non si riusano; la riga del build che stampa la
    policy), ADR-0010 (la disponibilità dell'en passant è calcolata tre volte), ADR-0016,
    [verifica](docs/verifica.md) (il test differenziale confronta anche le case attaccate e i
    pezzi che danno scacco; i test del livello ottimizzato aggiunti con la Fase 1),
    [misure](docs/misure.md) (il metodo di `make bench`: campioni calibrati, passate
    A B C C B A, tabella della deriva, carico medio all'inizio e alla fine) e
    [architettura](docs/architettura.md) (le righe di `policy.lisp` e `perft.lisp`; le
    dipendenze dei sistemi) descrivono il codice com'è. In `CLAUDE.md` la regola «Nessuna
    tecnica per sentito dire» rimanda a QA-17 e a EXP-0001 e nomina i tre casi che QA-17
    registra, invece di parlarne come di un punto solo; QA-17 resta aperta. La sezione
    *Status* del README dice quali voci tengono aperto il gate della Fase 1 e che cosa chiude
    ciascuna.
- **Dopo il commit c15291e**, per decisioni dell'autore, Giacomo Picchiarelli, prese il
  2026-10-04 in sessione, rispondendo a domande esplicite. Questo file registra le decisioni; i
  documenti dicono che cosa ne segue.
  - *QA-17: «ADR per le EXACT».* Nuovo
    [ADR-0017](docs/adr/0017-percorso-di-ricerca-per-le-alternative-exact.md), accettato lo
    stesso giorno: per un'alternativa `[EXACT]` le cui uscite sono identiche a quelle
    dell'implementazione esistente o del riferimento, provate da un'equivalenza esaustiva o
    differenziale e dal perft, INV-X3 è soddisfatto dall'equivalenza, dal microbenchmark e da
    `make bench` con il registro dell'ambiente e una regola di decisione; self-play e
    validazione statistica non si applicano. Limiti: non copre ciò che cambia un'uscita (valore,
    mossa scelta, nodi di una ricerca); l'equivalenza è un test in `make check` o in un target
    profondo documentato; il benchmark si esegue su una revisione committata e pulita. L'ADR
    applica le condizioni ai tre casi di QA-17, con i test e i comandi: il default
    `fixed-magic` le soddisfa; il filtro di legalità per maschere (ADR-0015) e l'espansione
    delle funzioni di nodo nel perft (ADR-0014, punto 6) hanno l'equivalenza ma non la misura,
    e l'ADR dice che cosa manca a ciascuno. L'ADR scrive anche che oggi `make bench` non ha
    righe di una ricerca, e che la condizione è `make bench` com'è sulla revisione misurata.
    [QA-17](docs/limiti-e-rischi.md#qa-17) è marcata «Risolta da ADR-0017», con il testo di
    prima. [EXP-0001](research/exp-0001-attacchi-dei-pezzi-a-lunga-gittata.md) è chiuso,
    Accettato: stato, data di chiusura, etichetta finale (`[EXACT]` per le tavole magic,
    `[HEURISTIC]` per lo scarto rapido), sezioni 6-9 riscritte con le ragioni e con il testo di
    prima citato. INV-X3 rimanda a ADR-0017 e ne riporta le condizioni; lo stesso fanno la regola
    «Nessuna tecnica per sentito dire» di `CLAUDE.md`, [research](research/README.md),
    [misure](docs/misure.md#due-livelli-di-benchmark) e `CONTRIBUTING.md`.
  - *EXP-0001, riproduzione non riuscita.* Un controllo indipendente ha ripetuto `make bench` su
    un nuovo clone pulito di 5d25099 mentre altri processi occupavano la macchina: con la regola
    della sezione 1 `:fixed-magic` e `:magic` non si sono distinti. Il record lo dice nelle
    sezioni 9 e 10: il vantaggio di velocità del default va riconfermato su una macchina
    scarica, e se non si conferma il verdetto si riapre. Le uscite restano identiche.
  - *Classificazione.* La tabella delle tecniche nomina ora tutti gli ADR accettati che ne
    decidono una riga: anche ADR-0015 per generazione legale, make/unmake e tavole del livello
    ottimizzato, e ADR-0001 per i microkernel nativi.
  - *ADR: «Accettali tutti».* ADR-0004, 0005, 0009, 0010, 0011, 0012, 0013, 0014, 0015 e 0016,
    in stato Proposta, sono Accettati il 2026-10-04. In ciascuno cambiano lo Stato, la Data (con
    la data di accettazione), «Da confermare dall'autore», che diventa «Confermata dall'autore
    il 2026-10-04», e il blocco Proposta della Decisione, che diventa
    `Deciso (autore → ADR-nnnn)`; il resto del testo no. L'indice degli ADR ha una tabella sola,
    con note su 0014, 0015 e 0016, il cui testo rimanda a QA-17 o descrive EXP-0001 In corso. Lo
    seguono la tabella *Decisions* del README e i conteggi, `SECURITY.md` (le dipendenze sono una
    decisione), `CONTRIBUTING.md` e `CLAUDE.md`. Diventano `Deciso (autore → ADR-nnnn)` i
    blocchi Proposta il cui contenuto è la decisione di uno di questi ADR: in
    [classificazione](docs/classificazione.md) intestazione, regole d'uso, marcatura e ipotesi
    della TT (ADR-0011); in [architettura](docs/architettura.md) le regole tra i livelli
    (ADR-0010); in [verifica](docs/verifica.md) valori attesi e regole di esecuzione del perft
    (ADR-0012); nella [roadmap](docs/roadmap.md) il gate della Fase 1 prima delle fasi
    successive (ADR-0012); in `CONTRIBUTING.md` il formato della classificazione (ADR-0011) e la
    lingua dei commit (ADR-0009), mentre il titolo breve e il corpo che dice perché restano
    Proposta. Gli altri blocchi Proposta restano tali. Passano a Deciso gli invarianti che questi
    ADR decidono: INV-A1, INV-A2 e INV-A3 (ADR-0010, ADR-0004), INV-X6 (ADR-0005), e in INV-C4
    la parte sui valori pubblicati e di regressione (ADR-0012). Nella tabella delle tecniche,
    che resta una proposta (ADR-0011, punto 4), sono decise le righe che ADR accettati
    classificano, sette, due delle quali solo in parte: le due di Zobrist (ADR-0005);
    generazione legale e make/unmake, decise per il livello ottimizzato, le tavole di attacco,
    decise per le tavole precalcolate e non per PEXT, e il filtro per maschere (ADR-0015); le
    magic bitboard del livello ottimizzato (ADR-0016); i microkernel nativi (ADR-0001).
  - *Prossimo lavoro: la Fase 2.* L'autore ha deciso di procedere alla Fase 2; lo registrano la
    [roadmap](docs/roadmap.md#fase-1), la sezione *Status* del README, con il badge della fase,
    e `CLAUDE.md`. Il gate della Fase 1 è rivalutato voce per voce: le cinque voci della roadmap
    hanno il comando che le mostra; le modifiche fatte dopo 5d25099 le ha eseguite la CI, con la
    run 37183294754 sul commit c15291e (`make check` passato su `ubuntu-24.04`, x86-64, SBCL
    2.2.9.debian, e su `macos-26-arm64`, SBCL 2.6.8: 191 test, 4068483 asserzioni, 0 fallimenti
    su ciascuna), registrata in [QA-12](docs/limiti-e-rischi.md#qa-12); le regole che ogni gate
    aggiunge non hanno una revisione dell'autore registrata, e la voce non è soddisfatta ma
    superata dalla decisione dell'autore di procedere (le revisioni registrate dopo 5d25099
    sono audit di agenti, non dell'autore); lo scostamento da INV-X3 è deciso da ADR-0017.
  - *Anteprima per i social.* L'autore la carica a mano, con le istruzioni di
    [assets/README.md](assets/README.md), che non cambiano. Nessun documento dice che sia
    impostata.
- **Dopo il commit 0408743**, con il lavoro della Fase 2 (in *Aggiunto*). Il commit cc6fceb ne è
  un punto di controllo, fatto su richiesta dell'autore mentre la parte del livello ottimizzato
  era ancora in scrittura.
  - *Ricerche del riferimento.* Valutano le foglie con la valutazione classica, salvo un'altra
    valutazione passata con `:evaluator`, e restituiscono, oltre a valore, mossa migliore e nodi,
    la variante principale; l'iterative deepening la registra per ogni iterazione
    (`iteration-pv`). I test scritti per la valutazione di materiale le passano
    `evaluate-material` esplicitamente, così provano ciò che provavano prima: nessuno è
    indebolito o tolto, e `evaluate-material` con i suoi test non cambia. La suite `search` ha
    cinque test nuovi: `depth-one-is-the-best-negated-child-evaluation`,
    `principal-variation-leads-to-the-score`, `alpha-beta-value-does-not-depend-on-the-move-order`,
    `a-permutation-really-changes-the-search-order` e
    `iterative-deepening-equals-the-direct-search-at-every-depth`.
  - *Make e unmake del livello ottimizzato* salvano e riportano anche lo stato incrementale della
    valutazione, in tre vettori nuovi dello stack di undo. La conversione dal riferimento lo
    calcola da zero, `bitboard-consistent-p` lo ricalcola, `bitboard-equal-p` e `bitboard-clone`
    lo comprendono. Il perft, che non valuta, fa quindi più lavoro per mossa, e nessun comando del
    repository isola quel costo
    ([ADR-0019](docs/adr/0019-valutazione-e-ricerca-del-livello-ottimizzato.md), Conseguenze).
  - *Hot path.* `evaluation` e `search` sono in `*hot-path-files*`: `make test-checked` le
    esegue a `safety 3`, e `make hot-path` scansiona anche il disassemblato di
    `bitboard-evaluate`, `negamax-node` e `alpha-beta-node`.
  - *Documenti.* Nuovi `docs/valutazione.md` e ADR-0018, con gli invarianti INV-C7…INV-C10 (in
    *Aggiunto*); [verifica](docs/verifica.md) e [architettura](docs/architettura.md) descrivono
    la valutazione e la ricerca del riferimento. Il codice del livello ottimizzato, già nel
    commit cc6fceb, vi era ancora descritto come previsto.
- **Dopo il commit cc6fceb**, a seguito di revisioni del lavoro della Fase 2, fatte da agenti e
  non dall'autore. Le porta il commit b3190dc.
  - *CI.* Registrata in [QA-12](docs/limiti-e-rischi.md#qa-12) la run 37198250566 sul commit
    cc6fceb, la prima con codice della Fase 2: su `ubuntu-24.04` (x86-64, SBCL 2.2.9.debian) e
    su `macos-26-arm64` (SBCL 2.6.8), 252 test, 4507840 asserzioni, 0 fallimenti. Sulle due
    immagini la firma di ricerca è riprodotta, e i test di allocazione hanno stampato 0 byte per
    il perft (1808266 mosse fatte e disfatte), per la valutazione (800002 valutazioni) e per la
    ricerca (1957626 nodi).
  - *Minacce nel livello ottimizzato.* L'attaccante più economico è il minimo dei valori di
    `**piece-values**` fra i tipi di pezzo che attaccano la casa, quali che siano i valori, e non
    più il primo di un ordine fisso (pedone, cavallo o alfiere, torre, donna), che dà lo stesso
    risultato solo finché i valori seguono quell'ordine e cavallo e alfiere valgono uguale. Che
    le due divisioni del termine siano esatte con i valori dei pezzi lo controlla il caricamento
    di `src/optimized/evaluation-tables.lisp` (`check-exact-threat-divisions`): un parametro che
    le rende inesatte ferma il caricamento. Con i valori di oggi i punteggi non cambiano. Nuovo
    test `optimized-evaluation/threat-term-follows-the-piece-values`.
  - *Attacco al re nel livello ottimizzato.* I contatori `U` e `n` hanno i tipi dei loro limiti
    reali (`attack-units`, `attacker-count`) invece di `(signed-byte 32)`, così che
    `4 · U · (n − 1)` stia in una parola: la scansione di `make hot-path` non trova in
    `bitboard-evaluate` chiamate piene, chiamate di routine (l'aritmetica generica è fra queste)
    né allocazioni.
  - *Test.* Due posizioni calcolate a mano in più, eseguite sui due livelli: i pedoni doppiati
    e4 ed e5, dove il pedone di dietro non è passato anche se nessun pedone avversario lo
    ferma, e una torre che dà scacco al re in g8, la cui casa appartiene alla zona del re. Con il
    test delle minacce, `make test` esegue 253 test.
  - *Benchmark.* Le tre righe della valutazione si eseguono in due passate intercalate,
    A B C C B A, e la tabella dà la mediana di ogni passata, così che una deriva della macchina
    si veda; la loro differenza è dichiarata una misura di una macchina in un momento.
  - *Firma di ricerca.* `make signatures` rilegge il file che ha scritto e lo confronta con ciò
    che ha calcolato (formato, algoritmo, profondità, ogni voce), ed esce con un errore se
    differiscono. Il file è stato riscritto: cambiano solo le due righe dell'intestazione con la
    revisione di base e la data, non le voci.
  - *Decisioni e questioni.* Nuovo
    [ADR-0019](docs/adr/0019-valutazione-e-ricerca-del-livello-ottimizzato.md), in stato
    Proposta: copia dei parametri per livello, stato incrementale riletto dallo stack di undo,
    contesto della ricerca, che cosa si confronta con il riferimento, formato e regola di
    aggiornamento della firma. Dichiara due scostamenti da invarianti Decisi, che un ADR in stato
    Proposta non può esentare: [QA-19](docs/limiti-e-rischi.md#qa-19), nuova, i parametri della
    valutazione nel codice contro INV-X7; lo stato incrementale senza la misura che ADR-0017
    chiede, contro INV-X3, con il nuovo record
    [EXP-0002](research/exp-0002-stato-incrementale-della-valutazione.md), Proposto. Nuova
    [QA-18](docs/limiti-e-rischi.md#qa-18): cinque dei sei pesi della struttura pedonale sono
    costanti di Fruit 2.1 negli stessi ruoli, e la regola scritta non li fissa; la sezione
    [Provenienza](docs/valutazione.md#provenienza) di `docs/valutazione.md` elenca questa e le
    altre coincidenze note.
  - *Documenti.* [Verifica](docs/verifica.md) (la sezione sulla valutazione e la ricerca del
    livello ottimizzato, la regressione di ricerca con la prima firma e la sua regola di
    aggiornamento, i comandi), [architettura](docs/architettura.md) (i file nuovi, l'allocazione
    della valutazione e della ricerca), [misure](docs/misure.md) (le righe della ricerca e della
    valutazione di `make bench`), l'indice degli ADR (note su 0014 e 0017) e `CONTRIBUTING.md`
    (quando si esegue `make signatures`) descrivono il livello ottimizzato com'è. La sezione
    *Status* del README valuta il gate della Fase 2 voce per voce, con il comando che mostra
    ciascuna, e dice che cosa lo tiene aperto; il gate non è dichiarato chiuso. `CLAUDE.md` lo
    riassume, nomina QA-18 e QA-19 e aggiunge lo stato incrementale ai casi con l'equivalenza ma
    senza la misura di ADR-0017.
- **Dopo il commit b3190dc**, a seguito di una verifica della verità delle affermazioni fatta da
  agenti, non dall'autore (le frasi corrette sono in *Corretto*):
  - *CI.* Registrate in [QA-12](docs/limiti-e-rischi.md#qa-12), nella tabella *Status* del
    README e in QA-03 la run 37193831706 sul commit 0408743 (191 test, 4068483 asserzioni, 0
    fallimenti su ciascuna immagine) e la run 37215795264 sul commit b3190dc, che porta le
    modifiche fatte dopo cc6fceb: su `ubuntu-24.04` (x86-64, SBCL 2.2.9.debian) e su
    `macos-26-arm64` (SBCL 2.6.8), 253 test, 4507911 asserzioni, 0 fallimenti; sulle due
    immagini la firma di ricerca è riprodotta e i tre test di allocazione hanno stampato 0 byte.
  - *Gate della Fase 2.* La voce aperta «le modifiche fatte dopo cc6fceb sono state eseguite
    solo sulla macchina dell'autore» è soddisfatta dalla run 37215795264: il README e
    `CLAUDE.md` la tolgono dall'elenco di ciò che resta aperto e dicono che cosa la soddisfa. Il
    gate non è dichiarato chiuso.
- **Dopo il commit ae86fe3**, a seguito di una verifica della verità delle affermazioni fatta da
  agenti, non dall'autore (le frasi corrette sono in *Corretto*). Nessun test è tolto o
  indebolito; pesi, ricerche e firma di ricerca non cambiano. `make test` esegue 258 test.
  - *Controllo delle varianti principali.* `principal-variation-problems`
    (`tests/test-search.lisp`) tratta a parte i punteggi di matto: la variante deve finire in
    scacco matto esattamente al ply che il punteggio dice, prima della profondità, con il segno
    del lato che dà matto; gli altri punteggi restano la valutazione alla fine della variante,
    vista dalla radice, o 0 in uno stallo. Il nuovo test
    `search/principal-variation-check-finds-planted-errors` controlla che rifiuti varianti
    false di ogni tipo e accetti quelle vere.
  - *Varianti principali in `make test`.* `search/principal-variation-leads-to-the-score`
    rigioca anche negamax a profondità 3, dove `alpha-beta-equals-negamax-up-to-depth-three` lo
    esegue; `optimized-search/principal-variation-leads-to-the-score` rigioca alpha-beta da 0 a
    4 e negamax da 0 a 3 sulle posizioni di ricerca e alpha-beta a profondità 4 sulle dodici
    posizioni della firma, sulla posizione di riferimento letta dalla FEN invece che su quella
    convertita dal livello ottimizzato (l'aiuto `reference-of`, non più usato, è tolto). I test
    `alpha-beta-value-does-not-depend-on-the-move-order` dei due livelli rigiocano anche negamax
    permutato, e quello del livello ottimizzato anche alpha-beta permutato a profondità 4; i
    test `iterative-deepening-mate-stop-equals-the-full-depth-search` dei due livelli rigiocano
    la ricerca diretta e l'ultima iterazione. `differential/search-values-equal-the-reference`
    rigioca le varianti delle tre ricerche che confronta. Il nuovo test
    `differential/random-position-variations-are-checked-by-the-reference` rigioca quelle di
    alpha-beta del livello ottimizzato su posizioni casuali con seme 20261008: 40 a profondità 3
    in `make test`, 200 a profondità 5 in `make differential-deep`.
  - *Firma di ricerca giudicata dal riferimento.* Il nuovo test
    `differential/search-signature-is-judged-by-the-reference` legge
    `tests/search-signature.sexp`: in `make test` il riferimento rigioca la variante principale
    registrata di ogni voce, che deve portare al valore registrato, e la mossa migliore
    registrata deve esserne la prima; in `make differential-deep` alpha-beta del riferimento
    cerca anche ogni posizione a profondità 4, e il valore deve essere quello registrato e
    quello di alpha-beta del livello ottimizzato. È in `make differential-deep` e non in
    `make test` perché quella ricerca del riferimento visita 899060 nodi, con la valutazione
    classica calcolata da zero a ogni foglia.
- **Dopo il commit 024bdb9**, per decisioni dell'autore, Giacomo Picchiarelli, prese il
  2026-10-04 rispondendo a domande esplicite, e applicate in un solo commit.
  - *Pesi della struttura pedonale ([QA-18](docs/limiti-e-rischi.md#qa-18), «Sostituisci»).* I
    sei pesi della prima stesura (doppiato 10 / 20, isolato 10 / 15, arretrato 8 / 10), che la
    regola di allora non fissava e cinque dei quali erano costanti di Fruit 2.1 negli stessi
    ruoli, sono sostituiti da pesi che una regola scritta fissa
    ([valutazione](docs/valutazione.md#struttura-pedonale)): un'unità per ogni sostegno che manca
    al pedone, `floor(100 / 16) = 6` in mediogioco e `floor(3 · 100 / 32) = 9` in finale;
    doppiato e arretrato 6 / 9, isolato 12 / 18. Nessuno è uguale al peso di Fruit 2.1 nello
    stesso ruolo; il confronto con altri engine non è rifatto per i valori nuovi. Cambiano nello
    stesso commit le due copie dei parametri, gli esempi calcolati del documento (re e pedone
    contro re 92 e −72, la posizione 3 −21; iniziale, Kiwipete e posizione 4 invariati), i
    valori attesi dei casi calcolati a mano nei test e la firma di ricerca, riscritta da
    `make signatures`. L'esempio dell'arrotondamento verso zero passa al pedone e4 contro il
    cavallo d5 (−189, con `floor` −190): la posizione 3 ha ora un quoziente esatto. Le altre
    coincidenze di [Provenienza](docs/valutazione.md#provenienza) restano: l'autore non ha
    chiesto di rivederle. Nessuna affermazione sulla forza: la valutazione non è tarata e non ha
    giocato partite.
  - *Parametri della valutazione ([QA-19](docs/limiti-e-rischi.md#qa-19), «Rimanda a Fase 10»).*
    [ADR-0020](docs/adr/0020-parametri-della-valutazione-dalla-fase-10.md), accettato: INV-X7 si
    applica ai parametri della valutazione dalla Fase 10; fino ad allora restano costanti nel
    codice dei due livelli. QA-19 è chiusa.
  - *ADR-0018 e ADR-0019 («Dopo QA-18»).* Accettati il 2026-10-07, dopo la sostituzione dei
    pesi; gli invarianti INV-C7…INV-C10 che 0018 introduce sono Decisi con esso. L'indice degli
    ADR, il README, `CLAUDE.md`, la verifica, l'architettura e EXP-0002 lo riportano.
  - Il gate della Fase 2 resta aperto su due voci: la revisione dell'autore e la misura dello
    stato incrementale ([EXP-0002](research/exp-0002-stato-incrementale-della-valutazione.md)).
- **Dopo il commit 938195c**, per [EXP-0002](research/exp-0002-stato-incrementale-della-valutazione.md):
  - *Variante senza stato.* L'interruttore `SCF_EVAL_STATE` (`incremental`, il default, oppure
    `recompute`), letto e fissato come `SCF_SLIDERS` (`src/optimized/policy.lisp`), compila la
    variante B: make e unmake senza lo stato della valutazione, la valutazione con materiale,
    piece-square tables e fase calcolati dai bitboard. Ogni file del hot path, e
    `bitboard-position.lisp`, controlla al caricamento la scelta con cui è stato compilato. Le
    due varianti passano tutte le suite, compresa la firma di ricerca (`make check` e
    `SCF_EVAL_STATE=recompute make test`: 259 test, 0 fallimenti; anche `make differential-deep`
    con la variante B). I tre test dello stato controllano nella variante B solo ciò che essa
    tiene; il nuovo test `the-evaluation-state-follows-the-build` controlla la differenza.
  - *Righe di `make bench`.* Ricerca e perft del livello ottimizzato con le due varianti,
    compilate una volta ciascuna in `build/bench/state-…/` e misurate in passate A B B A, con
    l'esito della regola di decisione del record stampato in fondo. L'esecuzione confermativa
    si fa sul commit che porta questa voce.
  - *Docstring.* Le docstring di `bitboard-evaluate` e di `evaluate-classical`, e l'intestazione
    di `src/reference/classical.lisp`, dicevano ancora che l'origine dei pesi della struttura
    pedonale non era registrata: ora dicono che li fissa una regola (QA-18).
- **Dopo il commit dd5a2a5**, l'esecuzione confermativa di
  [EXP-0002](research/exp-0002-stato-incrementale-della-valutazione.md): `make bench` su un clone
  pulito di dd5a2a5, il 2026-10-08, carico medio fra 4 e 5 su 10 CPU logiche. In tutte e cinque
  le righe della ricerca il massimo della variante con lo stato è sotto il minimo della variante
  senza, e la sua mediana è più bassa in entrambe le passate: la regola del record dà «A più
  rapida di B». Nel perft, che non valuta, la variante senza stato ha la mediana più bassa in
  ogni riga: lo stato costa in make e unmake, come il razionale prevede. Il record è chiuso,
  Accettato secondo ADR-0017, e lo stato resta; le cifre non sono copiate nel repository
  (QA-14). Una misura di una macchina: x86-64 non è misurato. README, `CLAUDE.md`, architettura,
  valutazione, misure, l'indice degli esperimenti e quello degli ADR lo riportano. Il gate della
  Fase 2 resta aperto su una voce: la revisione dell'autore.
- **Dopo il commit 094fd8f**, per decisione dell'autore del 2026-10-08 di procedere alla Fase 3,
  con il lavoro della Fase 3 (in *Aggiunto*):
  - *Fase 2 chiusa.* Le cinque voci del suo gate hanno ciascuna il comando che la mostra; la voce
    delle regole che ogni gate aggiunge non è soddisfatta, perché nessuna revisione dell'autore
    del lavoro della Fase 2 è registrata, ed è superata dalla decisione dell'autore di procedere,
    come per la Fase 1. README, `CLAUDE.md` e roadmap lo riportano.
  - *Tre ADR in stato Proposta:* [ADR-0021](docs/adr/0021-transposition-table-del-livello-ottimizzato.md)
    (la TT, con i default proposti per QA-01 e QA-02, che restano aperte),
    [ADR-0022](docs/adr/0022-pvs-negascout-e-tipi-di-nodo.md) (PVS, NegaScout, tipi di nodo,
    ricerca di default, firma in formato 2) e
    [ADR-0023](docs/adr/0023-ordinamento-delle-mosse-della-fase-3.md) (ordinamento). Le tre
    tecniche cambiano i nodi di una ricerca: il loro record,
    [EXP-0003](research/exp-0003-ricerca-della-fase-3.md), è Proposto, e lo scostamento da INV-X3
    è dichiarato (self-play e validazione statistica non esistono ancora).
  - *Test.* Due suite nuove, `optimized-tt` e `optimized-pvs` (22 test): la modalità di verifica
    contro la ricerca senza TT con tabelle da 2 a 65536 slot e le tre politiche, falsi riscontri
    forzati con una maschera di chiave, mosse di altre posizioni e entry alterate mai eseguite,
    ogni entry come bound vero, una posizione raggiunta per due percorsi; PVS, NegaScout e
    l'ordinamento contro alpha-beta, anche permutati; l'ordine della regola ricalcolato dal test;
    l'albero minimo di Knuth e Moore con un ordinamento perfetto; i tipi di nodo; l'allocazione.
    La suite `differential` confronta anche il valore e la variante della ricerca di default con
    il riferimento. `make check` esegue 281 test.
  - *Firma di ricerca.* Formato 2, riscritto da `make signatures`: la parte di alpha-beta è
    invariata (cambia solo l'intestazione), e si aggiunge la ricerca di default della Fase 3 con
    la TT in modalità di verifica, con nodi diversi e gli stessi valori. Lo strumento rilegge
    le due parti.
  - *Documenti.* Classificazione (le righe di PVS e NegaScout, della TT e dell'ordinamento
    nominano gli ADR proposti), verifica (la sezione *Ricerca della Fase 3*, la modalità di
    verifica implementata, la firma in due parti), architettura, misure, invarianti (INV-C5 e
    INV-C6 con i loro test), questioni aperte (QA-01, QA-02, QA-05), roadmap, README, `CLAUDE.md`
    e `CONTRIBUTING.md`.
  - *Esempio del README.* L'esempio della ricerca nel *Quick start* stampava 61792 nodi: la
    ricerca e la firma danno 61888 dalla modifica dei pesi della struttura pedonale. Ora
    stampa 61888, ed è seguito dalla ricerca di default. Allo stesso modo
    [verifica](docs/verifica.md#regressione-di-ricerca) e un commento di
    `tests/test-optimized-search.lisp` dicevano che alpha-beta del riferimento visita 899060 nodi
    sulle dodici posizioni della firma: `make differential-deep` ne stampa 897329.

### Rimosso

- `DESIGN.md` e `ROADMAP.md`, sostituiti da [`docs/`](docs/README.md).
- I file della prima bozza: `src/reference/board.lisp`, `src/reference/types.lisp`,
  `src/optimized/bitboards.lisp`, `src/optimized/board-opt.lisp`, `tests/test-position.lisp`,
  `benchmarks/engine-bench.lisp`, `benchmarks/microbench.lisp`.
- Il vecchio flusso di CI `.github/workflows/test.yml` e i modelli di issue `bug.md` e
  `research.md`.
- `.github/labels.yml`, sostituito da `.github/labels.sh`.

### Corretto

- **La prima bozza non è mai stata compilata né eseguita, e non si caricava.** Definiva una
  struttura chiamata `POSITION`, che viola il package lock di `COMMON-LISP`. È la bozza dei
  commit `c8ff85e` e `bc85a20`.
- **Le dichiarazioni di completamento di quella bozza erano sbagliate.** `PHASE_0_COMPLETE.md`
  segnava la Fase 0 «COMPLETE», con le voci «All code compiles without warnings», «Code is
  simple and correct» e «Quality gates established». Nessun comando lo mostrava: il codice non si
  caricava e i test non erano mai stati eseguiti. Il commit `26fe29f` tolse
  `PHASE_0_COMPLETE.md` e riaprì la Fase 0, ma non corresse il codice.
- **Le durate della vecchia roadmap erano segnaposto**, non stime. Sono rimosse, insieme a ogni
  altra durata e data di avanzamento: lo stato di una fase è l'esito del suo gate.
- **Che cosa l'ha sostituita:** il codice è riscritto da zero (vedi *Aggiunto*), con perft
  confrontato con valori pubblicati dove esistono. Dove `make check` è stato eseguito, su quale
  revisione e con quale esito, è registrato in
  [QA-12](docs/limiti-e-rischi.md#qa-12).
- **Dopo il commit 5d25099: un target ricaricava file compilati da un target precedente.**
  `scf-tools:load-strict` chiamava ASDF con `:force t`, che ricompila solo il sistema nominato:
  `make perft-deep` e `make differential-deep` caricano `scacchiforge/test`, e `scacchiforge`
  veniva caricato dai file in `build/fasl/` lasciati dal target precedente. Dopo
  `make test-checked`, `make perft-deep` e `make differential-deep` uscivano con codice 2
  sull'errore di `check-compiled-choice` (policy diversa); dopo `make test`,
  `SCF_SLIDERS=magic make perft-deep` faceva lo stesso (implementazione diversa). Ora
  `load-strict` passa ad ASDF, come sistemi da forzare, tutti quelli che `scacchiforge.asd`
  definisce (`scf-tools:project-systems`, letta dal file), non ASDF, UIOP né i contrib di
  SBCL: ogni target che carica il sistema ricompila ogni sistema del repository che carica.
  Le quattro sequenze (le tre sopra e `make bench` dopo `make test-checked`) terminano con
  codice 0. Il build compila i tre sistemi con un caricamento solo; `make hot-path` e
  `make bench` usano lo stesso caricamento. Erano false per questo difetto, e ora sono esatte,
  le frasi che dicevano che ogni target forza la compilazione e che `SCF_SLIDERS` vale per
  ogni target: nel README, in `CLAUDE.md`, in `CONTRIBUTING.md` (che ora dice anche che un
  caricamento non forzato di file compilati con un altro `SCF_SLIDERS` o un'altra policy si
  ferma con un errore), nell'intestazione del Makefile, nel docstring e nel messaggio di
  `check-compiled-choice` (`src/optimized/policy.lisp`), nel docstring di `load-strict` e
  nell'esempio del punto 2 di ADR-0016.
- **Dopo il commit cc6fceb: frasi false nel commit cc6fceb.** Il README e questo file dicevano
  che il codice della Fase 2 non esisteva, che la valutazione classica non era implementata e che
  il livello ottimizzato non aveva ricerca, mentre lo stesso commit aggiungeva
  `src/reference/classical.lisp`, `src/optimized/evaluation.lisp` e
  `src/optimized/search.lisp`. Il README, `docs/valutazione.md` e questo file dicevano anche che
  i pesi della valutazione non vengono da altri engine, e ADR-0018 diceva originali le formule
  delle piece-square tables: cinque dei sei pesi della struttura pedonale sono costanti di Fruit
  2.1 negli stessi ruoli ([QA-18](docs/limiti-e-rischi.md#qa-18)), e generare le tavole da
  formule è anche il modo di Fruit 2.1. Le frasi sono corrette in quei file; ADR-0018 e
  `docs/valutazione.md` rimandano alla sezione [Provenienza](docs/valutazione.md#provenienza).
- **Dopo il commit b3190dc: frasi false o non sostenute.**
  - *Stato dei commit e della CI.* `CLAUDE.md`, il README, questo file,
    [architettura](docs/architettura.md) e [QA-12](docs/limiti-e-rischi.md#qa-12) dicevano che
    le modifiche fatte dopo cc6fceb non erano committate e che la CI non le aveva eseguite;
    il commit b3190dc le porta e la run 37215795264 vi ha passato `make check`.
  - *Righe decise della classificazione.* Il README e la voce di questo file sul commit 0408743
    dicevano decise quattro righe della tabella delle tecniche, mentre
    [classificazione](docs/classificazione.md#tabella-delle-tecniche) ne segna come decise sette,
    due delle quali solo in parte: anche generazione legale e make/unmake del livello
    ottimizzato e le sue tavole precalcolate (ADR-0015) e i microkernel nativi (ADR-0001). Il
    README e la voce dicono ora le sette.
  - *Durate senza comando.* Tre commenti di `tests/test-search.lisp`, scritti con il commit
    cc6fceb, dicevano che negamax con la valutazione classica «takes seconds», senza un comando
    né una macchina (INV-X2). Ora dicono il lavoro in nodi: da circa 47000 a 100000 nodi a
    profondità 3 sulle quattro posizioni grandi, al più circa 23000 per negamax con la
    valutazione classica, circa 350000 per negamax a profondità 5 sulla scala di torri. Li
    stampano, con note nuove, i test `alpha-beta-equals-negamax-up-to-depth-three` e
    `iterative-deepening-mate-stop-equals-the-full-depth-search`; nessuna asserzione cambia. Lo
    stesso per due frasi più vecchie, del commit 371b205: «much slower» nel docstring di
    `position-invariant-violations` e «slower» in un commento di `tests/test-make-unmake.lisp`
    dicono ora il lavoro in più; «small and slow» nell'intestazione di
    `src/reference/search.lisp` dice ora che nulla vi è ottimizzato.
  - *Provenienza dei pesi.* [Valutazione](docs/valutazione.md) e
    [ADR-0018](docs/adr/0018-definizione-della-valutazione-classica.md) (punto 9 e
    Classificazione) dicevano di ogni peso che non viene da dati né da misure, e l'intestazione
    di `src/reference/classical.lisp` diceva che i numeri non vengono da un altro engine. Per i
    sei pesi della struttura pedonale il repository non registra come siano stati scelti, e
    cinque sono costanti di Fruit 2.1 negli stessi ruoli ([QA-18](docs/limiti-e-rischi.md#qa-18)):
    l'affermazione non era sostenuta. Ora i documenti, i docstring di `evaluate-classical` e
    `bitboard-evaluate`, l'indice degli ADR e il README dicono ciò che il repository mostra:
    nessun peso vi è stimato su dati, scelto con una misura registrata o validato da un
    esperimento; dei sei pesi non si afferma l'origine, finché l'autore non decide QA-18.
  - *Re contro re.* [Valutazione](docs/valutazione.md#convenzioni-per-la-ricerca) («Patte per
    regola»), [ADR-0018](docs/adr/0018-definizione-della-valutazione-classica.md) e un commento
    di `tests/test-evaluation.lisp`, scritti con il commit cc6fceb, dicevano che re contro re
    vale 10 per chi muove. Vale 10 solo con i re ugualmente centrali: a fase 0
    `E_W = ±10 + 8 · (cent(s_W) − cent(s_B))`, e per esempio `8/8/8/4k3/8/8/8/4K3 w` vale −14
    in entrambi i livelli. Le frasi dicono ora la formula, e il test nuovo
    `bare-kings-score-the-initiative-and-the-endgame-king-table` la controlla nelle 3612
    disposizioni legali dei due re, con ciascun lato al tratto, in entrambi i livelli.
  - *Repository privato.* La guida rapida del README diceva che il clone funziona solo per un
    account con accesso al repository finché è privato; il repository è pubblico, e la frase è
    tolta.
  - *Cifre di prestazione.* Il README e `CLAUDE.md` dicevano che nel repository non è scritta
    alcuna cifra di prestazione, mentre
    [EXP-0001](research/exp-0001-attacchi-dei-pezzi-a-lunga-gittata.md) registra i rapporti fra
    due passate di un tentativo di riproduzione di `make bench` (con comando, revisione e
    macchina) e il README stesso i byte stampati dai test di allocazione. Ora le due guide
    dicono quali cifre misurate vi sono scritte.
  - *Righe del benchmark di engine.* Il README e la voce *Benchmark* di questo file parlavano
    di «due righe» di un benchmark di engine, stampate dopo le utilità sui bit e gli attacchi;
    `make bench` stampa cinque righe della ricerca e tre della valutazione, due gruppi, fra le
    righe di perft e le utilità sui bit (`run-benchmarks` in `benchmarks/report.lisp`). Il
    testo dice ora i gruppi, le righe e l'ordine.
- **Dopo il commit ae86fe3: frasi non sostenute.**
  - *Varianti principali.* Il README (righe *Differential testing* e *Search* della tabella
    della verifica), [verifica](docs/verifica.md) e
    [ADR-0019](docs/adr/0019-valutazione-e-ricerca-del-livello-ottimizzato.md) (punto 5)
    dicevano che il riferimento controlla ogni variante principale del livello ottimizzato e
    che ogni variante principale è fatta di mosse legali e porta al punteggio. I test le
    controllavano in parte: sul livello ottimizzato non quelle di alpha-beta a profondità 4, di
    negamax permutato, delle posizioni della firma, del test dell'arresto su un matto né del
    confronto con il riferimento; sul riferimento non quelle di negamax permutato né del test
    dell'arresto su un matto, e quelle di negamax a profondità 3 solo attraverso l'uguaglianza con
    quelle di alpha-beta. Ora le controllano i test descritti in *Cambiato*, e i documenti dicono
    quali ricerche, su quali posizioni, a quali profondità e con quale comando.
  - *Valore della firma.* Il README, [verifica](docs/verifica.md#regressione-di-ricerca) e
    ADR-0019 (Conseguenze) dicevano che il valore della firma di ricerca lo giudica il
    riferimento, ma quattro posizioni della firma (`quiet-queens-gambit`, `quiet-italian`,
    `tactical-knight-takes-f7`, `tactical-knight-takes-e5`) non sono posizioni di ricerca, e
    nessun comando ne confrontava il valore con quello del riferimento; le altre otto, che sono
    posizioni di ricerca, le confrontano `make test` fino a profondità 3 e
    `make differential-deep` fino a 4. Ora lo fa
    `differential/search-signature-is-judged-by-the-reference` in `make differential-deep`, e i
    documenti dicono che cosa ne esegue `make test`.
  - *Cifre misurate.* Il README e `CLAUDE.md` dicevano che nel repository sono scritti due soli
    tipi di cifre misurate, e il README che le cifre di `make bench` non vi si copiano.
    [EXP-0001](research/exp-0001-attacchi-dei-pezzi-a-lunga-gittata.md) (sezione 10) registra
    anche carichi medi della macchina, in parte stampati da `make bench`, e la quota di CPU di
    tre processi estranei; [ADR-0016](docs/adr/0016-attacchi-dei-pezzi-a-lunga-gittata.md) dà
    due limiti di quei carichi; le [osservazioni su SBCL](docs/limiti-e-rischi.md#osservazioni-su-sbcl)
    registrano la crescita di `get-internal-run-time` in un secondo. Ora le due guide elencano i
    quattro tipi e dove stanno, e il README dice che le misure in pixel di `assets/README.md`
    sono calcolate dai disegni. Nessuna cifra è tolta dai record di ricerca.
