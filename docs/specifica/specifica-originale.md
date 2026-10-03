# Specifica originale

Testo del committente, riportato senza modifiche. È la prima fonte di verità del progetto:
non si modifica senza un ADR che dichiari l'emendamento.

---

Sì. Lo rifarei completamente: non più “lista di ottimizzazioni”, ma una specifica per un laboratorio di ricerca di chess engine ad alte prestazioni, con correttezza matematica, ricerca aggressiva, deduplicazione e ottimizzazione hardware come principi fondanti.
Progetta e implementa da zero un chess engine originale in Common Lisp/SBCL, senza utilizzare Stockfish, codice derivato da Stockfish o implementazioni proprietarie di altri engine.
L'obiettivo non è semplicemente creare un engine forte, ma costruire una piattaforma di ricerca per chess search, evaluation e computational optimization, orientata a massimizzare la forza scacchistica ottenuta per unità di CPU-time.
Il progetto deve essere matematicamente rigoroso, sperimentalmente misurabile, multipiattaforma e ottimizzato fin dalle prime decisioni architetturali.
PRINCIPIO FONDAMENTALE
Ogni riduzione del lavoro computazionale deve essere classificata come almeno una delle seguenti:
[THEOREM]
Correttezza dimostrabile.
[EXACT]
Algoritmo esatto senza perdita di correttezza.
[BOUNDED]
Produce bound matematicamente interpretabili.
[PROBABILISTIC]
Correttezza pratica basata su proprietà probabilistiche esplicite.
[HEURISTIC]
Euristica senza garanzia generale.
[EMPIRICAL]
Validata sperimentalmente.
[LEARNED]
Parametri o funzioni ottenuti tramite training.
Non confondere mai un'euristica efficace con un teorema.
OBIETTIVO MATEMATICO
Modellare gli scacchi come problema di ricerca su un grafo di stati.
L'obiettivo è ottenere una buona approssimazione computazionale del valore minimax:
V(s) = max/min V(s')
utilizzando la minor quantità possibile di lavoro.
Ottimizzare quindi:
max Strength / CPU-time
e secondariamente:
min Nodes / decision
min CPU-ms / solved position
max Depth / fixed time
NPS non deve essere considerato il principale indicatore di qualità.
ARCHITETTURA GENERALE
Separare rigorosamente:

1. Reference implementation
2. Optimized engine
3. Experimental research layer
4. Hardware-specific backends
5. Benchmark infrastructure
6. Training infrastructure
7. Test infrastructure

Struttura concettuale:
engine/
reference/
core/
search/
evaluation/
nnue/
transposition/
movegen/
cpu/
simd/
platform/
benchmarks/
tests/
research/
training/
REFERENCE ENGINE
Creare una implementazione di riferimento volutamente semplice e leggibile.
La reference implementation deve fungere da oracle per:

* legal move generation
* make/unmake
* state transitions
* Zobrist state
* evaluation
* NNUE feature updates
* search results dove applicabile

L'implementazione ottimizzata deve essere continuamente confrontabile con la reference implementation.
Generare milioni di posizioni random e confrontare:
optimized(position) == reference(position)
L'ottimizzazione non deve mai rendere impossibile la verifica della correttezza.
BOARD REPRESENTATION
Utilizzare bitboard 64-bit.
Separare chiaramente:

* piece bitboards
* color occupancy
* total occupancy
* side to move
* castling rights
* en passant
* halfmove clock
* incremental state
* Zobrist key

Usare make/unmake.
Evitare copie complete di Position durante la ricerca.
Usare stack preallocati per lo stato precedente.
MOVE REPRESENTATION
Rappresentare Move come valore packed.
Non allocare oggetti Lisp per ogni mossa.
Preallocare move buffers.
Separare:

* pseudo-legal generation
* legal move filtering
* ordering
* execution

MOVE GENERATION
Implementare:

* pawn moves
* captures
* promotions
* en passant
* castling
* knights
* bishops
* rooks
* queens
* kings

Gestire correttamente:

* pins
* discovered checks
* double checks
* pinned en-passant
* castling attack constraints
* promotion legality

Ottimizzare successivamente tramite:

* precomputed attack tables
* magic bitboards dove vantaggioso
* PEXT/BMI2 dove vantaggioso
* lookup tables
* bit tricks
* POPCNT

Ogni alternativa deve essere benchmarkata.
PERFT
Perft è un gate obbligatorio.
Prima di introdurre search aggressiva:

* tutte le posizioni Perft devono passare;
* testare castling;
* en passant;
* promotion;
* pins;
* checks;
* discovered checks;
* edge cases.

Creare inoltre un fuzzer di posizioni legali.
SEARCH FOUNDATION
Implementare come baseline:

* Minimax
* Negamax
* Alpha-Beta
* Iterative Deepening

Successivamente implementare e confrontare:

* Principal Variation Search
* NegaScout
* null-window search
* MTD(f)
* Transposition-driven search
* SSS*
* DUAL*

Non assumere a priori che un algoritmo sia universalmente migliore.
Costruire benchmark scientifici per confrontare:

* nodes
* time
* depth
* TT hit rate
* cutoff rate
* strength
* stability

SEARCH TREE CLASSIFICATION
Classificare esplicitamente i nodi come:

* PV nodes
* Cut nodes
* All nodes

Usare questa informazione per modulare:

* pruning
* reductions
* extensions
* move ordering
* search window

SEARCH REDUCTIONS AND PRUNING
Implementare progressivamente:

* Null Move Pruning
* Futility Pruning
* Reverse Futility
* Razoring
* Late Move Reductions
* ProbCut
* Singular Extensions
* Check Extensions
* Quiescence Search

Ogni tecnica deve essere marcata come HEURISTIC se non è matematicamente garantita.
Non utilizzare soglie arbitrarie senza benchmark.
LMR
Non implementare LMR come semplice:
if move_index > N then reduction = R
Progettare invece:
R = f(depth, move_index, node_type, history, TT information, tactical volatility, evaluation, previous search)
e studiare sperimentalmente la funzione.
L'obiettivo è creare una politica adattiva di ricerca.
NULL MOVE
Implementare versioni progressive:

* basic null move
* verification search
* zugzwang detection
* adaptive reduction

Testare esplicitamente gli zugzwang e le posizioni in cui il null move è pericoloso.
QUIESCENCE
Implementare quiescence search con:

* captures
* promotions
* checks quando giustificato
* SEE
* delta pruning quando validato

Ridurre il rischio di horizon effect.
MOVE ORDERING
Implementare progressivamente:

1. TT move
2. PV move
3. winning captures
4. promotions
5. killer moves
6. history heuristic
7. countermove
8. continuation history
9. SEE
10. tactical ordering

Misurare separatamente l'efficienza del move ordering.
TRANSPOSITION TABLE
La TT deve essere progettata come struttura di memoization ad alte prestazioni.
Usare:

* Zobrist hash
* compact entries
* depth
* score
* bound type
* best move
* generation
* replacement policy

Supportare:

* EXACT
* LOWERBOUND
* UPPERBOUND

La collisione o perdita di una entry non deve mai compromettere la correttezza.
La TT deve essere considerata parte del modello di ricerca su grafo:
game tree → game graph
Ottimizzare:

* hit rate
* cache locality
* memory footprint
* replacement quality
* contention

Testare diverse dimensioni e replacement policies.
Non assumere che più memoria significhi automaticamente più performance.
DEDUPLICATION
Trattare la deduplicazione come principio architetturale.
Distinguere esplicitamente:
Memoization:

* TT

Incremental computation:

* Zobrist
* material
* pawn state
* NNUE accumulator
* altri dati incrementali

Precomputation:

* attack tables
* magic/PEXT tables
* evaluation tables

Reuse:

* hash move
* PV
* killer
* history
* continuation history

Compression:

* packed Move
* compact TTEntry
* compact feature representation

Cache locality:

* contiguous arrays
* compact structs
* predictable memory access

Regola:
Non effettuare una lookup/cache operation se il costo della deduplicazione supera il costo del calcolo.
Misurare sempre hit rate e costo del lookup.
EVALUATION
Creare inizialmente una evaluation classica:

* material
* piece-square tables
* mobility
* king safety
* pawn structure
* passed pawns
* space
* initiative
* threats

Utilizzare rappresentazioni incrementali dove conveniente.
Successivamente introdurre NNUE.
NNUE
Implementare una rete NNUE originale.
Separare:

* feature extraction
* sparse representation
* accumulator
* incremental update
* inference
* training

La rete deve essere aggiornata incrementalmente.
Una mossa deve modificare soltanto le feature necessarie.
Supportare progressivamente:

* scalar reference
* AVX2
* AVX-512
* VNNI
* ARM NEON
* SVE/SVE2

Non assumere che AVX-512 sia sempre più veloce di AVX2.
Benchmarkare:

* inference
* accumulator update
* memory bandwidth
* latency
* throughput
* CPU frequency effects

SEARCH + EVALUATION
Trattare la search policy e l'evaluation come sistemi accoppiati.
Definire:
Eθ(s)
per la evaluation e parametri:
θsearch
per:

* LMR
* Null Move
* aspiration
* pruning
* extensions
* move ordering
* futility
* ProbCut

Ottimizzare concettualmente:
θ* = argmax Strength(θ)
sotto il vincolo:
CPU-time ≤ T
Studiare quindi non solo il training della NNUE, ma anche il tuning automatico della search.
PARAMETER OPTIMIZATION
Supportare:

* grid search
* coordinate descent
* SPSA
* Texel tuning
* Bayesian optimization quando appropriata
* self-play optimization
* automated regression

Ogni parametro importante deve poter essere modificato senza cambiare il codice.
EXPERIMENTAL SEARCH
Creare un laboratorio separato per:

* alternative pruning
* adaptive LMR
* learned move ordering
* learned reductions
* learned extensions
* adaptive aspiration windows
* alternative TT policies
* alternative evaluation
* alternative search algorithms

Ogni esperimento deve essere:

* riproducibile
* configurabile
* confrontabile con baseline
* misurabile
* reversibile

MULTI-THREAD
Prima single-thread.
Poi:

* thread-local search state
* thread-local stacks
* parallel search
* Lazy SMP
* shared/opportunistic TT

Evitare lock globali nel critical path.
Studiare:

* scaling
* contention
* cache coherence
* false sharing
* memory bandwidth

NUMA
Preparare l'architettura per sistemi multi-socket.
Preferire, quando conveniente:

* local TT
* local search state
* local worker memory
* read-only replicated data

piuttosto che strutture globali altamente contese.
CPU OPTIMIZATION
Implementare runtime CPU feature detection.
x86:

* POPCNT
* BMI2
* PEXT
* AVX2
* AVX-512
* VNNI

ARM:

* NEON
* SVE
* SVE2

Mantenere sempre un generic fallback.
Il dispatch CPU deve essere isolato dal resto dell'engine.
Priorità:

1. algoritmo
2. data layout
3. cache locality
4. memory traffic
5. branch behavior
6. SIMD
7. micro-ottimizzazioni

Non usare SIMD per accelerare un algoritmo o data layout sbagliato.
COMMON LISP / SBCL
Utilizzare SBCL come implementazione primaria.
Mantenere il GC.
GC libero in:

* server
* tooling
* configuration
* logging
* orchestration
* tests

Search hot path:

* near-zero allocation
* preallocated stacks
* preallocated move buffers
* typed arrays
* compact structs
* evitare boxing quando possibile
* evitare consing
* evitare closure allocation
* verificare il comportamento reale tramite profiling e disassembly

Non trasformare Common Lisp in una caricatura di C.
Usare il linguaggio dove aumenta sicurezza e produttività e specializzare soltanto i kernel realmente critici.
NATIVE MICROKERNELS
Consentire FFI/native kernels esclusivamente quando:

* il profiling dimostra un hot spot;
* SBCL non produce codice adeguato;
* il kernel è isolabile;
* esiste un fallback portabile;
* esiste un test di equivalenza.

Il core dell'engine deve rimanere Common Lisp.
PERFORMANCE INFRASTRUCTURE
Creare due livelli di benchmark.
MICROBENCHMARK:

* POPCNT
* PEXT
* move generation
* make/unmake
* Zobrist
* TT lookup
* NNUE accumulator
* NNUE inference
* SIMD kernels
* memory access

ENGINE BENCHMARK:

* NPS
* depth/time
* TT hit rate
* cutoff rate
* branching factor
* QNodes
* evaluation cost
* allocation
* GC
* RSS
* CPU utilization
* strength

Ogni commit significativo deve poter essere confrontato con un baseline.
PERFORMANCE GATES
Una modifica deve essere valutata almeno su:

* correctness
* speed
* memory
* allocation
* strength

Registrare esplicitamente regressioni e miglioramenti.
METRICHE PRINCIPALI
Non usare NPS come unica metrica.
Priorità:

1. Elo / CPU-second
2. strength at fixed time
3. nodes / solved tactical position
4. CPU-ms / decision
5. depth / fixed time
6. NPS

SELF-PLAY
Creare infrastruttura per:

* engine vs engine
* version vs version
* parameter A vs parameter B
* fixed-time matches
* fixed-node matches
* randomized openings
* reproducible seeds

Usare statistiche appropriate per valutare differenze di forza.
Non dichiarare un miglioramento sulla base di una singola partita o benchmark.
POSITION CORPUS
Creare un corpus diversificato di posizioni:

* opening
* middlegame
* endgame
* tactical
* quiet
* king attacks
* pawn structures
* promotions
* en passant
* castling
* rare legal states

Usarlo per:

* regression
* profiling
* NNUE training
* tuning
* search experiments

TESTING
Implementare:

* unit tests
* Perft
* randomized legal-position testing
* differential testing reference vs optimized
* search regression
* NNUE regression
* cross-platform regression
* fuzzing
* benchmark regression

CROSS-PLATFORM
Target:

* Debian/Linux x86-64
* FreeBSD x86-64
* macOS Intel
* macOS Apple Silicon
* predisposizione ARM64 Linux/FreeBSD

Il comportamento logico deve essere identico.
Le differenze hardware devono riguardare soltanto i backend ottimizzati.
SERVER ARCHITECTURE
Il server deve essere separato logicamente dall'engine:
Browser/WebSocket
↓
Game Actor
↓
Bot Scheduler
↓
Engine Worker Pool
↓
Chess Engine
Il Game Actor non deve bloccare durante la ricerca del bot.
La prima versione deve essere single-node/cloud-ready.
Preparare l'architettura per:

* horizontal scaling
* partitioning per game
* actor ownership
* failure isolation
* backpressure
* idempotency
* observability

senza introdurre prematuramente database/distributed systems nel critical path dell'engine.
RESEARCH METHODOLOGY
Ogni nuova tecnica deve seguire:
Hypothesis
↓
Mathematical rationale
↓
Implementation
↓
Microbenchmark
↓
Engine benchmark
↓
Self-play
↓
Statistical validation
↓
Accept / Reject
Mai accettare una tecnica soltanto perché "sembra più veloce".
ROADMAP
Phase 0:
Repository, build system, tests, benchmark framework, reference model.
Phase 1:
Bitboards, Position, Move, legal move generation, make/unmake, Perft.
Phase 2:
Negamax, Alpha-Beta, iterative deepening, classical evaluation.
Phase 3:
Zobrist, TT, PVS/NegaScout, move ordering.
Phase 4:
Quiescence, SEE, killer/history/countermove, aspiration.
Phase 5:
Null Move, LMR, Futility, Razoring, ProbCut, Singular Extensions.
Phase 6:
Alternative searches:
MTD(f), SSS*, DUAL*, transposition-driven search.
Phase 7:
Aggressive profiling, cache optimization, CPU dispatch, SIMD.
Phase 8:
NNUE + incremental accumulator.
Phase 9:
AVX2, VNNI, AVX-512, NEON, SVE/SVE2.
Phase 10:
Automated tuning, self-play, parameter optimization.
Phase 11:
Parallel search, Lazy SMP, NUMA-aware architecture.
Phase 12:
Experimental learned search policies and adaptive pruning.
PHILOSOPHY
Non ottimizzare semplicemente il numero di operazioni al secondo.
Ottimizzare il numero di operazioni necessarie per ottenere una decisione forte.
Non aumentare semplicemente NPS.
Ridurre il lavoro.
Non usare semplicemente più memoria.
Riutilizzare intelligentemente il lavoro già effettuato.
Non usare semplicemente SIMD.
Ridurre prima il problema e poi accelerare il kernel residuo.
Non usare semplicemente più profondità.
Spendere la profondità dove ha maggiore valore informativo.
Non trattare le euristiche come teoremi.
Misurare e classificare ogni tecnica.
Obiettivo finale:
Costruire un chess engine originale, matematicamente rigoroso, estremamente efficiente, multipiattaforma e capace di diventare una piattaforma di ricerca su minimax, alpha-beta search, transposition-driven search, pruning, learned evaluation e adaptive search.
Il criterio ultimo di successo è:
max Strength / CPU-time
con correttezza verificabile, benchmark riproducibili e un'architettura capace di evolvere oltre le tecniche attualmente implementate.
Questa versione cambia sostanzialmente il progetto: non stiamo più progettando “un engine con tante ottimizzazioni”; stiamo progettando un sistema sperimentale nel quale possiamo mettere in competizione algoritmi matematici, euristiche e modelli learned, misurando esattamente quanto lavoro eliminano e quanto valore producono.
La prima milestone concreta dovrebbe quindi essere molto disciplinata: reference chess model → bitboard optimized model → Perft/fuzz differential testing → benchmark harness. Solo quando quella base è inattaccabile iniziamo a scatenare Alpha-Beta/PVS/TT e tutto il resto.
