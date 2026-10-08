# Limiti e rischi

> **Fonte:** «COMMON LISP / SBCL», «NATIVE MICROKERNELS», «CPU OPTIMIZATION»,
> «TRANSPOSITION TABLE», «MULTI-THREAD» e «CROSS-PLATFORM» della
> [specifica](specifica/specifica-originale.md).

Questo documento dice che cosa il progetto non sa, non fa o non può dire. Tre parti: i limiti
dichiarati, i rischi (`RSK-nn`) e le questioni aperte (`QA-nn`).

Regola: di SBCL e dell'hardware non si afferma ciò che non è stato controllato. Ciò che non lo è
resta una questione aperta, con l'esperimento o la decisione (ADR) che la chiude.

## Limiti dichiarati

- **Nessuna affermazione di forza.** L'obiettivo è `max Strength / CPU-time`; è un obiettivo, non
  un risultato.
- **Nessuna cifra di prestazione** che non venga da un comando eseguito (INV-X2).
- **Le classificazioni sono proposte** finché un ADR non le decide ([classificazione](classificazione.md)).
- **Il `core` condiviso non è giudicato dal confronto differenziale** (INV-A3). Se una definizione
  condivisa è sbagliata, lo è per tutti i livelli. Per questo contiene solo definizioni.
- **Le piattaforme target non sono tutte raggiungibili**, né dall'ambiente di sviluppo né dalla
  CI ([QA-12](#qa-12)).
- **Il riferimento è semplice, non veloce.** Un perft profondo sul riferimento può essere lento: è
  il prezzo dell'oracolo.

## Osservazioni su SBCL

Controllate nell'installazione usata per scrivere questi documenti: SBCL 2.6.9, macOS, ARM64. Sono
osservazioni di una macchina, non garanzie. I comandi permettono di ripeterle.

| Osservazione | Comando |
|---|---|
| `most-positive-fixnum` vale 4611686018427387903, cioè 2^62 − 1. Un intero a 64 bit con il bit alto acceso non è un fixnum. | `sbcl --noinform --non-interactive --eval '(print most-positive-fixnum)'` |
| `sb-ext:get-bytes-consed`, `sb-ext:*gc-run-time*` e `get-internal-run-time` esistono; `internal-time-units-per-second` vale 1000000. | `sbcl --noinform --non-interactive --eval '(print (list (fboundp (quote sb-ext:get-bytes-consed)) (boundp (quote sb-ext:*gc-run-time*)) internal-time-units-per-second))'` |
| `get-internal-run-time` conta il tempo CPU dell'intero processo, non del solo thread: mentre il thread principale dorme 1 s e un altro thread gira a vuoto, cresce di circa 1 s. Il comando stampa la crescita, in secondi. | `sbcl --noinform --non-interactive --eval '(let* ((stop nil) (th (sb-thread:make-thread (lambda () (loop until stop)))) (start (get-internal-run-time))) (sleep 1) (print (/ (- (get-internal-run-time) start) internal-time-units-per-second 1.0)) (setf stop t) (sb-thread:join-thread th))'` |
| Il contrib `sb-simd` è presente tra i contrib installati: il comando stampa il percorso del suo file `.asd`. | `sbcl --noinform --non-interactive --eval '(print (probe-file (merge-pathnames "contrib/sb-simd.asd" (sb-int:sbcl-homedir-pathname))))'` |
| `(require :sb-simd)` si carica e definisce i package `SB-SIMD` e `SB-SIMD-NEON`, non `SB-SIMD-AVX2` né `SB-SIMD-SSE`. Che le sue operazioni producano istruzioni NEON non è stato verificato. | `sbcl --noinform --non-interactive --eval '(require :sb-simd)' --eval '(print (mapcar (function find-package) (list "SB-SIMD" "SB-SIMD-NEON" "SB-SIMD-AVX2" "SB-SIMD-SSE")))'` |
| Nessun simbolo il cui nome contiene `PEXT` o `PDEP`: SBCL non espone le due istruzioni BMI2 (che su arm64 non esistono). Il comando stampa `(NIL NIL)`. | `sbcl --noinform --non-interactive --eval '(print (list (apropos-list "PEXT") (apropos-list "PDEP")))'` |

## Rischi

> **Proposta** — Per ogni rischio, la mitigazione proposta e la questione che lo misura.

| ID | Rischio | Mitigazione | Questione |
|---|---|---|---|
| RSK-01 | Valori a 64 bit allocati (boxing) nel hot path | rappresentazione scelta con una misura, non per abitudine; allocazione misurata (INV-A5) | [QA-03](#qa-03) |
| RSK-02 | Pause del GC durante una ricerca a tempo | nessuna allocazione nel hot path; misura di GC e RSS | [QA-05](#qa-05) |
| RSK-03 | POPCNT, BMI2/PEXT, SIMD non raggiungibili da SBCL, o diversi per piattaforma | fallback generico sempre presente (INV-H1); scelta del backend con una misura | [QA-04](#qa-04) |
| RSK-04 | Collisioni della TT e interazione con la storia: valori sbagliati | modalità di verifica; mossa TT controllata (INV-C6); classificazione onesta | [QA-01](#qa-01), [QA-02](#qa-02) |
| RSK-05 | Il riferimento è sbagliato nello stesso modo dell'ottimizzato | valori pubblicati di perft come oracolo esterno; casi con risultato noto; nessun algoritmo nel `core` | — |
| RSK-06 | Etichette assegnate con ottimismo | regola «nel dubbio la più debole»; promozione solo con evidenza | — |
| RSK-07 | Miglioramenti falsi da misure rumorose o da confronti multipli | test statistico dichiarato prima, conferma indipendente, registro dell'ambiente | [QA-08](#qa-08), [QA-09](#qa-09) |
| RSK-08 | Potenza statistica limitata: un guadagno di pochi Elo richiede molte partite | dichiarare «non distinguibile»; non confondere assenza di prova con assenza di effetto | — |
| RSK-09 | Piattaforme e hardware non raggiungibili | nessuna affermazione su ciò che non è stato eseguito | [QA-12](#qa-12) |
| RSK-10 | Non determinismo della ricerca parallela: bug non riproducibili | modalità a un thread deterministica; test di stress; validazione statistica | [QA-07](#qa-07) |
| RSK-11 | Costruire la piattaforma prima che la base sia solida | gate di fase; nessuna ricerca aggressiva prima del gate di perft (INV-X8); il gate della Fase 1 precede la ricerca dell'engine ottimizzato, mentre il riferimento può avere ricerca semplice come oracolo (lettura di [ADR-0012](adr/0012-lettura-del-gate-di-perft.md)) | [QA-10](#qa-10) |
| RSK-12 | Sovradattamento al corpus di posizioni | insiemi separati per tuning e valutazione; corpus versionato | — |
| RSK-13 | Prestazioni dipendenti da frequenza, temperatura e carico | registro dell'ambiente; ripetizioni; dispersione riportata | [QA-09](#qa-09) |
| RSK-14 | La documentazione invecchia | aggiornamento nello stesso commit (INV-X12); `make links` | — |

## Microkernel nativi

La specifica consente FFI e kernel nativi esclusivamente quando valgono tutte e cinque le
condizioni:

1. il profiling dimostra un hot spot;
2. SBCL non produce codice adeguato;
3. il kernel è isolabile;
4. esiste un fallback portabile;
5. esiste un test di equivalenza.

Il core dell'engine deve rimanere Common Lisp ([ADR-0001](adr/0001-common-lisp-sbcl.md)). Nessun
microkernel è previsto oggi. La questione di conciliarli con «SBCL unica toolchain» è
[QA-06](#qa-06).

## Questioni aperte

Ogni questione dice che cosa non si sa e quale esperimento, o quale decisione, la chiude. Si
chiude con un ADR; la voce resta, marcata «Risolta da ADR-nnnn». L'esperimento, dove c'è, si
registra come [record di ricerca](../research/README.md).

| ID | Questione | Incide su |
|---|---|---|
| [QA-01](#qa-01) | Collisioni della TT e «non deve mai compromettere la correttezza» | INV-C5, INV-C6 |
| [QA-02](#qa-02) | Ripetizioni e interazione tra grafo e storia | TT, Fase 3 |
| [QA-03](#qa-03) | Boxing e rappresentazione dei valori a 64 bit | INV-A5, Fase 1 |
| [QA-04](#qa-04) | POPCNT, bit scan, PEXT e SIMD in SBCL, per piattaforma | Fasi 7 e 9 |
| [QA-05](#qa-05) | GC e memoria della TT | Fasi 3 e 7 |
| [QA-06](#qa-06) | Kernel nativi e SBCL come unica toolchain | INV-A8 |
| [QA-07](#qa-07) | Integrità delle entry della TT in concorrenza | Fase 11 |
| [QA-08](#qa-08) | Definizione operativa di «Elo per CPU-secondo» | [misure](misure.md) |
| [QA-09](#qa-09) | Misura del tempo CPU in SBCL | [misure](misure.md) |
| [QA-10](#qa-10) | Confine tra Fase 0 e Fase 1 | [roadmap](roadmap.md) |
| [QA-11](#qa-11) | Elementi della specifica senza fase | [roadmap](roadmap.md) |
| [QA-12](#qa-12) | Piattaforme non raggiungibili, né dall'ambiente di sviluppo né dalla CI | INV-H5 |
| [QA-13](#qa-13) | Significato di «transposition-driven search» | Fasi 6 e 11 |
| [QA-14](#qa-14) | Dove vivono le baseline | [misure](misure.md) |
| [QA-15](#qa-15) | Aritmetica della NNUE tra backend | INV-H3, Fase 8 |
| [QA-16](#qa-16) | Distribuzione delle posizioni del fuzzer | [verifica](verifica.md) |
| [QA-17](#qa-17) | Percorso di ricerca per le alternative con le stesse uscite. Risolta da [ADR-0017](adr/0017-percorso-di-ricerca-per-le-alternative-exact.md) | INV-X3, Fase 1 |
| [QA-18](#qa-18) | Pesi della struttura pedonale uguali alle costanti di Fruit 2.1. Risolta dall'autore: pesi fissati da una regola ([valutazione](valutazione.md#struttura-pedonale), [ADR-0018](adr/0018-definizione-della-valutazione-classica.md)) | INV-X9, [ADR-0013](adr/0013-interpretazione-operativa-dell-originalita.md), [ADR-0018](adr/0018-definizione-della-valutazione-classica.md), Fase 2 |
| [QA-19](#qa-19) | Parametri della valutazione nel codice, contro INV-X7. Risolta da [ADR-0020](adr/0020-parametri-della-valutazione-dalla-fase-10.md) | INV-X7, [ADR-0019](adr/0019-valutazione-e-ricerca-del-livello-ottimizzato.md), Fasi 2 e 10 |

### QA-01

**Collisioni della TT.** La specifica vuole che la collisione o la perdita di una entry non
comprometta mai la correttezza. La perdita non cambia il valore sotto TT-1, TT-2 e TT-4
([classificazione](classificazione.md#ipotesi-della-transposition-table)); con la storia nel
valore ([QA-02](#qa-02)) può cambiarlo. Una collisione, cioè un falso riscontro, può restituire il
valore di un'altra posizione, e con chiavi a 64 bit non si può escludere: si può renderla
improbabile e innocua.

- *Opzioni:* confrontare più bit di chiave; controllare la legalità della mossa TT (INV-C6); in
  modalità di verifica, conservare un controllo indipendente.
- *Esperimento:* in modalità di verifica, contare i falsi riscontri su molte ricerche al variare
  dei bit confrontati; forzare un falso riscontro e controllare che non produca mosse illegali né
  errori.

> **Proposta ([ADR-0021](adr/0021-transposition-table-del-livello-ottimizzato.md))** — Il
> default che la TT del livello ottimizzato applica: la chiave intera di 64 bit confrontata a
> ogni sonda; la mossa TT usata solo se è fra le mosse legali del nodo, e scartata e contata
> altrimenti; in modalità di verifica un controllo indipendente della posizione in ogni slot, con
> i falsi riscontri scartati e contati. I test della suite `optimized-tt` forzano falsi riscontri
> con una maschera di chiave di 8 e 4 bit: in modalità di verifica sono scartati e contati e il
> valore non cambia; in modalità normale le mosse di altre posizioni si scartano, e nessuna
> ricerca finisce in errore né esegue una mossa illegale. La questione resta aperta: la decide
> l'autore.

### QA-02

**Ripetizioni e interazione tra grafo e storia (GHI).** Una posizione ripetuta vale patta, ma la
TT identifica la posizione, non il percorso: un valore memorizzato su un percorso può essere letto
da un altro. La specifica parla di «game graph» ma non dice come si tratta la storia.

- *Opzioni:* non memorizzare né usare valori che dipendono dalla storia; controllare le ripetizioni
  prima della sonda; accettare l'errore e classificare `HEURISTIC`.
- *Esperimento:* una suite di posizioni il cui valore dipende da una ripetizione; confrontare la
  ricerca con TT, senza TT e con ciascuna opzione; misurare in self-play la frequenza dell'errore.

> **Proposta ([ADR-0021](adr/0021-transposition-table-del-livello-ottimizzato.md))** — Il
> default di oggi: la ricerca non rileva ripetizioni né la regola delle cinquanta mosse, quindi
> nessun valore memorizzato dipende dal percorso e TT-2 vale; gli orologi stanno fuori dalla
> chiave; la TT non memorizza punteggi che dipendono dalla storia. Il test
> `one-position-by-two-paths-has-one-key-and-one-value` lo mostra su una posizione raggiunta per
> due percorsi. La questione resta aperta per quando la ricerca rileverà le ripetizioni.

### QA-03

**Boxing e rappresentazione dei valori a 64 bit.** Un bitboard è un intero a 64 bit senza segno e
non sempre entra in un fixnum (vedi sopra).

Oggi è misurato il hot path del livello ottimizzato, su SBCL 2.6.9, macOS arm64 (Apple M4). Il
perft, dopo un riscaldamento, fa e disfa più di un milione di mosse e alloca 0 byte: lo stampano
il test `perft-allocates-nothing-after-warm-up` di `make check`, che richiede al più 1 MiB, e la
parte 3 di `make hot-path`, con il passo con cui `sb-ext:get-bytes-consed` conta. La parte 2
elenca le chiamate e le allocazioni che il disassemblato di ogni funzione eseguita a ogni nodo
nomina. Le copie fuori linea delle funzioni inline che restituiscono un intero di 64 bit lo
restituiscono in forma boxed, come dicono le note di efficienza della parte 1; nel hot path
quelle funzioni sono espanse
([ADR-0014](adr/0014-policy-di-compilazione-del-livello-ottimizzato.md), Conseguenze).

Nella CI su 5d25099 (run 37180782566, [QA-12](#qa-12)) lo stesso test ha stampato 0 byte anche
su x86-64 con SBCL 2.2.9 e su arm64 con SBCL 2.6.8, e così su c15291e (run 37183294754) e su
0408743 (run 37193831706). Su cc6fceb (run 37198250566) e su b3190dc (run 37215795264), sulle
stesse due immagini, hanno stampato 0 byte anche i test di allocazione della valutazione e della
ricerca del livello ottimizzato (`evaluation-allocates-nothing-after-warm-up`,
`search-allocates-nothing-after-warm-up`).

Resta aperto: le altre piattaforme e versioni di SBCL, compresa la 2.2.9 della CI su x86-64, dove
`make hot-path` (note, disassemblato) non è stato eseguito; il livello di riferimento, che non è
misurato; il confronto fra rappresentazioni alternative, che non è stato fatto.

- *Esperimento:* `make hot-path` su ogni piattaforma; per ogni rappresentazione candidata
  (variabili locali tipizzate, funzioni inline, array `(unsigned-byte 64)`, slot tipizzati di
  struct) un microbenchmark con `sb-ext:get-bytes-consed` e l'ispezione di `disassemble`.

### QA-04

**POPCNT, bit scan, PEXT e SIMD in SBCL.** Quali istruzioni SBCL emetta per `logcount`, per la
ricerca del bit più basso e per l'aritmetica a 64 bit su ciascuna piattaforma; se PEXT sia
raggiungibile senza FFI; se `sb-simd` sia utilizzabile su ciascuna architettura. Su macOS ARM64 il
contrib si carica e definisce un package NEON, e SBCL non espone simboli di nome PEXT o PDEP
(vedi sopra); su x86-64 nessuna delle due cose è stata verificata, e nient'altro di questo è stato
verificato. Per ora gli attacchi dei pezzi a lunga gittata usano magic bitboard in Common Lisp
portabile, senza PEXT ([ADR-0016](adr/0016-attacchi-dei-pezzi-a-lunga-gittata.md)). Non si
assume che PEXT sia veloce su ogni microarchitettura: va misurata su ogni macchina.

- *Esperimento:* per piattaforma, `disassemble` di funzioni minime; confronto in microbenchmark con
  le alternative portabili (tabelle, bit tricks); prova di caricamento del contrib.

### QA-05

**GC e memoria della TT.** Dimensione massima dello heap e sua impostazione all'avvio; costo di
tenere grandi array tipizzati per la TT; pause del GC durante una ricerca a tempo, perché una
pausa consuma il tempo della mossa.

- *Esperimento:* allocare TT di varie dimensioni; eseguire ricerche; registrare
  `sb-ext:*gc-run-time*`, byte allocati e RSS; controllare se un GC avviene durante una ricerca.

Oggi la TT del livello ottimizzato si alloca una volta, in vettori tipizzati, e la sonda e
l'inserimento non allocano ([ADR-0021](adr/0021-transposition-table-del-livello-ottimizzato.md)).
Le righe delle ricerche della Fase 3 di `make bench` stampano, per tabelle di 2^10, 2^16 e 2^20
slot, i byte allocati e il tempo di GC di ogni riga; l'RSS e una ricerca a tempo non sono
misurati. La questione resta aperta.

### QA-06

**Kernel nativi e SBCL come unica toolchain.** La specifica ammette FFI a cinque condizioni. Il
repository dichiara SBCL unica toolchain. Un kernel nativo richiede un compilatore o una libreria.
Le due cose si conciliano solo con un ADR.

- *Esperimento:* nessuno ora. Si apre solo se un profiling mostra un hot spot che SBCL non risolve
  (condizioni 1 e 2).

### QA-07

**Integrità delle entry della TT in concorrenza.** Una entry di più parole scritta da due thread
può risultare metà dell'una e metà dell'altra. Esistono tecniche note per rilevarlo (per esempio
memorizzare la chiave combinata con i dati e verificarla in lettura). Quali operazioni atomiche
SBCL offra sugli array di interi a 64 bit, e se i thread siano disponibili su ogni target, non è
stato verificato.

- *Esperimento:* test di stress con più thread che scrivono e leggono le stesse entry, in cerca di
  letture incoerenti, sulle piattaforme dove i thread sono disponibili.

### QA-08

**Definizione operativa di «Elo per CPU-secondo».** Elo non è una quantità per secondo. La proposta
è in [misure](misure.md#che-cosa-vuol-dire-elo-per-cpu-secondo).

- *Esperimento:* applicare le due letture proposte a una modifica di velocità nota e a una di
  qualità nota, e verificare che distinguano i due casi.

### QA-09

**Misura del tempo CPU in SBCL.** Se `get-internal-run-time` sia il tempo CPU del processo o del
thread, e con quale risoluzione sulle piattaforme target. Su SBCL 2.6.9, macOS arm64, conta il
tempo del processo ([osservazioni su SBCL](#osservazioni-su-sbcl)); `make bench` lo usa, su un
solo thread. La risoluzione e le altre piattaforme non sono state controllate.

- *Esperimento:* thread occupati e thread in attesa, su ogni piattaforma target; confronto con il
  tempo reale e con uno strumento esterno; intervalli sempre più brevi, per la risoluzione.

### QA-10

**Confine tra Fase 0 e Fase 1.** Vedi [roadmap](roadmap.md#fase-0).

- *Esperimento:* nessuno; si chiude con un ADR.

### QA-11

**Elementi della specifica senza fase:** server, corpus di posizioni, infrastruttura di
addestramento, test cross-platform, classificazione dei nodi («SEARCH TREE CLASSIFICATION»). Vedi
[roadmap](roadmap.md#senza-fase).

- *Esperimento:* nessuno; si chiude con un ADR.

### QA-12

**Piattaforme non raggiungibili.** L'ambiente di sviluppo osservato è macOS su ARM64. La CI di
GitHub ([workflow](../.github/workflows/ci.yml)) esegue `make check` su due immagini, una Linux
x86-64 e una macOS arm64, scelte nel workflow. L'immagine e la versione di SBCL di ogni
esecuzione si leggono nel suo log.

Esecuzioni registrate della CI. Ognuna si rilegge con `gh run view <run> --log`. Sul commit
371b205 il workflow chiedeva le etichette `ubuntu-latest` e `macos-latest`; dal commit fc50e17
chiede le immagini fissate `ubuntu-24.04` e `macos-26`. La colonna «Immagine» riporta ciò che il
log dichiara.

| Run | Commit | Immagine | Architettura | SBCL | Esito di `make check` |
|---|---|---|---|---|---|
| 37165773431 | 371b205 | `ubuntu-24.04` | x86-64 | 2.2.9.debian | 120 test, 132017 asserzioni, 0 fallimenti |
| 37165773431 | 371b205 | `macos-26-arm64` | arm64 | 2.6.8 | 120 test, 132017 asserzioni, 0 fallimenti |
| 37168681432 | fc50e17 | `ubuntu-24.04` | x86-64 | 2.2.9.debian | 124 test, 132127 asserzioni, 0 fallimenti |
| 37168681432 | fc50e17 | `macos-26-arm64` | arm64 | 2.6.8 | 124 test, 132127 asserzioni, 0 fallimenti |
| 37171203140 | 340515a | `ubuntu-24.04` | x86-64 | 2.2.9.debian | 125 test, 132137 asserzioni, 0 fallimenti |
| 37171203140 | 340515a | `macos-26-arm64` | arm64 | 2.6.8 | 125 test, 132137 asserzioni, 0 fallimenti |
| 37180782566 | 5d25099 | `ubuntu-24.04` | x86-64 | 2.2.9.debian | 191 test, 4068483 asserzioni, 0 fallimenti |
| 37180782566 | 5d25099 | `macos-26-arm64` | arm64 | 2.6.8 | 191 test, 4068483 asserzioni, 0 fallimenti |
| 37183294754 | c15291e | `ubuntu-24.04` | x86-64 | 2.2.9.debian | 191 test, 4068483 asserzioni, 0 fallimenti |
| 37183294754 | c15291e | `macos-26-arm64` | arm64 | 2.6.8 | 191 test, 4068483 asserzioni, 0 fallimenti |
| 37193831706 | 0408743 | `ubuntu-24.04` | x86-64 | 2.2.9.debian | 191 test, 4068483 asserzioni, 0 fallimenti |
| 37193831706 | 0408743 | `macos-26-arm64` | arm64 | 2.6.8 | 191 test, 4068483 asserzioni, 0 fallimenti |
| 37198250566 | cc6fceb | `ubuntu-24.04` | x86-64 | 2.2.9.debian | 252 test, 4507840 asserzioni, 0 fallimenti |
| 37198250566 | cc6fceb | `macos-26-arm64` | arm64 | 2.6.8 | 252 test, 4507840 asserzioni, 0 fallimenti |
| 37215795264 | b3190dc | `ubuntu-24.04` | x86-64 | 2.2.9.debian | 253 test, 4507911 asserzioni, 0 fallimenti |
| 37215795264 | b3190dc | `macos-26-arm64` | arm64 | 2.6.8 | 253 test, 4507911 asserzioni, 0 fallimenti |

La run 37180782566 è la prima che contiene il lavoro della Fase 1 (il generatore del livello
ottimizzato, le magic bitboard, i test differenziali): su x86-64 e su SBCL 2.2.9 quel codice è
stato eseguito solo nella CI, lì e nelle run seguenti. Le due immagini hanno compilato il hot
path con la policy di default e con l'implementazione `fixed-magic` (lo stampa il build nel log).

La run 37183294754 è sul commit c15291e, che porta le modifiche fatte dopo 5d25099 (il
caricamento che ricompila ogni sistema del repository, lo strumento dei numeri magici che non
dipende dai numeri nel file, i documenti: vedi il [CHANGELOG](../CHANGELOG.md)). Fino a quella
run erano state eseguite solo sulla macchina dell'autore. Anche lì le due immagini hanno compilato
il hot path con la policy di default e con `fixed-magic`, e nei log `make check` stampa lint,
autotest e link senza errori.

La run 37193831706 è sul commit 0408743, che registra le decisioni dell'autore (ADR-0017, gli ADR
accettati, il passaggio alla Fase 2): cambia documenti e un docstring di un test, non il codice
dei livelli, e sulle due immagini dà gli stessi conteggi di c15291e.

La run 37198250566 è sul commit cc6fceb, il primo che porta il codice della Fase 2: la
valutazione classica nei due livelli, le ricerche del livello ottimizzato e la firma di ricerca.
Anche lì le due immagini hanno compilato il hot path con la policy di default. Sulle due immagini
il test della firma (`optimized-search/search-signature-is-reproduced`) è passato, e i test di
allocazione hanno stampato 0 byte per il perft (1808266 mosse fatte e disfatte), per la
valutazione (800002 valutazioni) e per la ricerca (1957626 nodi): su quella revisione la firma e
questi conteggi coincidono fra x86-64 e arm64.

La run 37215795264 è sul commit b3190dc, che porta le modifiche fatte dopo cc6fceb (il termine
delle minacce che segue i valori dei pezzi, i contatori dell'attacco al re tipizzati, le righe
della valutazione di `make bench` in passate intercalate, `make signatures` che rilegge il file,
test nuovi, i documenti: vedi il [CHANGELOG](../CHANGELOG.md)). Fino a quella run erano state
eseguite solo sulla macchina dell'autore. Le due immagini hanno compilato il hot path con la
policy di default e con `fixed-magic`; il test della firma è passato, e i test di allocazione
hanno stampato 0 byte con gli stessi conteggi di cc6fceb (1808266 mosse, 800002 valutazioni,
1957626 nodi). Nei log `make check` stampa lint (78 file, 0 violazioni), autotest e link (1155,
0 rotti) senza errori.

In locale `make check` è terminato con codice 0 su 371b205 e fc50e17, e su un clone pulito di
5d25099, su macOS arm64 (Apple M4) con SBCL 2.6.9; queste esecuzioni non hanno un registro
pubblico.

Tra i test passati su entrambe le immagini ci sono i valori noti del generatore pseudocasuale
(`core/prng-known-vectors`), le chiavi Zobrist fissate (`zobrist/key-tables-have-golden-values`,
`zobrist/position-keys-have-golden-values`) e il perft alle profondità di `make test`
(`perft/main-table`, `perft/special-positions`). Su quelle revisioni questi output logici
coincidono quindi tra x86-64 e arm64. Su 5d25099 coincidono anche il perft del livello
ottimizzato con gli stessi valori attesi (`optimized-perft/main-table`,
`optimized-perft/special-positions`), il confronto differenziale con il riferimento (suite
`differential`) e i numeri magici: la ricerca dal seme ha ritrovato su entrambe le immagini i
numeri nel repository, con lo stesso numero di candidati estratti
(`optimized/committed-magic-numbers-are-the-output-of-the-seeded-search`). Il test
`optimized/perft-allocates-nothing-after-warm-up` ha stampato 0 byte allocati su entrambe. Lo
stesso vale su c15291e (run 37183294754), su 0408743 (run 37193831706) e su b3190dc (run
37215795264): gli stessi test passano sulle due immagini, la ricerca dal seme estrae lo stesso
numero di candidati (11064344 e 1984531 per le due disposizioni, nei log delle ultime due), e il
test di allocazione del perft stampa 0 byte. Il riscontro vale per quelle revisioni; i log stanno
su GitHub, non nel repository.

Il codice della Fase 3 (transposition table, ordinamento, PVS e NegaScout, la firma in formato 2)
non è ancora stato eseguito nella CI: lo ha eseguito solo la macchina dell'autore, macOS arm64
con SBCL 2.6.9.

Restano non eseguiti: Debian (Ubuntu ne deriva, ma non è Debian), FreeBSD x86-64, macOS Intel,
ARM64 Linux e FreeBSD, hardware x86 con AVX2, AVX-512, VNNI o BMI2, sistemi NUMA. La CI non esegue
`make perft-deep`, `make differential-deep`, `make test-checked`, `make hot-path` né `make bench`.
Nulla su quelle piattaforme, né questi target sulle immagini della CI, si dichiara verificato.

- *Esperimento:* eseguire `make check` e `make perft-deep` su ciascuna piattaforma mancante e
  registrare l'esito con il registro dell'ambiente.

### QA-13

**Significato di «transposition-driven search».** La specifica la nomina nella ricerca di base,
nella Fase 6 e nell'obiettivo finale, senza definirla.

In letteratura il nome indica uno schema di ricerca distribuita, la *transposition-table-driven
work scheduling*: ogni posizione si affida al processore che possiede la sua entry della TT, invece
di leggere la entry a distanza (Romein e altri, 2002, in
[classificazione](classificazione.md#riferimenti)). È la lettura candidata, non decisa. Se fosse
adottata, il lavoro starebbe con la ricerca parallela della Fase 11, non con le ricerche
alternative della Fase 6. Finché la questione è aperta, la classe è `HEURISTIC`, provvisoria.

- *Esperimento:* nessuno finché non c'è una definizione; si chiude con un ADR che la scrive e ne
  fissa la fase.

### QA-14

**Dove vivono le baseline.** Sono misure di una macchina: committarle, o tenerle fuori dal
repository. Il formato.

- *Esperimento:* nessuno; si chiude con un ADR.

### QA-15

**Aritmetica della NNUE tra backend.** Per avere accumulatore e inferenza bit-identici tra scalare
e SIMD serve aritmetica intera con saturazioni e arrotondamenti definiti. Alcune istruzioni SIMD
saturano: il riferimento scalare deve riprodurre lo stesso comportamento.

- *Esperimento:* confronto bit a bit di ogni backend con il riferimento su ingressi casuali e agli
  estremi dei valori.

### QA-16

**Distribuzione delle posizioni del fuzzer.** Le passeggiate casuali dalla posizione iniziale
sbilanciano il corpus verso le aperture. La specifica chiede anche stati legali rari.

- *Esperimento:* misurare la distribuzione per categoria delle posizioni generate; aggiungere
  partenze dal corpus e trasformazioni mirate (promozioni, scacchi doppi, diritti di arrocco rari)
  finché ogni categoria della [verifica](verifica.md#suite-dei-casi-speciali) è coperta.

### QA-17

> **Risolta da [ADR-0017](adr/0017-percorso-di-ricerca-per-le-alternative-exact.md)**, il
> 2026-10-04, per decisione dell'autore fra le opzioni elencate sotto: un ADR per le alternative
> `[EXACT]`. Per un'alternativa `[EXACT]` con le stesse uscite, provate da un'equivalenza
> esaustiva o differenziale e dal perft, INV-X3 è soddisfatto dall'equivalenza, dal
> microbenchmark e da `make bench` con il registro dell'ambiente e una regola di decisione,
> eseguito su una revisione committata e pulita; self-play e validazione statistica non si
> applicano. Dei tre casi registrati qui, il default `:fixed-magic` soddisfa le condizioni e
> [EXP-0001](../research/exp-0001-attacchi-dei-pezzi-a-lunga-gittata.md) è chiuso, Accettato; il
> filtro per maschere e l'espansione delle funzioni di nodo hanno l'equivalenza ma non la misura
> che ADR-0017 chiede, e l'ADR dice che cosa manca a ciascuno. Il testo che segue è la questione
> com'era aperta.

**Percorso di ricerca per le alternative con le stesse uscite.** INV-X3 (Deciso, dalla «RESEARCH
METHODOLOGY») accetta una tecnica solo dopo ipotesi, razionale, implementazione, microbenchmark,
benchmark di engine, self-play e validazione statistica; la [guida del repository](../CLAUDE.md) e
[research](../research/README.md) lo ripetono. La «MOVE GENERATION» chiede per le ottimizzazioni
della generazione che «Ogni alternativa deve essere benchmarkata». Nella Fase 1 la ricerca
dell'engine ottimizzato non esiste. Per una sostituzione che restituisce le stesse uscite bit per
bit e cambia solo il tempo, le tappe del benchmark di engine, del self-play e della validazione
statistica oggi non si possono eseguire, e un self-play a nodi fissi non misurerebbe nulla,
perché i due lati giocherebbero le stesse partite. È il caso delle
magic bitboard di [ADR-0016](adr/0016-attacchi-dei-pezzi-a-lunga-gittata.md), in parte del filtro
di legalità per maschere di [ADR-0015](adr/0015-generatore-di-mosse-del-livello-ottimizzato.md)
(scelto anche per non ripetere l'algoritmo dell'oracolo) e dell'espansione delle funzioni di nodo
nel perft di [ADR-0014](adr/0014-policy-di-compilazione-del-livello-ottimizzato.md) (punto 6).

Oggi `:fixed-magic` è il default di ADR-0016 mentre il suo record,
[EXP-0001](../research/exp-0001-attacchi-dei-pezzi-a-lunga-gittata.md), è In corso: è uno
scostamento da INV-X3, registrato qui e non risolto. ADR-0016 è in stato Proposta e non può
esentare da un invariante Deciso.

- *Opzioni:* tenere come default la baseline `:ray` finché EXP-0001 non si chiude; oppure un
  ADR, da far accettare all'autore, che dichiari come INV-X3 si applica alle alternative `EXACT`
  con le stesse uscite (per esempio: microbenchmark e misura di throughput prima di diventare il
  default, record di ricerca aperto, tappe del benchmark di engine, del self-play e della
  validazione statistica quando la ricerca esiste) e che aggiorni nello stesso commit la guida
  del repository e [research](../research/README.md).
- *Esperimento:* nessuno per decidere. EXP-0001 completa le tappe mancanti quando la ricerca
  esiste.

### QA-18

> **Risolta dall'autore**, che il 2026-10-04 ha scelto fra le opzioni elencate sotto di
> sostituire i sei pesi con valori fissati da una regola scritta. La regola è in
> [valutazione](valutazione.md#struttura-pedonale): un'unità per ogni sostegno che manca al
> pedone, 6 in mediogioco e 9 in finale; doppiato e arretrato 6 / 9, isolato 12 / 18. Nessuno dei
> sei è uguale al peso di Fruit 2.1 nello stesso ruolo; il confronto con altri engine non è stato
> rifatto per i valori nuovi. Nello stesso commit sono cambiati il documento con i suoi esempi,
> le due copie dei parametri, i valori attesi dei test e la firma di ricerca; ADR-0018 è stato
> accettato con la regola. Le altre coincidenze di [Provenienza](valutazione.md#provenienza)
> restano come sono: l'autore non ha chiesto di rivederle. Il testo che segue è la questione
> com'era.

**Pesi della struttura pedonale uguali alle costanti di Fruit 2.1.** La
[valutazione](valutazione.md#struttura-pedonale) proposta da
[ADR-0018](adr/0018-definizione-della-valutazione-classica.md) (Proposta) pesa il pedone
doppiato 10 in mediogioco e 20 in finale, l'isolato 10 e 15, l'arretrato 8 e 10, con la regola
«ogni debolezza vale circa un decimo di pedone, di più in finale». La regola non determina quei
numeri: non dà l'8 dell'arretrato in mediogioco, né il 20 del doppiato in finale, un quinto di
pedone. Una revisione li ha confrontati con il sorgente pubblicato di Fruit 2.1 (GPL; fonte in
[valutazione](valutazione.md#provenienza)): cinque dei sei sono le sue costanti negli stessi
ruoli (doppiato 10 e 20, isolato 10 in mediogioco, arretrato 8 e 10; l'isolato in finale vi vale
20), e il nucleo della definizione di pedone arretrato è il suo test. Il repository non registra
come i sei numeri siano stati scelti.

[ADR-0013](adr/0013-interpretazione-operativa-dell-originalita.md) ammette le idee (punto 1) e
non ammette di copiare tabelle di costanti di altri engine (punto 2). Se cinque piccoli interi
uguali, in una tabella di sei, siano una tabella copiata o una coincidenza, le sue regole non lo
decidono: è il caso dubbio del punto 5, che va all'autore. Finché l'autore non decide, nessun
documento del repository afferma che nessun valore della valutazione venga da un altro engine o
gli somigli. Le altre coincidenze trovate dalla stessa revisione (basi e tre pesi della
mobilità, la torre sulla settima, due coefficienti delle piece-square tables, l'insieme di case
dello spazio di Stockfish 11) sono numeri che seguono da una regola del documento, numeri singoli
o idee; sono elencate in [valutazione](valutazione.md#provenienza), e l'autore può decidere anche
su quelle.

- *Opzioni:* tenere i sei pesi, registrando in ADR-0018 la coincidenza e la decisione
  dell'autore; oppure sostituirli con valori che una regola scritta determina, così che ogni
  numero si ricalcoli dalla regola. La seconda opzione non garantisce numeri diversi da quelli
  di Fruit: una regola naturale come «un decimo di pedone in mediogioco, un quinto in finale»
  darebbe 10 e 20 alle tre debolezze, cioè di nuovo i valori di Fruit per il doppiato e per
  l'isolato in mediogioco e in finale. Con la seconda opzione cambiano, nello stesso commit, il
  documento con i suoi esempi calcolati, i parametri dei due livelli
  (`src/reference/classical.lisp`, `src/optimized/evaluation-tables.lisp`), i valori attesi dei
  test che ne dipendono e la firma di ricerca (`make signatures`).
- *Esperimento:* nessuno; si chiude con la decisione dell'autore, scritta in ADR-0018 se la
  prende accettandolo, altrimenti in un ADR nuovo.

### QA-19

> **Risolta da [ADR-0020](adr/0020-parametri-della-valutazione-dalla-fase-10.md)**, per decisione
> dell'autore del 2026-10-04 fra le opzioni elencate sotto: INV-X7 si applica ai parametri della
> valutazione dalla [Fase 10](roadmap.md#fase-10); fino ad allora restano costanti nel codice dei
> due livelli, e un peso si cambia in un solo commit con il documento, le due copie, i valori
> attesi e la firma. Il testo che segue è la questione com'era.

**Parametri della valutazione nel codice, contro INV-X7.** INV-X7 (Deciso, da «PARAMETER
OPTIMIZATION») chiede che ogni parametro importante si modifichi senza cambiare il codice, perché
un esperimento di taratura cambi dati e non programma
([architettura](architettura.md#ricerca-e-valutazione-come-sistemi-accoppiati)). I parametri
della valutazione classica ([riepilogo](valutazione.md#riepilogo-dei-parametri)) sono costanti
(`defconstant` e `sb-ext:defglobal`) in cima a `src/reference/classical.lisp` e a
`src/optimized/evaluation-tables.lisp`, una copia per livello che il test differenziale
confronta: cambiare un peso vuol dire cambiare il codice dei due livelli. ADR-0018 (Proposta)
lascia la forma all'implementazione; ADR-0019 (Proposta), che è l'implementazione, non la
decide. È uno scostamento da un invariante Deciso, che un ADR in stato Proposta non può
esentare, come per [QA-17](#qa-17). Oggi nessun parametro cambia da dati: la taratura è della
[Fase 10](roadmap.md#fase-10).

- *Opzioni:* un file di dati con i parametri, letto al caricamento da ciascun livello per conto
  proprio, come si legge la firma di ricerca (il test differenziale continuerebbe a confrontare
  i due livelli, ma un errore nel file sarebbe comune a entrambi e lo vedrebbero solo i valori
  attesi del documento, RSK-05); i parametri nel `core`, che ADR-0018 (punto 7) permette (un solo
  posto, ma ancora codice); oppure una decisione dell'autore che rimandi INV-X7 per la valutazione
  alla Fase 10, quando la taratura ne ha bisogno. Con un file di dati i pesi letti nel hot path
  diventano variabili invece di costanti: che cosa costi si misura con le righe della valutazione
  di `make bench`.
- *Esperimento:* nessuno per decidere; si chiude con un ADR.
