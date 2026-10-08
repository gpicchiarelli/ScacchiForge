# ADR-0016 — Attacchi dei pezzi a lunga gittata: magic bitboard con numeri del progetto

- **Stato:** Accettata
- **Data:** 2026-10-04; accettata dall'autore il 2026-10-04, per sua decisione in sessione
- **Rapporto con la specifica:** proposta nuova (non nella specifica); applica «MOVE GENERATION»
  («magic bitboards dove vantaggioso», «PEXT/BMI2 dove vantaggioso», «Ogni alternativa deve
  essere benchmarkata»), «DEDUPLICATION» (precalcolo di «magic/PEXT tables»), «NATIVE
  MICROKERNELS», «PERFORMANCE INFRASTRUCTURE» e «RESEARCH METHODOLOGY». Confermata dall'autore il
  2026-10-04.
- **Riferimenti:** [ADR-0015](0015-generatore-di-mosse-del-livello-ottimizzato.md) (punto 3),
  [ADR-0014](0014-policy-di-compilazione-del-livello-ottimizzato.md),
  [ADR-0013](0013-interpretazione-operativa-dell-originalita.md),
  [ADR-0007](0007-licenza-bsd-2-clause-e-originalita.md),
  [ADR-0001](0001-common-lisp-sbcl.md),
  [classificazione](../classificazione.md#generazione-tabelle-hardware),
  [misure](../misure.md#due-livelli-di-benchmark), INV-A5, INV-A8, INV-H1, INV-X2, INV-X3, INV-X6,
  INV-X9, [QA-04](../limiti-e-rischi.md#qa-04), [QA-12](../limiti-e-rischi.md#qa-12),
  [QA-14](../limiti-e-rischi.md#qa-14), [QA-17](../limiti-e-rischi.md#qa-17),
  [EXP-0001](../../research/exp-0001-attacchi-dei-pezzi-a-lunga-gittata.md)

## Contesto

[ADR-0015](0015-generatore-di-mosse-del-livello-ottimizzato.md) mette gli attacchi di alfiere,
torre e donna dietro un'interfaccia sola, `bishop-attacks` e `rook-attacks` di una casa e di
un'occupazione, con l'implementazione classica per raggi, e rimanda magic bitboard e PEXT a un
passo successivo, dietro la stessa interfaccia e con la propria misura. La specifica li chiede
«dove vantaggioso» e vuole ogni alternativa misurata.

Una magic bitboard è una tecnica pubblicata (Chess Programming Wiki, voci «Magic Bitboards» e
«Looking for Magics»). Gli attacchi di un pezzo a lunga gittata da una casa dipendono solo
dall'occupazione delle sue *case rilevanti*: le case dei suoi raggi tranne l'ultima di ciascun
raggio, perché un pezzo sul bordo non blocca nulla dietro di sé. Un *numero magico* della casa
trasforma quell'occupazione in un indice di una tavola precalcolata,
`((occupazione AND maschera) · M mod 2^64) >> (64 − bit)`; è buono se due insiemi di bloccanti
con attacchi diversi non hanno mai lo stesso indice.

Restano da decidere tre cose: da dove vengono i numeri magici, che il vincolo di originalità
non permette di copiare da altri engine ([ADR-0013](0013-interpretazione-operativa-dell-originalita.md),
punto 2: niente tabelle di costanti di altri engine); come si sceglie l'implementazione senza
toccare il codice e senza costo nel hot path; quale implementazione è il default.

PEXT è un'istruzione x86-64 dell'estensione BMI2. SBCL portabile non la espone: su SBCL 2.6.9,
macOS arm64, `(apropos-list "PEXT")` restituisce `NIL`. Raggiungerla chiede codice nativo (una
VOP di SBCL o una chiamata FFI), che la specifica ammette solo a cinque condizioni
([ADR-0001](0001-common-lisp-sbcl.md)); le prime due, un hot spot dimostrato dal profiling e
codice inadeguato prodotto da SBCL, non sono dimostrate. Sulla macchina di sviluppo, un Apple M4
(arm64), l'istruzione non esiste.

## Decisione

> **Deciso (autore → ADR-0016)** — Proposta del repository, confermata dall'autore il
> 2026-10-04.

1. **Tre implementazioni dietro l'interfaccia**
   ([`src/optimized/sliders.lisp`](../../src/optimized/sliders.lisp)), tutte compilate e con le
   tavole costruite a ogni caricamento, così che i test le confrontino e `make bench` le misuri:
   - `:fixed-magic`: magic bitboard a spostamento fisso, 12 bit d'indice per ogni casa della
     torre e 9 per ogni casa dell'alfiere; lo spostamento è una costante e l'offset si calcola
     dalla casa. Una tavola di 294912 voci a 64 bit.
   - `:magic`: magic bitboard a spostamento per casa, tanti bit d'indice quante le case
     rilevanti (da 5 a 12); spostamento e offset si leggono per casa. Una tavola di 107648 voci.
   - `:ray`: gli attacchi classici per raggi di ADR-0015, ora in
     [`src/optimized/rays.lisp`](../../src/optimized/rays.lisp). Costruiscono anche le tavole
     magic: ogni voce è il loro valore per un'occupazione.
2. **Scelta al momento della compilazione, senza modificare il codice.** La variabile d'ambiente
   `SCF_SLIDERS` (`fixed-magic`, `magic` o `ray`; non impostata vale `fixed-magic`) si legge
   quando si compila il hot path ([`src/optimized/policy.lisp`](../../src/optimized/policy.lisp),
   `*slider-implementation*`). L'interfaccia è inline e il corpo scelto entra nei chiamanti,
   quindi la scelta non costa nulla a run time. Un altro valore fa fallire il build. Il build,
   `make hot-path` e il registro dell'ambiente di `make bench` stampano l'implementazione usata.
   Ogni target che carica il sistema ricompila ogni sistema di `scacchiforge.asd` che carica
   (`scf-tools:load-strict`, [`tools/load.lisp`](../../tools/load.lisp)), quindi la variabile
   vale per quel target anche dopo un target eseguito con un altro valore o con
   `make test-checked`. Esempi: `SCF_SLIDERS=ray make test`, `SCF_SLIDERS=magic make perft-deep`.
   ASDF non sa con quale valore è stato compilato un file: un caricamento fatto a mano che non
   forza `scacchiforge` e trova il hot path compilato con un altro valore si ferma con un errore
   (`check-compiled-choice`). In un REPL la variabile si imposta prima di avviare SBCL.
3. **Default `:fixed-magic`, scelto dalla misura** descritta in [Valutazione](#valutazione).
   La tecnica ha il suo record di ricerca,
   [EXP-0001](../../research/exp-0001-attacchi-dei-pezzi-a-lunga-gittata.md), che resta In corso
   finché le tappe di INV-X3 che chiedono una ricerca non si possono eseguire: il default precede
   l'accettazione, e lo scostamento da INV-X3 è [QA-17](../limiti-e-rischi.md#qa-17).
4. **Numeri magici del progetto.** Li trova `search-magic-numbers`
   ([`src/optimized/magic.lisp`](../../src/optimized/magic.lisp)), scritta per questo progetto
   dalla descrizione pubblica del metodo (ADR-0013, punto 1):
   - seme `+magic-seed+` = `#x4D61676963686521` (ASCII «Magiche!»), generatore splitmix64 del
     `core`; ogni disposizione (`:magic`, `:fixed-magic`) ha il proprio generatore creato dal
     seme e cerca le case in ordine: torre da a1 a h8, poi alfiere da a1 a h8;
   - un candidato è l'AND di tre estrazioni del generatore, così che circa un bit su otto sia
     acceso;
   - un candidato il cui prodotto con la maschera ha meno di sei bit accesi negli otto più alti
     è scartato senza la prova completa;
   - un candidato è accettato quando, su tutti i 2^n sottoinsiemi delle n case rilevanti, nessuna
     coppia con attacchi diversi ha lo stesso indice.

   Lo strumento [`tools/generate-magics.lisp`](../../tools/generate-magics.lisp) (`make magics`)
   esegue la ricerca e scrive i numeri in
   [`src/optimized/magic-numbers.lisp`](../../src/optimized/magic-numbers.lisp), con il seme e il
   numero di candidati estratti. Il test `committed-magic-numbers-are-the-output-of-the-seeded-search`
   ([`tests/test-optimized.lisp`](../../tests/test-optimized.lisp)) ripete la ricerca e richiede
   gli stessi numeri: il file è l'output di questo strumento, e la ricerca dà gli stessi numeri
   su ogni piattaforma che esegue il test (INV-X6). Nessun numero viene da un altro engine.
5. **Tavola nel repository, ricerca fuori dal caricamento.** La ricerca estrae più di dieci
   milioni di candidati per `:magic`; eseguita a ogni caricamento del sistema la pagherebbero il
   build (che carica due volte), ogni test, ogni benchmark e il REPL. Con i numeri nel repository
   il caricamento costruisce solo le tavole; la ricerca la eseguono `make magics` e il test.
   `make magics` stampa il tempo CPU della ricerca. La ricerca non usa i numeri nel file:
   `make magics` carica il sistema con la feature `:scacchiforge-magic-search`, che salta la
   costruzione delle tavole alla fine di `magic.lisp`, controlla che le tavole siano ancora
   vuote, cerca, scrive il file e ricarica il sistema senza la feature, così che le tavole si
   costruiscano dai numeri appena scritti.
6. **Tavole controllate a ogni caricamento.** La costruzione enumera ogni occupazione rilevante
   di ogni casa e vi scrive l'attacco per raggi. Un numero che non è magico ferma il caricamento
   con un errore, invece di dare un attacco sbagliato (test `a-number-that-is-not-magic-is-refused`).
   L'unico caricamento senza tavole è il primo di `make magics` (punto 5).

**Classificazione:** tavole magic `EXACT`: ogni occupazione rilevante di ogni casa è enumerata
quando le tavole si costruiscono, e il test la confronta con un cammino casa per casa; le case
fuori dalla maschera non cambiano gli attacchi. La ricerca dei numeri: ogni numero restituito è
magico, `EXACT`, perché la prova è completa; lo scarto rapido è `HEURISTIC`, perché può saltare
un candidato magico e cambiare quale numero si trova, mai se è magico. La scelta del default non
riduce lavoro: sceglie fra implementazioni equivalenti, con una misura. Le basi sono nei
docstring di `initialise-magic-tables` e `find-magic-number`
([`src/optimized/magic.lisp`](../../src/optimized/magic.lisp)) e di `magic-bishop-attacks`
([`src/optimized/sliders.lisp`](../../src/optimized/sliders.lisp)).

**Invarianti:** INV-C1 e INV-C4 (stesse mosse e stessi perft con ogni implementazione), INV-A5
(il perft, dopo un riscaldamento, alloca al più 1 MiB su più di un milione di mosse: test
`perft-allocates-nothing-after-warm-up`), INV-A8 e INV-H1 (nessun
codice nativo; tutte e tre le implementazioni sono Common Lisp portabile), INV-X6 (seme dichiarato,
valori attesi fissati), INV-X9 (numeri del progetto).

**Verifica:** suite `optimized`: `slider-attacks-match-a-naive-walk` (l'interfaccia),
`every-slider-implementation-matches-a-naive-walk-on-every-relevant-occupancy` (ogni
implementazione, su ogni sottoinsieme delle case rilevanti di ogni casa, da solo e con bit casuali
fuori dalla maschera), `slider-implementations-agree-on-random-occupancies` (occupazioni casuali
dell'intera scacchiera, quattro densità), `relevant-occupancy-masks-and-magic-table-sizes`,
`committed-magic-numbers-are-the-output-of-the-seeded-search`,
`a-number-that-is-not-magic-is-refused`, `the-slider-implementation-is-chosen-by-name`; perft
(`optimized-perft`, `make perft-deep`) e test differenziale (`differential`,
`make differential-deep`) con il default; `make test` con `SCF_SLIDERS` impostata a ciascuna
implementazione; `make bench` per le misure.

## Conseguenze

- Le tre tavole si costruiscono a ogni caricamento, tranne il primo di `make magics`: 107648 e
  294912 voci a 64 bit per le due disposizioni magic, oltre ai raggi.
- Chi cambia il seme, la ricerca o le disposizioni (maschere o bit d'indice) esegue
  `make magics`; altrimenti il test dei numeri fallisce, o il caricamento si ferma su un numero
  che non è più magico. Lo strumento cerca senza costruire prima le tavole dai numeri nel file
  (punto 5): il file deve solo compilare, come `defparameter` di `*committed-magic-numbers*`,
  qualunque numero contenga. Su una copia dell'albero di lavoro con il primo numero di `:magic`
  sostituito da 1 e l'ultimo di `:fixed-magic` tolto, `make magics` ha riscritto un file
  identico byte per byte a quello del commit 5d25099, mentre lo strumento di 5d25099, sulla
  stessa copia, si fermava con l'errore della costruzione delle tavole. Un cambiamento delle
  disposizioni non è stato provato: la ricerca si ferma solo quando ha trovato un numero magico
  per ogni casa, e non termina se per una casa, con i bit d'indice scelti, un numero magico non
  esiste.
- `make bench` compila il hot path una volta con ciascuna implementazione, in `build/bench/`,
  poi esegue le righe di perft del livello ottimizzato in passate nell'ordine
  `fixed-magic magic ray ray magic fixed-magic`, caricando prima di ogni passata i file
  compilati con la sua implementazione, e alla fine lo ricompila con quella del build. I file
  del hot path sono elencati una volta sola, in `*hot-path-files*`
  ([`src/optimized/policy.lisp`](../../src/optimized/policy.lisp)), che usa anche
  `make hot-path`.
- In un processo l'implementazione è una sola: cambiarla chiede di ricompilare il hot path.
- Il punto 3 di [ADR-0015](0015-generatore-di-mosse-del-livello-ottimizzato.md) rimanda a questo
  ADR.

## Alternative considerate

- *`:magic` come default:* tavola più piccola; sulla macchina misurata più lenta di
  `:fixed-magic` nel microbenchmark degli attacchi e nel perft. Resta, perché una macchina con
  cache diverse può ordinarle in un altro modo.
- *`:ray` come default:* la più semplice da leggere, ed è la baseline di
  [EXP-0001](../../research/exp-0001-attacchi-dei-pezzi-a-lunga-gittata.md); sulla macchina
  misurata la più lenta nel microbenchmark degli attacchi e nel perft. Resta come
  implementazione leggibile e come costruttrice delle tavole. Tenerla come default finché
  EXP-0001 non è accettato è una delle opzioni di [QA-17](../limiti-e-rischi.md#qa-17).
- *PEXT (BMI2):* non raggiungibile da SBCL portabile senza codice nativo, che la specifica
  ammette solo alle cinque condizioni di [ADR-0001](0001-common-lisp-sbcl.md), qui non dimostrate;
  sulla macchina di sviluppo l'istruzione non esiste. Non implementata, e nessun kernel nativo
  aggiunto. Un indice con il PEXT software di `bits.lisp`, che è un ciclo sui bit della maschera,
  non è stato provato.
- *Ricerca dei numeri a ogni caricamento:* nessun file generato, ma il costo della ricerca a ogni
  caricamento del sistema (punto 5).
- *Numeri magici pubblicati da altri engine:* esclusi da ADR-0013, punto 2.
- *Scelta a run time con una variabile letta a ogni chiamata:* costa un salto condizionato per
  attacco nel hot path; esclusa. Una variabile letta solo quando si costruiscono le tavole non
  basta, perché le tre implementazioni non leggono le stesse tavole.

## Valutazione

**Misura su cui poggia il default.** Il comando è `make bench`, con le ripetizioni di default, e
la regola con cui se ne legge l'output è dichiarata in
[EXP-0001](../../research/exp-0001-attacchi-dei-pezzi-a-lunga-gittata.md) (sezione 1): per due
implementazioni, una è più rapida dell'altra solo se in ogni riga i loro intervalli fra minimo e
massimo sono separati, e nel perft anche le mediane di entrambe le passate stanno nello stesso
ordine. Sulla macchina su cui è stato scritto questo ADR (Apple M4, macOS, SBCL 2.6.9),
l'esecuzione confermativa di EXP-0001, fatta su un clone pulito del commit 5d25099 (il registro
dell'ambiente dice «5d25099, working tree clean»), ha dato, secondo quella regola:

- nel microbenchmark degli attacchi (torre e alfiere su coppie casuali di casa e occupazione, con
  seme dichiarato), `:fixed-magic` più rapido di `:magic`, ed entrambi più rapidi di `:ray`.
  Queste righe si eseguono sempre nello stesso ordine, senza passate invertite;
- nel perft del livello ottimizzato, sulle quattro posizioni di `make bench`, lo stesso ordine:
  `:fixed-magic` più rapido di `:magic` e `:magic` più rapido di `:ray`, in ogni posizione e in
  ciascuna delle due passate. Le passate sono nell'ordine
  `fixed-magic magic ray ray magic fixed-magic` e ogni campione dura almeno mezzo secondo di CPU.
  Le differenze sono minori che nel microbenchmark, perché il perft fa molto altro oltre agli
  attacchi; fra `:fixed-magic` e `:magic`, in pos3 e in pos5, gli intervalli sono separati di
  poco.

Il carico medio, sotto 3 all'avvio, alla fine dell'esecuzione era salito sopra 16 (su 10 CPU
logiche) per altri processi della macchina: la regola non ne tiene conto, ed è scritto in
EXP-0001 (sezione 10).

Le cifre non si copiano qui ([QA-14](../limiti-e-rischi.md#qa-14)): `make bench` le riproduce,
con il registro dell'ambiente.

La prima stesura di questo ADR citava invece due esecuzioni di `make bench` con
`SCF_BENCH_REPETITIONS=11`, una con l'ordine delle implementazioni invertito. Venivano da una
versione precedente, mai committata, del benchmark e del default; nessun comando del repository
le ripete, e non sono evidenza (EXP-0001, sezione 10).

**Che cosa la misura non dice.** È la misura di una macchina in un momento. x86-64 non è stato
misurato: non in locale, e la CI esegue `make check`, non `make bench`. Sul commit 5d25099 la CI
ha mostrato su x86-64 la correttezza, non il tempo: le tre implementazioni danno gli stessi
attacchi di un cammino casa per casa su ogni occupazione rilevante, e il perft compilato con
`:fixed-magic`, il default, dà i valori attesi ([QA-12](../limiti-e-rischi.md#qa-12)). Su una
macchina con meno cache la tavola più grande di `:fixed-magic` può costare di più. Sono stati
misurati solo il microbenchmark degli attacchi e il perft, che è anch'esso un microbenchmark,
composto, di generazione, filtro di legalità e make/unmake
([misure](../misure.md#due-livelli-di-benchmark)): un benchmark di engine non esiste, perché non
esiste ancora una ricerca del livello ottimizzato.
Per la stessa ragione le tappe di INV-X3 che seguono (benchmark di engine, self-play,
validazione statistica) non sono state eseguite, e EXP-0001 resta In corso. Le tre
implementazioni calcolano gli stessi attacchi, quindi la forza a parità di nodi non cambia;
cambia il tempo per nodo, e con esso la forza per CPU-secondo, che si misurerà quando la ricerca
esisterà. Il default è quindi in uso prima che la tecnica sia accettata: lo scostamento da
INV-X3 è [QA-17](../limiti-e-rischi.md#qa-17).

**Porterebbe a rivedere la decisione:** `make bench` su un'altra macchina o un'altra versione di
SBCL, in particolare su x86-64, che ordini le implementazioni diversamente nel perft; una ricerca
il cui uso degli attacchi cambi il confronto; la chiusura di EXP-0001 o di QA-17; un kernel PEXT
ammesso alle cinque condizioni di [ADR-0001](0001-common-lisp-sbcl.md), con fallback portabile e
test di equivalenza.
