# ScacchiForge — guida per il lavoro nel repository

## Fase corrente

**Fase 2, per decisione dell'autore del 2026-10-04.** L'autore ha deciso di procedere alla
[Fase 2](docs/roadmap.md#fase-2): negamax, alpha-beta, iterative deepening e valutazione
classica, nell'engine ottimizzato. Il codice della Fase 2 esiste: la valutazione classica di
[valutazione](docs/valutazione.md) nei due livelli, le ricerche baseline del livello ottimizzato
e la prima firma di ricerca ([ADR-0018](docs/adr/0018-definizione-della-valutazione-classica.md)
e [ADR-0019](docs/adr/0019-valutazione-e-ricerca-del-livello-ottimizzato.md), accettati
dall'autore il 2026-10-07).
Il commit cc6fceb ne è un punto di controllo; il commit b3190dc porta le modifiche fatte dopo.

Il gate della Fase 2 è valutato voce per voce nella sezione *Status* del README: ognuna delle
cinque voci della [roadmap](docs/roadmap.md#fase-2) ha il comando che la mostra (`make test`, e
`make differential-deep` per il valore della ricerca e lo stato incrementale), terminato con
codice 0 sulla macchina dell'autore; `make check`, che esegue `make test`, è passato anche nella
CI su cc6fceb e su b3190dc, sulle due immagini (sotto). Il gate **non è dichiarato chiuso**.
Restano aperti:

- le regole che ogni gate aggiunge ([verifica](docs/verifica.md#gate-di-fase)): nessuna
  revisione dell'autore del lavoro della Fase 2 è registrata.

Lo stato incrementale della valutazione (ADR-0018 punto 6, ADR-0019 punto 2) ha ora anche la
misura che ADR-0017 chiede: [EXP-0002](research/exp-0002-stato-incrementale-della-valutazione.md) è chiuso,
Accettato, il 2026-10-08, con l'esecuzione confermativa sul commit dd5a2a5.

Tre voci che tenevano aperto il gate sono chiuse dalle decisioni dell'autore: ADR-0018 e
ADR-0019 sono accettati; i sei pesi della struttura pedonale, cinque dei quali erano costanti di
Fruit 2.1, li fissa ora una regola scritta ([QA-18](docs/limiti-e-rischi.md#qa-18),
[valutazione](docs/valutazione.md#struttura-pedonale)); INV-X7 si applica ai parametri della
valutazione dalla Fase 10 ([ADR-0020](docs/adr/0020-parametri-della-valutazione-dalla-fase-10.md),
che chiude [QA-19](docs/limiti-e-rischi.md#qa-19)).

Un'altra voce che teneva aperto il gate è soddisfatta: le modifiche fatte dopo cc6fceb, eseguite
prima solo sulla macchina dell'autore, sono nel commit b3190dc, su cui la run 37215795264 ha
passato `make check` sulle due immagini (sotto).

Il gate della Fase 0 che la [roadmap](docs/roadmap.md#fase-0) propone è soddisfatto: ogni sua
voce ha il comando che la mostra (`make check` su un checkout pulito, `make test`, `make bench`,
`make links`; la roadmap li elenca). Il gate è una proposta del repository; dove finisce la Fase 0
e comincia la Fase 1 è aperto ([QA-10](docs/limiti-e-rischi.md#qa-10)).

Il livello di riferimento esiste: FEN, generazione legale, make/unmake, perft, chiavi Zobrist,
matto e stallo, valutazione di materiale e valutazione classica, scambio dei colori, negamax,
alpha-beta e iterative deepening come baseline, con la variante principale, fuzzer di posizioni
legali. Il livello ottimizzato ha il proprio generatore di mosse: posizione bitboard con
conversione da e verso il riferimento, tavole di attacco, attacchi dei pezzi a lunga gittata
dietro un'interfaccia sola (`fixed-magic`, `magic` o `ray`,
[ADR-0016](docs/adr/0016-attacchi-dei-pezzi-a-lunga-gittata.md)), make/unmake con chiave
incrementale, generazione pseudo-legale, filtro di legalità per maschere di scacco e di
inchiodatura, perft e divide
([ADR-0015](docs/adr/0015-generatore-di-mosse-del-livello-ottimizzato.md); policy di
compilazione in [ADR-0014](docs/adr/0014-policy-di-compilazione-del-livello-ottimizzato.md);
tutti e tre accettati dall'autore il 2026-10-04). Lo giudicano il riferimento e i valori
pubblicati, con le suite `optimized-perft`, `optimized-movegen` e `differential` di `make test`,
con `make perft-deep` e con `make differential-deep`. Il livello ottimizzato ha anche la
valutazione classica, con materiale, piece-square tables e fase incrementali in make e unmake, e
negamax, alpha-beta e iterative deepening a profondità fissa: li giudicano le suite
`optimized-evaluation`, `optimized-search` e `differential`, e la firma di ricerca in
`tests/search-signature.sexp`, che scrive solo `make signatures`.

Il gate della [Fase 1](docs/roadmap.md#fase-1), rivalutato voce per voce il 2026-10-04 (il README
ne dà la tabella, nella sezione *Status*):

- **le cinque voci della roadmap** hanno ciascuna il comando che la mostra, e quei comandi sono
  terminati con codice 0 sulla macchina dell'autore (macOS arm64, SBCL 2.6.9). `make check`, che
  esegue le suite di `make test`, è passato nella CI sul commit 5d25099 (run 37180782566) e sul
  commit c15291e (run 37183294754), su x86-64 con SBCL 2.2.9 e su arm64 con SBCL 2.6.8
  ([QA-12](docs/limiti-e-rischi.md#qa-12)). Soddisfatte;
- **le modifiche fatte dopo 5d25099** (il caricamento forzato di tutti i sistemi del
  repository, lo strumento dei numeri magici che non dipende più dai numeri nel file, i
  documenti: vedi il [CHANGELOG](CHANGELOG.md)) erano state eseguite solo sulla macchina
  dell'autore; la run 37183294754 sul commit c15291e, che le porta, ha passato `make check` sulle
  due immagini. Soddisfatta;
- **le regole che ogni gate aggiunge** ([verifica](docs/verifica.md#gate-di-fase), in stato
  Proposta) si controllano in revisione, e il README dava la voce chiusa dalla revisione
  dell'autore. Una revisione dell'autore del lavoro della Fase 1 non è registrata; il CHANGELOG
  registra revisioni indipendenti dopo il commit 5d25099, audit fatti da agenti, non dall'autore.
  La voce non è soddisfatta: è superata dalla decisione dell'autore di procedere alla Fase 2;
- **lo scostamento da INV-X3** ([QA-17](docs/limiti-e-rischi.md#qa-17)): QA-17 è risolta dalla
  decisione dell'autore, [ADR-0017](docs/adr/0017-percorso-di-ricerca-per-le-alternative-exact.md).
  Il default `fixed-magic` ne soddisfa le condizioni, e
  [EXP-0001](research/exp-0001-attacchi-dei-pezzi-a-lunga-gittata.md) è Accettato. Il filtro per
  maschere (ADR-0015) e l'espansione delle funzioni di nodo (ADR-0014, punto 6) restano in uso
  con l'equivalenza ma senza la misura che ADR-0017 chiede: per questi due casi le condizioni di
  ADR-0017 non sono ancora soddisfatte, e l'ADR dice che cosa manca a ciascuno.

[ADR-0012](docs/adr/0012-lettura-del-gate-di-perft.md), accettato, pone il gate della Fase 1
prima di ogni fase successiva dell'engine ottimizzato. Nessuna ricerca aggressiva e nessuna TT
prima che il gate di perft passi (INV-X8). Lo stato di una fase è l'esito del suo gate: non si
scrivono durate, percentuali né date di avanzamento; si scrive la data di una decisione
dell'autore, come il passaggio alla Fase 2.

Principio operativo: non si scrive che qualcosa funziona, passa o è veloce senza aver eseguito il
comando che lo mostra. La prima bozza del repository dichiarava completa una fase senza essere mai
stata compilata: vedi il [CHANGELOG](CHANGELOG.md).

## Regole operative

- **Classificazione.** Ogni riduzione del lavoro porta almeno una delle sette etichette:
  `[THEOREM]`, `[EXACT]`, `[BOUNDED]`, `[PROBABILISTIC]`, `[HEURISTIC]`, `[EMPIRICAL]`,
  `[LEARNED]`. Nel dubbio, la più debole. Un'euristica efficace non è un teorema. Il formato nei
  docstring e nei commit è in [classificazione](docs/classificazione.md#come-si-marca), deciso da
  [ADR-0011](docs/adr/0011-convenzioni-di-classificazione.md).
- **Onestà sulle misure.** Per INV-X2 una cifra di prestazione entra nel repository solo con il
  comando, nel repository, che l'ha prodotta e con il registro dell'ambiente
  ([misure](docs/misure.md#registro-dellambiente)), come misura di una macchina; ogni altra
  cifra si dichiara target o stima. `make bench` stampa misure di una macchina in un momento,
  precedute dal registro dell'ambiente: i suoi tempi non si copiano nei documenti, e dove
  tenere le sue cifre è aperto ([QA-14](docs/limiti-e-rischi.md#qa-14)). Le cifre misurate su
  una macchina scritte nel repository sono di quattro tipi, ciascuna accanto al comando o
  all'esecuzione da cui viene; il README (sezione *Metrics*) dice dove stanno: i byte che
  stampano i test di allocazione di `make test`, con i conteggi stampati accanto; carichi medi
  della macchina, in [EXP-0001](research/exp-0001-attacchi-dei-pezzi-a-lunga-gittata.md)
  (sezione 10: quelli stampati da `make bench` nell'esecuzione confermativa, quelli di un
  tentativo di riproduzione non riuscito e uno letto prima di un tentativo rinviato, senza il
  comando) e, come limiti, in [ADR-0016](docs/adr/0016-attacchi-dei-pezzi-a-lunga-gittata.md),
  e in [EXP-0002](research/exp-0002-stato-incrementale-della-valutazione.md) (sezione 10: quelli stampati da
  `make bench` nell'esecuzione confermativa);
  nella stessa sezione di EXP-0001, la quota di CPU di tre processi estranei durante quel
  tentativo, senza il comando, e l'intervallo dei rapporti fra la seconda e la prima passata
  di `:fixed-magic` nel tentativo; in
  [limiti-e-rischi](docs/limiti-e-rischi.md#osservazioni-su-sbcl), la crescita di
  `get-internal-run-time` mentre un thread dorme 1 s, accanto al comando che la stampa.
- **Oracolo prima.** Il riferimento è l'oracolo. Non dipende dall'ottimizzato (INV-A2) e si
  giudica con valori pubblicati dove esistono; l'ottimizzato si giudica con il riferimento, mai il
  contrario. Un valore atteso di perft non si modifica per far passare un test: se pare sbagliato
  si riporta, con la prova. Ogni valore atteso deve dire da dove viene, nell'intestazione di
  `tests/test-perft.lisp`: da una fonte pubblicata, nominata, oppure da questo engine. Un valore
  non pubblicato non si presenta come pubblicato. I valori attesi della valutazione vengono dalla
  definizione in [valutazione](docs/valutazione.md), calcolati a mano o dal documento; la firma
  di ricerca è un valore di regressione di questo engine, e la riscrive solo `make signatures`,
  mai per far passare una modifica `[EXACT]`.
- **Nessuna tecnica per sentito dire.** Una tecnica entra solo dopo il percorso di
  [research/](research/README.md): ipotesi, razionale, implementazione, microbenchmark, benchmark
  di engine, self-play, validazione statistica (INV-X3). Mai perché «sembra più veloce». Per
  un'alternativa `[EXACT]` le cui uscite sono identiche a quelle dell'implementazione esistente o
  del riferimento, provate da un'equivalenza esaustiva o differenziale e dal perft, il percorso è
  soddisfatto dall'equivalenza, dal microbenchmark e da `make bench` con il registro dell'ambiente
  e una regola di decisione; self-play e validazione statistica non si applicano
  ([ADR-0017](docs/adr/0017-percorso-di-ricerca-per-le-alternative-exact.md)). L'equivalenza è un
  test in `make check` o in un target profondo documentato, e `make bench` si esegue su una
  revisione committata e pulita. Non vale per ciò che cambia un'uscita (il valore di una ricerca,
  la mossa scelta, il numero di nodi di una ricerca): per quello vale il percorso intero. Dei tre
  casi che [QA-17](docs/limiti-e-rischi.md#qa-17), ora risolta, registrava, il default
  `fixed-magic` di [ADR-0016](docs/adr/0016-attacchi-dei-pezzi-a-lunga-gittata.md) soddisfa le
  condizioni ([EXP-0001](research/exp-0001-attacchi-dei-pezzi-a-lunga-gittata.md), Accettato); il
  filtro di legalità per maschere di ADR-0015 e l'espansione delle funzioni di nodo nel perft di
  ADR-0014 (punto 6) hanno l'equivalenza ma non la misura: che cosa manca è in ADR-0017. Un terzo
  caso è venuto con la Fase 2, lo stato incrementale della valutazione (ADR-0018 punto 6, ADR-0019
  punto 2, accettati): ne soddisfa le condizioni
  ([EXP-0002](research/exp-0002-stato-incrementale-della-valutazione.md), Accettato).
- **Una sola metrica non decide.** L'NPS è l'ultima della gerarchia
  ([misure](docs/misure.md#gerarchia-delle-metriche), INV-X11).

## Fonti di verità, in ordine

1. [docs/specifica/specifica-originale.md](docs/specifica/specifica-originale.md) — non si
   modifica senza un ADR.
2. [docs/adr/](docs/adr/README.md) — gli ADR accettati possono emendare la specifica,
   dichiarandolo. Un ADR in stato Proposta non vincola.
3. [docs/invarianti.md](docs/invarianti.md) — regole `INV-…` inviolabili.
4. Documenti tematici in `docs/`.

## Vincoli

- **Solo SBCL** (INV-A1, [ADR-0004](docs/adr/0004-nessuna-dipendenza-esterna-e-harness-proprio.md),
  accettato): nessun Quicklisp, nessuna libreria Lisp di terzi. ASDF e UIOP vengono con SBCL e si
  usano. I test girano su un harness del repository, in `tests/`.
- **Codice originale** (INV-X9, [ADR-0007](docs/adr/0007-licenza-bsd-2-clause-e-originalita.md)):
  nessun codice di Stockfish o derivato, nessuna implementazione proprietaria di altri engine.
  Niente pesi, tabelle o dati di altri engine
  ([ADR-0013](docs/adr/0013-interpretazione-operativa-dell-originalita.md)). Le coincidenze note
  della valutazione con engine pubblicati sono in [valutazione](docs/valutazione.md#provenienza).
  I pesi della struttura pedonale, che coincidevano con costanti di Fruit 2.1, li fissa ora una
  regola scritta, per decisione dell'autore ([QA-18](docs/limiti-e-rischi.md#qa-18)). Nessun
  documento afferma che nessun valore della valutazione somigli a quelli di un altro engine: il
  confronto ne copre due, Fruit 2.1 e Stockfish 11.
- **Parametri** (INV-X7, Deciso): per la valutazione si applica dalla Fase 10
  ([ADR-0020](docs/adr/0020-parametri-della-valutazione-dalla-fase-10.md), che chiude
  [QA-19](docs/limiti-e-rischi.md#qa-19)); fino ad allora i parametri sono costanti nel codice dei
  due livelli. Un peso si
  cambia in un commit solo nel documento con i suoi esempi, nelle due copie e nei valori attesi
  dei test che ne dipendono, con `make signatures`.
- **Il nucleo resta Common Lisp** (INV-A8, [ADR-0001](docs/adr/0001-common-lisp-sbcl.md)).
- Nei documenti, ciò che non viene dalla specifica è marcato `> **Proposta** —`,
  `> **Deciso (FONTE → ADR-nnnn)** —` o `> **Aperto (QA-nn)** —`, come definiti nelle
  [convenzioni](docs/README.md#convenzioni). Non presentare un'interpretazione come requisito.
- Identificativi (`INV-`, `ADR-`, `QA-`, `RSK-`, `EXP-`, `TT-`) stabili: non si rinumerano; una
  voce chiusa si marca, non si cancella. Un ADR accettato non si riscrive, si sostituisce.
- **Nessun avviso di compilazione.** `tools/load.lisp` trasforma ogni `WARNING` e
  `STYLE-WARNING`, tranne la ridefinizione dallo stesso file, in un errore; una ridefinizione da
  un altro file fa fallire la build. `make build` carica i sistemi una seconda volta nello stesso
  processo, e anche quel caricamento deve passare. Per questo solo gli interi sono
  `defconstant`; le tabelle usano `sb-ext:defglobal`.
- **Linter** (`tools/lint.lisp`): 100 colonne, niente tab, niente spazi finali, niente
  `ignore-errors`, niente `eval`.
- **`POSITION` è un simbolo di `COMMON-LISP`** e non si può ridefinire (package lock): la
  struttura della posizione si chiama `chess-position`. La prima bozza non si caricava per questo
  motivo, come riporta il commit 26fe29f.
- I file compilati vanno in `build/fasl/` (ignorata da git), mai in `~/.cache`: lo garantisce
  `tools/load.lisp`. Chi aggiunge uno script che carica il sistema lo passa da lì.
- `core` contiene solo definizioni (INV-A3,
  [ADR-0010](docs/adr/0010-regole-di-indipendenza-tra-i-livelli.md)): se un errore sta nel
  `core`, il confronto differenziale non lo vede.
- Nel hot path non si alloca (INV-A5): `Move` è un valore packed, i buffer sono preallocati. Che
  cosa alloca davvero si misura con `sb-ext:get-bytes-consed`, non si afferma: il test
  `perft-allocates-nothing-after-warm-up` lo controlla in `make test`, con
  `evaluation-allocates-nothing-after-warm-up` e `search-allocates-nothing-after-warm-up` per la
  valutazione e la ricerca; `make hot-path` mostra il disassemblato.
- **Hot path del livello ottimizzato** ([ADR-0014](docs/adr/0014-policy-di-compilazione-del-livello-ottimizzato.md),
  accettato). I suoi file sono elencati una volta sola, in `*hot-path-files*`
  (`src/optimized/policy.lisp`), e proclamano la policy con `(declaim-optimized-policy)`; i
  macro stanno prima di quella riga. Un file nuovo del hot path fa lo stesso. Chi cambia il hot
  path esegue anche `make test-checked` e `make hot-path`.

## Convenzioni

- Documentazione in italiano; codice, identificativi, docstring e nomi dei test in inglese
  ([ADR-0009](docs/adr/0009-convenzione-linguistica.md), accettato). I termini tecnici consolidati
  restano in inglese; l'elenco è uno solo, nel
  [glossario](docs/glossario.md#convenzione-linguistica).
- Sono in inglese anche `README.md`, `SECURITY.md`, `SUPPORT.md`, `CODE_OF_CONDUCT.md`, i moduli
  delle issue e il modello di pull request.
- Messaggi di commit in italiano, con una riga finale `Classification: [TAG]` oppure
  `Classification: none`.
- Una modifica di requisito si propaga nello stesso commit a specifica o ADR, invarianti e
  documenti tematici (INV-X12). La documentazione che una modifica rende falsa si aggiorna con
  essa.
- Moduli: `scacchiforge.core` (`scf-core`), `scacchiforge.reference` (`scf-ref`),
  `scacchiforge.optimized` (`scf-opt`). Sistemi ASDF: `scacchiforge`, `scacchiforge/test`,
  `scacchiforge/bench`; il terzo dipende dal secondo, da cui legge i conteggi attesi di perft.
  Dove il riferimento esporta lo stesso nome (`make-move`, `perft`, …) l'ottimizzato usa il
  prefisso `bitboard-`: i due livelli non esportano nomi uguali (lo controlla un test).
- Gli esperimenti vivono in `research/`, dal [modello](research/TEMPLATE.md).

## Comandi

Il comando che chiude ogni modifica:

```bash
make check
```

Compila senza avvisi, esegue i test e il linter, esegue gli autotest del linter, dello strumento
dei link e del caricamento rigoroso, e controlla ogni link e ogni ancora dei file Markdown. Altri
target (`make help` li elenca):

| Comando | Fa |
|---|---|
| `make build` | compila i tre sistemi con gli avvisi trattati come errori |
| `make test` | build, poi tutte le suite di test (perft alle profondità standard, fuzzer, test differenziali, valutazione e ricerca dei due livelli, firma di ricerca) |
| `make lint` · `make lint-selftest` | linter; prova del linter, dello strumento dei link e del caricamento rigoroso (`tools/build.lisp --self-test`, cinque casi piantati in `build/self-test/`) su campioni con errori noti |
| `make links` | link e ancore nei file Markdown |
| `make test-checked` | come `make test`, con il hot path del livello ottimizzato compilato a `safety 3` ([ADR-0014](docs/adr/0014-policy-di-compilazione-del-livello-ottimizzato.md)); fuori da `make check` |
| `make perft-deep` | i perft profondi dei due livelli; fuori da `make check` |
| `make differential-deep` | il test differenziale tra ottimizzato e riferimento su milioni di posizioni, con la valutazione, il valore della ricerca e le varianti principali rigiocate dal riferimento a profondità maggiori, e i valori della firma di ricerca confrontati con alpha-beta del riferimento alla profondità della firma; fuori da `make check` |
| `make bench` | registro dell'ambiente, poi perft (riferimento, e ottimizzato con ciascuna implementazione degli attacchi dei pezzi a lunga gittata, in passate `fixed-magic magic ray ray magic fixed-magic` con campioni di circa mezzo secondo di CPU e la tabella di ogni passata), nodi per secondo di alpha-beta del livello ottimizzato alla profondità della firma, costo di una chiamata della valutazione nei due livelli (tre righe in passate intercalate A B C C B A, con la mediana di ogni passata), ricerca e perft con le due varianti dello stato della valutazione di EXP-0002 in passate A B B A, con l'esito della sua regola di decisione, utilità sui bit e attacchi dei pezzi a lunga gittata, in tempo CPU, con i contatori del GC; il tempo reale solo per le righe di perft e per l'intera esecuzione; il carico medio all'inizio e alla fine; misure di una macchina; fuori da `make check` |
| `make hot-path` | note di efficienza di SBCL, scansione del disassemblato delle funzioni di ogni nodo del perft e della ricerca e di `bitboard-evaluate` (provata prima su funzioni piantate), allocazione, tempi di perft per policy del hot path del livello ottimizzato, con le funzioni di nodo espanse e chiamate (misure di una macchina); fuori da `make check` |
| `make magics` | ripete la ricerca dei numeri magici dal seme, senza costruire prima le tavole dai numeri nel file, e riscrive `src/optimized/magic-numbers.lisp` ([ADR-0016](docs/adr/0016-attacchi-dei-pezzi-a-lunga-gittata.md)); fuori da `make check` |
| `make signatures` | ricalcola la firma di ricerca e riscrive `tests/search-signature.sexp`, con la sua intestazione di provenienza; solo per una modifica che deve cambiare un'uscita della ricerca, mai per far passare una modifica `[EXACT]` ([verifica](docs/verifica.md#regressione-di-ricerca)); fuori da `make check` |

La variabile d'ambiente `SCF_SLIDERS` (`fixed-magic`, `magic` o `ray`; non impostata vale
`fixed-magic`) sceglie, per ogni target che carica il sistema, l'implementazione con cui si
compilano gli attacchi dei pezzi a lunga gittata del livello ottimizzato, per esempio
`SCF_SLIDERS=ray make test` o `SCF_SLIDERS=magic make perft-deep`
([ADR-0016](docs/adr/0016-attacchi-dei-pezzi-a-lunga-gittata.md), accettato). I numeri magici in
`src/optimized/magic-numbers.lisp` non si scrivono a mano: li scrive `make magics`.

Allo stesso modo `SCF_EVAL_STATE` (`incremental` o `recompute`; non impostata vale
`incremental`) sceglie se make e unmake del livello ottimizzato tengano lo stato incrementale
della valutazione (materiale, piece-square tables, fase) o se la valutazione lo ricalcoli a ogni
chiamata: le varianti A e B di [EXP-0002](research/exp-0002-stato-incrementale-della-valutazione.md). Le due danno le stesse
valutazioni e le stesse ricerche: `SCF_EVAL_STATE=recompute make test` esegue tutte le suite, e i
tre test dello stato si limitano a ciò che la variante B tiene.

Ogni target che carica il sistema lo fa con `scf-tools:load-strict` (`tools/load.lisp`), che
ricompila in `build/fasl/` ogni sistema di `scacchiforge.asd` raggiunto dal caricamento, non
solo quello nominato: `:force t` di ASDF forzerebbe solo il sistema nominato e caricherebbe
`scacchiforge` dai file compilati da un target precedente. Così, per esempio, `make perft-deep`
dopo `make test-checked`, o `SCF_SLIDERS=magic make perft-deep` dopo `make test`, ricompila
prima di eseguire. Un caricamento fatto a mano che non forza `scacchiforge` e trova il hot path
compilato con un'altra implementazione degli attacchi o un'altra policy si ferma con un errore
(`check-compiled-choice`). Due target eseguiti insieme nello stesso albero compilano negli stessi
file: è successo che `make perft-deep`, avviato insieme a `make differential-deep`, si
fermasse su un file compilato mancante, e che da solo passasse. I target si eseguono uno alla
volta.

Per lavorare in un REPL:

```bash
sbcl --noinform --no-userinit --load tools/load.lisp
```

e poi `(scf-tools:load-strict "scacchiforge")`.

## Che cosa è stato eseguito

Dove `make check` è stato eseguito, su quale revisione, con quale SBCL e con quale esito è
registrato in [QA-12](docs/limiti-e-rischi.md#qa-12); il README lo riporta in inglese, nella
sezione *Status*. Il lavoro della Fase 1 (il generatore ottimizzato e ciò che lo accompagna) è
nel commit 5d25099, su cui la CI ha eseguito `make check` su x86-64 con SBCL 2.2.9 e su arm64
con SBCL 2.6.8 (run 37180782566); le correzioni che lo seguono sono nel commit c15291e, su cui la
CI ha eseguito `make check` sulle stesse immagini (run 37183294754), come sul commit 0408743, che
registra le decisioni dell'autore (run 37193831706). Il primo codice della Fase 2 è nel commit
cc6fceb, un punto di controllo: la run 37198250566 vi ha eseguito `make check` sulle due
immagini, 252 test e 0 fallimenti su ciascuna; la firma di ricerca è riprodotta, e i test di
allocazione hanno stampato 0 byte per il perft, la valutazione e la ricerca. Le modifiche fatte
dopo cc6fceb sono nel commit b3190dc: la run 37215795264 vi ha eseguito `make check` sulle
stesse immagini, 253 test e 0 fallimenti su ciascuna, con la firma riprodotta e 0 byte nei tre
test di allocazione. `make perft-deep`, `make differential-deep`, `make test-checked`,
`make hot-path` e `make bench` sono stati eseguiti solo sulla macchina dell'autore, macOS arm64
con SBCL 2.6.9. Su FreeBSD, macOS Intel e Linux ARM64 non è stato eseguito nulla. Una cosa vale
su una piattaforma solo se vi è stata eseguita.
