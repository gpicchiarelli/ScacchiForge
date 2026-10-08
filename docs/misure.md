# Misure

> **Fonte:** «OBIETTIVO MATEMATICO», «PERFORMANCE INFRASTRUCTURE», «PERFORMANCE GATES»,
> «METRICHE PRINCIPALI», «SELF-PLAY», «POSITION CORPUS» e «RESEARCH METHODOLOGY» della
> [specifica](specifica/specifica-originale.md), con le richieste di misura di «SEARCH
> FOUNDATION», «MOVE ORDERING» e «TRANSPOSITION TABLE». Decisioni:
> [ADR-0006](adr/0006-gerarchia-delle-metriche.md),
> [ADR-0017](adr/0017-percorso-di-ricerca-per-le-alternative-exact.md).

## Principio

Le prestazioni si misurano; non si dichiarano. Ogni cifra di prestazione in questo repository è un
target o una stima finché un comando nel repository non la produce e l'ambiente non è registrato
(INV-X2). Una cifra misurata è la misura di una macchina, non una proprietà del programma.

Questo documento non contiene numeri di prestazione.

## Due livelli di benchmark

La specifica chiede due livelli. Rispondono a domande diverse.

| Livello | Che cosa misura | Domanda |
|---|---|---|
| Microbenchmark | POPCNT, PEXT, generazione delle mosse, make/unmake, Zobrist, lookup TT, accumulatore NNUE, inferenza NNUE, kernel SIMD, accesso alla memoria | Questo pezzo è più veloce? |
| Benchmark di engine | NPS, profondità e tempo, hit rate della TT, cutoff rate, branching factor, QNodes, costo della valutazione, allocazione, GC, RSS, utilizzo CPU, forza | Il sistema, nell'insieme, vale di più? |

Un pezzo più veloce può non cambiare il sistema. Una tecnica che riduce i nodi può rallentare ogni
nodo. Servono entrambi i livelli, e per la forza serve il self-play.

La specifica chiede anche tre misure mirate:

- confrontare gli algoritmi di ricerca con benchmark scientifici su nodi, tempo, profondità, hit
  rate della TT, cutoff rate, forza e stabilità, senza assumerne uno migliore a priori («SEARCH
  FOUNDATION»);
- misurare a parte l'efficienza dell'ordinamento delle mosse («MOVE ORDERING»);
- provare diverse dimensioni e politiche di sostituzione della TT, senza assumere che più memoria
  renda di più («TRANSPOSITION TABLE»).

> **Proposta** — Regole per i microbenchmark.

- Il risultato del kernel misurato si confronta con quello del riferimento nella stessa
  esecuzione. Un microbenchmark che calcola il risultato sbagliato non misura niente.
- Ingressi da un generatore deterministico con seme dichiarato.
- Riscaldamento prima della misura; il compilatore non deve poter eliminare il lavoro misurato.
- Più ripetizioni. Si riporta la distribuzione (mediana e dispersione), non il valore migliore.
- Si registra l'attività del GC durante la misura.
- Si misura il costo della lookup contro quello del calcolo, come chiede la regola di
  [architettura](architettura.md#deduplicazione).

Oggi `make bench` misura soprattutto al primo livello, quello dei microbenchmark, e ha tre
gruppi di righe del secondo. I suoi kernel misurano le utilità sui bit e gli attacchi dei pezzi a
lunga gittata nelle tre implementazioni del livello ottimizzato: la lookup nelle tavole magic, nelle due disposizioni, contro il calcolo
per raggi che sostituisce, sugli stessi ingressi con seme dichiarato e con la policy del hot
path. Le sue righe di perft, del riferimento e del livello ottimizzato compilato con ciascuna
implementazione ([ADR-0016](adr/0016-attacchi-dei-pezzi-a-lunga-gittata.md)), misurano il
throughput di generazione delle mosse, filtro di legalità e make/unmake insieme: un
microbenchmark composto, perché la specifica mette «move generation» e «make/unmake» fra i
microbenchmark. Non è un benchmark di engine. Le righe della ricerca e della valutazione sono due
voci del secondo livello: l'NPS di alpha-beta del livello ottimizzato a profondità fissa, senza TT
né ordinamento, e il costo di una chiamata della valutazione classica nei due livelli. Le righe
dello stato della valutazione ([EXP-0002](../research/exp-0002-stato-incrementale-della-valutazione.md)) ripetono la ricerca e il
perft del livello ottimizzato con le due varianti, `incremental` e `recompute`, compilate una
volta ciascuna in `build/bench/state-…/` e misurate in passate A B B A, e stampano l'esito della
regola di decisione della sezione 1 del record su quell'esecuzione. Il terzo gruppo sono le
righe delle ricerche della Fase 3: nodi e tempo CPU a profondità fissa con e senza ordinamento e
TT, l'efficienza dell'ordinamento, il cutoff rate, la hit rate della TT per diverse dimensioni,
politiche e modalità, l'accordo fra tipo di nodo atteso e osservato; accanto, al primo livello,
il costo della lookup della TT. Le altre voci del benchmark di engine (profondità a tempo fisso,
branching factor, QNodes, RSS, forza) non hanno righe.

Il metodo di `make bench` ([`benchmarks/`](../benchmarks/), [`tools/bench.lisp`](../tools/bench.lisp)):

- **Build.** Prima di misurare ricompila nello stesso processo `scacchiforge`,
  `scacchiforge/test` e `scacchiforge/bench` (`tools/load.lisp`), così che la policy stampata
  nel registro sia quella del codice misurato. Il registro nomina una volta ogni file che fa una
  proclamazione `optimize`, anche quando la fa due volte.
- **Ripetizioni.** `SCF_BENCH_REPETITIONS` (5 se non impostata) è il numero di chiamate misurate
  di ogni riga di microbenchmark e di campioni di ogni riga di perft in ogni passata.
- **Microbenchmark.** Una chiamata di calibrazione, che fa anche da riscaldamento, sceglie quante
  passate sugli ingressi fa una chiamata; poi le chiamate misurate. Prima di misurare, le righe
  che calcolano la stessa quantità devono dare la stessa somma di controllo, o l'esecuzione si
  ferma. Le righe si eseguono una volta, sempre nello stesso ordine.
- **Perft: campioni calibrati.** Una chiamata di riscaldamento, poi una di calibrazione che dice
  quante chiamate servono perché un campione duri almeno mezzo secondo di CPU
  (`*perft-sample-seconds*`); ogni campione fa quel numero di chiamate, e la tabella dà il tempo
  per chiamata con il numero di chiamate. Ogni chiamata è confrontata con il conteggio atteso di
  [`tests/test-perft.lisp`](../tests/test-perft.lisp).
- **Perft: passate A B C C B A.** Il riferimento si esegue in una passata. Il livello ottimizzato
  si compila una volta con ciascuna implementazione degli attacchi dei pezzi a lunga gittata, in
  `build/bench/`, e si esegue in due passate per implementazione, nell'ordine
  `fixed-magic magic ray ray magic fixed-magic`, caricando prima di ogni passata i file compilati
  con la sua implementazione; alla fine il hot path si ricompila con l'implementazione del build.
  Una deriva lineare nel tempo pesa così su ogni implementazione allo stesso modo, in media
  sulle sue due passate. Mediana, minimo e massimo di una riga sono su entrambe le passate.
- **Tabella della deriva.** Per ogni riga del livello ottimizzato, la mediana di ciascuna passata
  e il rapporto fra la seconda e la prima: una deriva durante l'esecuzione si vede lì.
- **Ricerca** ([`benchmarks/search-bench.lisp`](../benchmarks/search-bench.lisp)). Alpha-beta del
  livello ottimizzato, con un contesto preallocato e l'implementazione degli attacchi del build,
  su alcune posizioni della firma di ricerca alla profondità della firma
  ([verifica](verifica.md#regressione-di-ricerca)). Ogni chiamata è confrontata con il valore e
  il numero di nodi registrati in [`tests/search-signature.sexp`](../tests/search-signature.sexp):
  una ricerca che calcola altro non produce una cifra. Campioni calibrati come quelli del perft,
  in una passata; la tabella dà il tempo CPU per ricerca e i nodi di ricerca per secondo di CPU.
- **Valutazione** (stesso file). La valutazione del livello ottimizzato con lo stato incrementale
  (`bitboard-evaluate`, quella che la ricerca chiama) e calcolata da zero
  (`bitboard-evaluate-from-scratch`), e `evaluate-classical` del riferimento, sulle stesse
  posizioni legali casuali con seme dichiarato. Prima di misurare, le tre righe devono dare la
  stessa somma dei punteggi. La tabella dà i nanosecondi per chiamata, la chiamata compresa. La
  differenza fra le prime due righe è ciò che lo stato incrementale risparmia quando si valuta.
  Ciò che costa tenerlo sta in make e unmake: lo isolano le righe dello stato della
  valutazione, che ripetono la ricerca e il perft con la variante senza stato
  (`SCF_EVAL_STATE=recompute`). È il confronto fra aggiornamento e ricalcolo che
  [architettura](architettura.md#deduplicazione) chiede per il calcolo incrementale, con la
  regola di decisione che [ADR-0017](adr/0017-percorso-di-ricerca-per-le-alternative-exact.md)
  chiede per un'alternativa `[EXACT]`: [EXP-0002](../research/exp-0002-stato-incrementale-della-valutazione.md).
- **Ricerche della Fase 3** ([`benchmarks/search-variants-bench.lisp`](../benchmarks/search-variants-bench.lisp)).
  Iterative deepening alla profondità della firma, su tre posizioni della firma, con undici
  configurazioni: alpha-beta di base; alpha-beta, PVS e NegaScout con l'ordinamento della Fase 3
  ([ADR-0023](adr/0023-ordinamento-delle-mosse-della-fase-3.md)); PVS ordinata con TT di 2^10,
  2^16 e 2^20 slot a due slot per bucket, di 2^16 con le politiche `:depth-preferred` e `:always`,
  in modalità normale, e di 2^16 in modalità di verifica (la ricerca di default come la firma la
  registra); PVS con TT senza ordinamento
  ([ADR-0021](adr/0021-transposition-table-del-livello-ottimizzato.md),
  [ADR-0022](adr/0022-pvs-negascout-e-tipi-di-nodo.md)). Ogni chiamata parte da una tabella
  pulita, e la pulizia non è nel tempo. Ogni chiamata è controllata: il valore di ogni
  configurazione, tranne quelle con la TT in modalità normale, deve essere quello registrato
  nella firma, il numero di nodi quello della prima chiamata della riga, e quello della ricerca
  di default quello della firma. Una TT in modalità normale può tagliare su una entry più profonda: la riga dice se
  il valore è quello di alpha-beta. Le configurazioni si eseguono in due passate, in ordine e al
  contrario, con campioni di almeno 0,2 s di CPU; la tabella dà i nodi, il tempo CPU per ricerca
  (mediana, minimo e massimo sulle due passate e la mediana di ciascuna) e i nodi per secondo di
  CPU; una seconda tabella dà, da una chiamata non misurata, la quota dei tagli beta fatti dalla
  prima mossa (l'efficienza dell'ordinamento), i tagli beta sui nodi sotto la radice che hanno
  cercato una mossa (il cutoff rate), le ri-ricerche, la quota dei nodi del tipo atteso, la hit
  rate (riscontri sulle sonde), la quota di sonde con una profondità usabile e i tagli della TT.
  Non si assume che più memoria renda di più: le righe delle tre dimensioni lo misurano.
- **Lookup della TT** (stesso file). Su 4096 posizioni legali casuali con seme dichiarato, per
  tabelle di più dimensioni e politiche e una in modalità di verifica: il costo di un
  inserimento, di una sonda delle posizioni inserite e di una sonda di altre posizioni casuali,
  in nanosecondi per operazione dal tempo CPU, con quante posizioni ogni sonda trova; in due
  passate, in ordine e al contrario. È il costo della lookup che la regola di
  [architettura](architettura.md#deduplicazione) chiede di confrontare con quello del calcolo.
- **Carico e tempo reale.** Il carico medio si stampa all'avvio, nel registro dell'ambiente, e
  alla fine, nell'ultima riga; la penultima dà il tempo CPU e il tempo reale dell'intera
  esecuzione. Il tempo reale si stampa anche accanto alle righe di perft.

Quanto una deriva o un carico cambino una conclusione, l'output non lo dice: lo decide la regola
con cui lo si legge, dichiarata prima dei dati (per esempio la sezione 1 di
[EXP-0001](../research/exp-0001-attacchi-dei-pezzi-a-lunga-gittata.md)).

Oggi del benchmark di engine esistono le voci dette sopra: NPS a profondità fissa e costo della
valutazione, per le ricerche baseline della [Fase 2](roadmap.md#fase-2); nodi e tempo a profondità
fissa, efficienza dell'ordinamento, cutoff rate e hit rate della TT per le ricerche della
[Fase 3](roadmap.md#fase-3), che non hanno quiescenza. Nessuna dice qualcosa sulla forza: non è
stata giocata nessuna partita. Le foglie di perft per secondo di CPU non sono l'NPS di una ricerca
([metriche](#metriche-da-definire-una-volta)).

> **Deciso (QA-17 → [ADR-0017](adr/0017-percorso-di-ricerca-per-le-alternative-exact.md))** —
> Per un'alternativa `[EXACT]` le cui uscite sono identiche a quelle dell'implementazione
> esistente o del riferimento, provate da un'equivalenza esaustiva o differenziale e dal perft,
> il percorso di INV-X3 è soddisfatto dall'equivalenza, dal microbenchmark e da `make bench` con
> il registro dell'ambiente e una regola di decisione, eseguito su una revisione committata e
> pulita; self-play e validazione statistica non si applicano. Per queste alternative il
> benchmark è `make bench` com'è sulla revisione misurata (quando ADR-0017 è stato scritto non
> aveva righe di una ricerca; oggi ha quelle descritte sopra). Non vale per ciò che cambia
> un'uscita: il valore o la mossa scelta da una ricerca, o il numero dei suoi nodi.

## Gerarchia delle metriche

> **Deciso (specifica «METRICHE PRINCIPALI» →
> [ADR-0006](adr/0006-gerarchia-delle-metriche.md))** — La gerarchia è della specifica.

La specifica non ammette l'NPS come indicatore principale. L'obiettivo è `max Strength / CPU-time`;
in secondo luogo `min Nodes / decision`, `min CPU-ms / solved position`, `max Depth / fixed time`.

| Priorità | Metrica |
|---|---|
| 1 | Elo / CPU-secondo |
| 2 | forza a tempo fisso |
| 3 | nodi per posizione tattica risolta |
| 4 | CPU-ms per decisione |
| 5 | profondità a tempo fisso |
| 6 | NPS |

Perché l'NPS inganna: una modifica può alzarlo togliendo lavoro utile, e una valutazione migliore
può abbassarlo e dare un engine più forte. Una decisione non si prende sul solo NPS (INV-X11).

### Che cosa vuol dire «Elo per CPU-secondo»

> **Aperto (QA-08)** — Elo è una differenza di forza tra due giocatori, non una quantità per
> secondo. Servono letture misurabili. [QA-08](limiti-e-rischi.md#qa-08).

> **Proposta** — Due letture.
>
> 1. *Elo a budget di CPU fisso.* La differenza di forza tra A e B quando entrambe hanno lo stesso
>    tempo CPU per partita o per mossa.
> 2. *CPU necessaria a parità di forza.* Il rapporto tra i tempi CPU con cui A e B ottengono lo
>    stesso punteggio contro un avversario fisso.
>
> Una partita a nodi fissi tiene fisso il lavoro: mostra se una modifica migliora la qualità per
> nodo, non se migliora la forza per CPU-secondo, perché non vede il costo di ogni nodo. Per le
> modifiche di velocità serve il tempo fisso.

## Self-play

La specifica chiede infrastruttura per engine contro engine, versione contro versione, parametro A
contro parametro B, partite a tempo fisso e a nodi fissi, aperture randomizzate, semi riproducibili.
Chiede anche statistiche appropriate e che nessun miglioramento si dichiari da una sola partita o da
un solo benchmark.

### Disegno di un confronto

> **Proposta**

- Le aperture vengono da un insieme noto, scelte con un seme dichiarato. Ogni apertura si gioca due
  volte, a colori invertiti. Le due partite formano una coppia: l'apertura non favorisce una parte.
- Stesso hardware, stessi limiti di tempo o di nodi, stessa dimensione della TT, stesso numero di
  thread, nessun altro carico sulla macchina.
- Si registrano le revisioni di A e di B, la configurazione, il seme, l'identità dell'insieme di
  aperture e l'ambiente.

| Modalità | Pro | Contro |
|---|---|---|
| Nodi fissi | riproducibile, indipendente dal carico | non vede il costo per nodo |
| Tempo fisso | vede velocità e qualità insieme | rumoroso, dipende dal carico e dalla frequenza della CPU |

### Statistica

> **Proposta**

**Punteggio ed Elo.** Con `W`, `D`, `L` vittorie, patte, sconfitte su `N` partite, il punteggio è
`s = (W + D/2) / N`. Nel modello logistico di Elo, `ΔElo = -400 * log10(1/s - 1)`, per `0 < s < 1`.

**Intervallo di confidenza.** L'errore standard viene dalla varianza campionaria del punteggio per
partita (o per coppia, se le partite sono in coppie). L'intervallo su `s` è `s ± z * errore`;
la funzione sopra è monotona, quindi si applica agli estremi.

**SPRT.** Si fissano prima dei dati due ipotesi, `Elo = elo0` e `Elo = elo1`, e gli errori `α` e
`β`. Si accumula il logaritmo del rapporto di verosimiglianza (LLR) partita dopo partita (Wald). Si
accetta `H1` quando l'LLR raggiunge `log((1 - β) / α)`, si accetta `H0` quando scende a
`log(β / (1 - α))`; in mezzo si continua. L'LLR si calcola su un modello dell'esito: il modello
usato va dichiarato.

**Numero di partite.** Non si fissa con una soglia. Lo decide il test: SPRT con un tetto di
budget, oppure una larghezza obiettivo dell'intervallo.

**Confronti multipli.** Se si provano `K` varianti contro la stessa baseline, la probabilità di
almeno un falso miglioramento cresce. Si registra `K`. Il vincitore si conferma con una prova
indipendente, con un seme e aperture nuovi.

**Differenza non risolta.** Un effetto più piccolo di ciò che la misura distingue si dichiara «non
distinguibile», non «nullo».

**Validare lo strumento.** Stimatore e SPRT si provano su partite simulate con Elo noto, per
controllare che gli errori osservati corrispondano a quelli dichiarati. Un guadagno di pochi Elo
richiede molte partite, perché l'errore diminuisce lentamente con `N`: su una sola macchina il
numero di esperimenti validabili è limitato ([limiti](limiti-e-rischi.md#rischi)).

### Corpus di posizioni

La specifica chiede un corpus diversificato: apertura, mediogioco, finale, tattico, quieto, attacchi
al re, strutture di pedoni, promozioni, en passant, arrocco, stati legali rari. Serve a regressione,
profiling, addestramento NNUE, tuning ed esperimenti.

> **Proposta**

- Ogni posizione ha una FEN, una categoria e una fonte.
- Gli insiemi per il tuning e per la valutazione sono separati. Tarare e giudicare sulle stesse
  posizioni è sovradattamento.
- Il corpus è versionato. Cambiarlo cambia la sua identità (un hash dei file), e le baseline
  misurate su quello precedente non valgono più.

## Registro dell'ambiente

> **Proposta** — Questi dati accompagnano ogni risultato. Senza, la cifra non entra nella
> documentazione (INV-X2).

| Dato | Come |
|---|---|
| Codice | revisione git e se l'albero di lavoro era pulito |
| Runtime | `(lisp-implementation-version)`, parametri di avvio (dimensione dello heap, GC) |
| Macchina | modello della CPU, numero di core, sistema operativo, politica di frequenza dove nota |
| Build | policy di ottimizzazione e opzioni di compilazione |
| Engine | dimensione della TT, thread, parametri |
| Casualità | semi |
| Dati | identità (hash) dei file di posizioni e di aperture |
| Esecuzione | comando esatto, data |

Oggi `make bench` stampa questo registro prima delle misure. Per ogni voce: la revisione git con
lo stato dell'albero di lavoro; versione di SBCL e di ASDF, dimensione dello heap e soglia del
GC; modello della CPU, numero di CPU logiche, sistema operativo e carico all'avvio (il carico
alla fine è nell'ultima riga dell'output); la policy di ottimizzazione globale e le
proclamazioni `optimize` di ogni file misurato, ciascun file nominato una volta, dopo aver
ricompilato nello stesso processo i sistemi che misura; l'implementazione degli attacchi dei
pezzi a lunga gittata del build, con il valore di `SCF_SLIDERS`, il seme dei numeri magici e la
dimensione delle tavole; che non c'è TT, che c'è un solo thread, e che i soli parametri sono i
pesi non tarati della valutazione classica ([valutazione](valutazione.md)); i semi degli ingressi,
compreso quello delle posizioni delle righe della valutazione; le posizioni, per nome e FEN, con
la provenienza dei valori attesi (la tabella di perft, il file della firma di ricerca), senza file
di posizioni né di aperture; le ripetizioni e l'ordine delle passate; il comando del processo e
la data in UTC. La politica di frequenza della
CPU non è registrata: l'output lo dice.

Alcune voci vengono da programmi esterni, ciascuno con un ripiego
([`benchmarks/system-info.lisp`](../benchmarks/system-info.lisp)):

| Voce | Fonti, in ordine |
|---|---|
| revisione e stato dell'albero di lavoro | `git rev-parse`, `git status`; altrimenti unknown |
| comando del processo | `ps`, tramite `/bin/sh`; altrimenti unknown |
| sistema operativo | `uname -srm`; altrimenti `software-type` e `software-version` di SBCL |
| modello della CPU | `sysctl machdep.cpu.brand_string`, `/proc/cpuinfo`, `sysctl hw.model`; altrimenti unknown |
| CPU logiche | `sysctl hw.ncpu`, `nproc`; altrimenti unknown |
| carico all'avvio | `sysctl vm.loadavg`, `/proc/loadavg`; altrimenti unknown |

Nessuno di questi programmi è quindi obbligatorio. Su SBCL 2.6.9, macOS arm64, con un `PATH`
che non contiene nessuno di essi, il registro è stampato lo stesso, con quelle voci a unknown e
il sistema operativo preso da SBCL, e il comando seguente esce con 0:

```bash
env PATH=/nonexistent SCF_BENCH_REPETITIONS=1 "$(command -v sbcl)" --noinform --no-userinit \
  --non-interactive --load tools/bench.lisp
```

**Strumenti di SBCL.** Nell'installazione usata per scrivere questo documento (SBCL 2.6.9, macOS
arm64) esistono `sb-ext:get-bytes-consed`, `sb-ext:*gc-run-time*` e `get-internal-run-time`, e
`internal-time-units-per-second` vale 1000000. Lì `get-internal-run-time` misura il tempo CPU
dell'intero processo, non del solo thread: il comando è in
[limiti e rischi](limiti-e-rischi.md#osservazioni-su-sbcl). La risoluzione, e il comportamento
sulle altre piattaforme, non sono stati verificati: [QA-09](limiti-e-rischi.md#qa-09).

**Rumore.** Frequenza della CPU, limiti termici, altri processi e GC alterano le misure. Si ripete,
si riporta la dispersione, si registra ciò che si sa dell'ambiente.

## Baseline e regressioni

La specifica chiede che ogni commit significativo si possa confrontare con una baseline e che
regressioni e miglioramenti si registrino.

> **Proposta**

- Una baseline è un insieme di risultati con il suo registro dell'ambiente e la revisione.
- Si confronta solo sulla stessa macchina e con lo stesso ambiente. Le misure di macchine diverse
  non si confrontano. Gli output logici (nodi, firme di ricerca, conteggi di perft) si confrontano
  ovunque.
- Una regressione si registra: che cosa, di quanto (con l'intervallo), contro quale baseline.

> **Aperto (QA-14)** — Dove vivono le baseline e in che formato. Sono misure di una macchina:
> committarle o no. [QA-14](limiti-e-rischi.md#qa-14).

## Metriche da definire una volta

> **Proposta** — Il codice dei benchmark fissa queste definizioni e le dichiara nell'output.

| Metrica | Definizione |
|---|---|
| Nodi | nodi di ricerca e nodi di quiescenza (QNodes) riportati separatamente |
| NPS | nodi diviso tempo CPU. Oggi `make bench` riporta le foglie di perft per secondo di CPU, con il tempo reale accanto: foglie di perft, non nodi di ricerca; e, nelle righe della ricerca, i nodi di ricerca di alpha-beta a profondità fissa (la radice, i nodi interni e le foglie, ciascuno con una generazione delle mosse o una valutazione; non ci sono QNodes) diviso la mediana del tempo CPU di una ricerca |
| Branching factor effettivo | una sola definizione, dichiarata |
| Hit rate della TT | sonde con chiave riscontrata diviso sonde; e le sole sonde con profondità sufficiente. Oggi `make bench` stampa le due: i riscontri (chiave intera uguale e, in modalità di verifica, controllo uguale) e i riscontri con una profondità usabile, divisi per le sonde |
| Cutoff rate | tagli beta diviso nodi in cui si poteva tagliare. Oggi: i nodi in cui una mossa ha raggiunto beta, diviso i nodi sotto la radice che hanno cercato almeno una mossa (la radice, a finestra piena, non taglia mai) |
| Efficienza dell'ordinamento | frazione dei tagli beta ottenuta alla prima mossa; la specifica chiede di misurarla a parte. Oggi `make bench` la stampa per ogni configurazione delle ricerche della Fase 3 |
| Allocazione | byte allocati per ricerca |
| Forza | la lettura scelta di Elo per CPU-secondo ([QA-08](limiti-e-rischi.md#qa-08)) |
