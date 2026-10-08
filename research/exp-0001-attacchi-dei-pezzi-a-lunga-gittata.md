# EXP-0001 — Attacchi dei pezzi a lunga gittata: magic bitboard contro raggi

- **Stato:** Accettato
- **Data di apertura:** 2026-10-04
- **Data di chiusura:** 2026-10-04, secondo
  [ADR-0017](../docs/adr/0017-percorso-di-ricerca-per-le-alternative-exact.md)
- **Autore:** proposta del repository; la chiusura (sezione 9) applica ADR-0017, decisione
  dell'autore del progetto del 2026-10-04
- **Revisione di base:** il commit 5d25099, che contiene le tre implementazioni e questo record
  con le sezioni 1-9, misurato su un clone pulito (sezione 10); la baseline è l'implementazione
  `:ray` della stessa revisione, scelta con `SCF_SLIDERS=ray`
- **Etichetta proposta:** `[EXACT]` per le tavole magic; `[HEURISTIC]` per lo scarto rapido dei
  candidati nella ricerca dei numeri, che cambia quale numero si trova, mai se è magico
- **Etichetta finale:** `[EXACT]` per le tavole magic; `[HEURISTIC]` per lo scarto rapido dei
  candidati (sezione 9)
- **Fase:** 1 ([roadmap](../docs/roadmap.md#fase-1))
- **Decisione collegata:** [ADR-0016](../docs/adr/0016-attacchi-dei-pezzi-a-lunga-gittata.md)
  e [ADR-0017](../docs/adr/0017-percorso-di-ricerca-per-le-alternative-exact.md), accettati il
  2026-10-04; [QA-17](../docs/limiti-e-rischi.md#qa-17), risolta da ADR-0017

> **Nota sull'ordine delle tappe.** Questo record è stato aperto dopo le misure esplorative con
> cui [ADR-0016](../docs/adr/0016-attacchi-dei-pezzi-a-lunga-gittata.md) ha scelto il default
> `:fixed-magic`: l'ipotesi, la metrica e la regola di decisione qui sotto sono state scritte
> dopo aver visto quelle misure, che quindi non contano come conferma. Conta l'esecuzione
> confermativa della sezione 10: `make bench` su un clone pulito del commit 5d25099, che porta
> questo record con la regola della sezione 1, invariata da allora. Una prima esecuzione detta
> confermativa, su un albero di lavoro non committato, è sostituita da questa (sezione 10).

## 1. Ipotesi

Gli attacchi di torre e alfiere letti da una tavola magic costano meno tempo CPU del calcolo per
raggi che sostituiscono, e il perft del livello ottimizzato, che con le tre implementazioni dà
gli stessi conteggi, costa meno tempo CPU con `:fixed-magic` che con `:magic` e con `:ray`.

- Metrica principale: tempo CPU per chiamata di perft, cioè per foglia a parità di conteggio,
  nelle righe del livello ottimizzato di `make bench`. Secondaria: nanosecondi per attacco nelle
  righe degli attacchi dei pezzi a lunga gittata di `make bench`. Sono metriche di throughput,
  dell'ultimo gradino della [gerarchia](../docs/misure.md#gerarchia-delle-metriche); la sezione 2
  dice perché qui le altre non cambiano e la sezione 9 perché, da sole, non bastano ad accettare
  la tecnica (INV-X11).
- Effetto minimo che interessa: nessuna soglia relativa. Interessa ogni differenza che la misura
  distingue secondo la regola seguente; una differenza più piccola si dichiara «non
  distinguibile», non «nulla» ([misure](../docs/misure.md#statistica)).
- Regola di decisione, per una coppia di implementazioni A e B, sull'esecuzione confermativa:
  - *perft:* «A più rapida di B» se, in ognuna delle quattro righe di perft, il massimo di A è
    minore del minimo di B, e la mediana di A è minore di quella di B in ciascuna delle due
    passate;
  - *microbenchmark:* «A più rapida di B» se, nelle righe della torre e dell'alfiere, il massimo
    di A è minore del minimo di B;
  - altrimenti, per quella coppia e quel livello, la differenza è non distinguibile.

## 2. Razionale matematico

Gli attacchi di un pezzo a lunga gittata da una casa dipendono solo dall'occupazione delle sue
case rilevanti (le case dei suoi raggi tranne l'ultima di ciascuno). Un numero magico trasforma
quell'occupazione in un indice di una tavola in cui sta l'attacco: la lettura è un AND, una
moltiplicazione a 64 bit, uno spostamento e un accesso alla memoria. Il calcolo per raggi fa, per
ognuna delle quattro direzioni, una lettura del raggio, un AND e un salto condizionato e, se il
raggio ha un bloccante, una ricerca di bit, una seconda lettura e uno XOR
([`src/optimized/rays.lisp`](../src/optimized/rays.lisp)). Ci si aspetta che la lettura magic
esegua meno istruzioni e meno salti per attacco; il suo costo è la
memoria: 294912 voci a 64 bit (2304 KiB) per `:fixed-magic`, 107648 (841 KiB) per `:magic`,
contro le sole tavole dei raggi.

Le tre implementazioni restituiscono lo stesso attacco per ogni casa e ogni occupazione (sezione
4). Ne segue che il generatore produce le stesse mosse nello stesso ordine, e che il perft dà gli
stessi conteggi. Per lo stesso motivo una ricerca deterministica a un thread che dipende solo
dalla posizione e dalle mosse generate, con lo stesso limite di nodi, visiterebbe lo stesso albero
con ciascuna: nodi, profondità e mosse scelte uguali. Fra le metriche della gerarchia, le prime
cinque possono quindi cambiare solo attraverso il tempo per nodo, e quanto di quel tempo vada
agli attacchi in una ricerca non si sa finché la ricerca non esiste.

- Etichetta proposta e motivo: `[EXACT]`. Ogni occupazione rilevante di ogni casa è enumerata
  quando le tavole si costruiscono, e un numero che non è magico ferma il caricamento; le case
  fuori dalla maschera non cambiano gli attacchi. La base è nei docstring di
  `initialise-magic-tables` e `find-magic-number`
  ([`src/optimized/magic.lisp`](../src/optimized/magic.lisp)).
- Ipotesi da cui dipende: l'ipotesi di velocità dipende dalla gerarchia di memoria e dal codice
  che SBCL produce per la moltiplicazione e lo spostamento a 64 bit; la correttezza non dipende da
  nulla di questo.
- Errore possibile: su una macchina con meno cache la tavola più grande di `:fixed-magic` può
  costare più del calcolo che risparmia; x86-64 non è stato misurato.

## 3. Implementazione

Tre implementazioni dietro l'interfaccia `bishop-attacks` / `rook-attacks`
([`src/optimized/sliders.lisp`](../src/optimized/sliders.lisp)), tutte compilate e con le tavole
costruite a ogni caricamento.

- Parametri esposti in configurazione: la variabile d'ambiente `SCF_SLIDERS` (`fixed-magic`,
  `magic`, `ray`), letta quando si compila il hot path; non impostata vale `fixed-magic`
  ([ADR-0016](../docs/adr/0016-attacchi-dei-pezzi-a-lunga-gittata.md), punto 2).
- Interruttore che spegne la tecnica e restituisce il comportamento della baseline:
  `SCF_SLIDERS=ray`.
- File toccati: `src/optimized/policy.lisp`, `rays.lisp`, `magic.lisp`, `magic-numbers.lisp`,
  `sliders.lisp`; `tools/generate-magics.lisp`; `benchmarks/micro.lisp`,
  `benchmarks/perft-bench.lisp`; `tests/test-optimized.lisp`.

Reversibilità: con `SCF_SLIDERS=ray` il livello ottimizzato usa il calcolo per raggi di
[ADR-0015](../docs/adr/0015-generatore-di-mosse-del-livello-ottimizzato.md); togliere
`magic.lisp`, `magic-numbers.lisp` e le letture magic di `sliders.lisp` riporta il codice a
quello stato.

## 4. Verifica di correttezza

- Perft, se cambia la generazione delle mosse: suite `optimized-perft` di `make test`, con gli
  stessi valori attesi del riferimento, con ciascuna implementazione
  (`SCF_SLIDERS=fixed-magic make test`, `SCF_SLIDERS=magic make test`,
  `SCF_SLIDERS=ray make test`).
- Test differenziale, se cambia il livello ottimizzato: suite `differential` di `make test`, con
  ciascuna implementazione; `make differential-deep` con il default.
- Firma di ricerca: non esiste ancora una ricerca del livello ottimizzato.
- Suite per tecnica: `every-slider-implementation-matches-a-naive-walk-on-every-relevant-occupancy`
  (ogni implementazione su ogni sottoinsieme delle case rilevanti di ogni casa, da solo e con bit
  casuali fuori dalla maschera), `slider-implementations-agree-on-random-occupancies`,
  `slider-attacks-match-a-naive-walk`, `relevant-occupancy-masks-and-magic-table-sizes`,
  `committed-magic-numbers-are-the-output-of-the-seeded-search`,
  `a-number-that-is-not-magic-is-refused`
  ([`tests/test-optimized.lisp`](../tests/test-optimized.lisp)).

Esito: sul commit 5d25099, con ciascuna implementazione, tutte le suite di `make test` passano
(sezione 10).

## 5. Microbenchmark

Il comando è `make bench`, con le ripetizioni di default. Due parti.

- *Attacchi.* Torre e alfiere, per ciascuna implementazione, su 65536 coppie di casa e
  occupazione con seme dichiarato (seme 5 per le occupazioni, seme 2 per le case), con i kernel
  compilati con la policy del hot path; il calcolo per raggi è la baseline che la lookup
  sostituisce. Le righe si eseguono sempre nello stesso ordine (`fixed-magic`, `magic`, `ray`),
  senza passate invertite.
- *Perft.* Il throughput di generazione, filtro di legalità e make/unmake insieme, su quattro
  posizioni (startpos 5, kiwipete 4, pos3 5, pos5 4), con il hot path compilato con ciascuna
  implementazione. Le passate sono nell'ordine `fixed-magic magic ray ray magic fixed-magic`,
  così che una deriva della macchina raggiunga ogni implementazione allo stesso modo; ogni
  campione dura almeno mezzo secondo di CPU. È un microbenchmark composto, non un benchmark di
  engine ([misure](../docs/misure.md#due-livelli-di-benchmark)).

Esito dell'esecuzione confermativa sul commit 5d25099 (sezione 10), secondo la regola della
sezione 1:

- *attacchi:* `:fixed-magic` più rapido di `:magic`, `:magic` più rapido di `:ray`, per la torre
  e per l'alfiere;
- *perft:* `:fixed-magic` più rapido di `:magic`, `:magic` più rapido di `:ray`, in ognuna delle
  quattro posizioni e in ciascuna delle due passate. Fra `:fixed-magic` e `:magic`, in pos3 e in
  pos5, il massimo del primo è vicino al minimo del secondo.

L'ipotesi della sezione 1 regge, su questa macchina e a questo livello di misura. Il carico della
macchina è salito durante l'esecuzione (sezione 10), e la regola non ne tiene conto. Le cifre non
si copiano qui ([QA-14](../docs/limiti-e-rischi.md#qa-14)): `make bench` le riproduce, con il
registro dell'ambiente.

## 6. Benchmark di engine

Non esiste una ricerca del livello ottimizzato, e quindi né NPS di ricerca, né profondità, né TT.
Fino alla chiusura questa sezione diceva: «Non eseguibile [...]. Le righe di perft della sezione
5 non lo sostituiscono.»

Con [ADR-0017](../docs/adr/0017-percorso-di-ricerca-per-le-alternative-exact.md) (2026-10-04),
per un'alternativa `[EXACT]` con le stesse uscite il benchmark di engine è `make bench`, con il
registro dell'ambiente e una regola di decisione, eseguito su una revisione committata e pulita.
Per questo record è l'esecuzione confermativa delle sezioni 5 e 10. ADR-0017 dice anche che cosa
contiene oggi `make bench`: nessuna riga di una ricerca; le righe di perft, che
[misure](../docs/misure.md#due-livelli-di-benchmark) chiama un microbenchmark composto, sono il
suo livello più alto.

## 7. Self-play

Non eseguito. Fino alla chiusura questa sezione diceva che non era eseguibile per lo stesso
motivo della sezione 6, e che quando la ricerca esisterà una partita a nodi fissi non misurerebbe
nulla, perché per la sezione 2 i due lati giocherebbero le stesse partite; servirebbe il tempo
fisso, o la seconda lettura di «Elo per CPU-secondo»
([misure](../docs/misure.md#che-cosa-vuol-dire-elo-per-cpu-secondo)).

Con ADR-0017 il self-play non si applica a questa alternativa: a nodi fissi le partite sono
identiche, e a tempo fisso una differenza di forza è una differenza di velocità, che la sezione 5
ha misurato (ADR-0017, punto 3).

## 8. Validazione statistica

- Test: per la sezione 5, la regola di decisione della sezione 1, che non è un test statistico.
  Con ADR-0017 la validazione statistica non si applica a questa alternativa (punto 3).
- Parametri dichiarati **prima** dei dati: la regola della sezione 1, scritta prima
  dell'esecuzione confermativa (non prima delle misure esplorative: vedi la nota in testa).
- Numero di varianti provate contro la stessa baseline (confronti multipli): tre implementazioni,
  tre coppie.
- Risultato: nessuna partita.
- Conferma indipendente: nessuna.

## 9. Verdetto

**Accettato**, il 2026-10-04, secondo
[ADR-0017](../docs/adr/0017-percorso-di-ricerca-per-le-alternative-exact.md), che l'autore ha
deciso quel giorno.

Fino ad allora il verdetto era «Non ancora»: il record restava In corso perché le tappe 6, 7 e 8
di INV-X3 non si potevano eseguire prima che esistesse una ricerca, e le metriche della sezione 5
sono di throughput, che da sole non decidono (INV-X11); il default `:fixed-magic` di ADR-0016 era
in uso prima che la tecnica fosse accettata, e lo scostamento era
[QA-17](../docs/limiti-e-rischi.md#qa-17).

Le ragioni dell'accettazione sono le condizioni di ADR-0017, ciascuna con la sua evidenza in
questo record:

- *`[EXACT]` con uscite identiche:* le tre implementazioni danno lo stesso attacco per ogni casa
  e ogni occupazione, quindi le stesse mosse nello stesso ordine e lo stesso perft (sezione 2).
- *Equivalenza esaustiva in `make check`, e perft:* il test esaustivo su ogni occupazione
  rilevante di ogni casa contro un cammino casa per casa e contro `:ray`, il perft con ciascuna
  implementazione sul commit 5d25099 (sezione 4 e sezione 10).
- *Microbenchmark e `make bench`, con il registro dell'ambiente e una regola di decisione:* la
  regola della sezione 1 e l'esito della sezione 5, «`:fixed-magic` più rapido di `:magic`,
  `:magic` più rapido di `:ray`», negli attacchi e nel perft.
- *Revisione committata e pulita:* il clone del commit 5d25099, «working tree clean»
  (sezione 10).
- *Self-play e validazione statistica:* non si applicano (ADR-0017, punto 3).

La misura resta quella di una macchina in un momento, con i limiti scritti nelle sezioni 2, 5 e
10: Apple M4 e SBCL 2.6.9, x86-64 non misurato, il carico salito durante l'esecuzione. Un
tentativo di riproduzione sotto carico non ha confermato l'ordine tra `:fixed-magic` e `:magic`
(sezione 10): il vantaggio di velocità che sostiene il default va riconfermato su una macchina
scarica. Il dubbio riguarda solo il tempo: le uscite delle tre implementazioni sono identiche.

- Etichetta finale e su quale evidenza: `[EXACT]` per le tavole magic, con l'evidenza esaustiva
  della sezione 4; `[HEURISTIC]` per lo scarto rapido dei candidati nella ricerca dei numeri,
  che cambia quale numero si trova, mai se è magico. La scelta del default non riduce lavoro
  (ADR-0016, Classificazione).
- Che cosa cambia in [classificazione](../docs/classificazione.md) o in un ADR: ADR-0016 è
  accettato dal 2026-10-04 e il suo default resta `:fixed-magic`; la riga delle magic bitboard
  del livello ottimizzato nella tabella delle tecniche è quella che ADR-0016 decide.
- Come si torna indietro: `SCF_SLIDERS=ray`, oppure `:ray` come primo elemento di
  `*slider-implementations*` ([`src/optimized/policy.lisp`](../src/optimized/policy.lisp)).

## 10. Riproducibilità

| Dato | Valore |
|---|---|
| Comandi esatti | nel clone, uno alla volta: `make bench`; `SCF_SLIDERS=fixed-magic make test`, `SCF_SLIDERS=magic make test`, `SCF_SLIDERS=ray make test` |
| Semi | ingressi dei microbenchmark: random 1, masks 2, lsb 3, msb 4, occupancy 5 (`benchmarks/micro.lisp`); numeri magici: `#x4D61676963686521` |
| Identità dei dati (hash) | nessun file di dati: le posizioni sono per nome e FEN nelle tabelle dei test |
| Versione di SBCL e parametri di avvio | SBCL 2.6.9, ASDF 3.3.1, heap di default di 1024 MiB (lo stampa il registro dell'ambiente) |
| Macchina e sistema operativo | Apple M4, 10 CPU logiche, Darwin 27.0.0 arm64 |
| Revisioni git | 5d25099, su un clone pulito: `git clone` del repository e `git checkout 5d25099`; il registro dell'ambiente dice «5d25099, working tree clean», e `git status --porcelain` era vuoto anche dopo i tre `make test` |
| Posizione dei risultati | non conservati nel repository ([QA-14](../docs/limiti-e-rischi.md#qa-14)) |

Esecuzioni, 2026-10-04, sulla macchina della riga precedente, in ordine:

- *Esplorative, alla base della prima stesura di ADR-0016:* due esecuzioni di `make bench` con
  `SCF_BENCH_REPETITIONS=11` su una versione precedente, mai committata, del benchmark e del
  default. Nella prima `:magic` era il default e le sue righe venivano prima di quelle di
  `:fixed-magic`; nella seconda le righe di perft cominciavano da `:fixed-magic`, quelle degli
  attacchi ancora da `:magic`. Quella versione non è nel repository: le due esecuzioni non si
  ripetono con un comando committato, e non sono evidenza.
- *Esplorativa, prima di questo record:* `make bench` sul benchmark attuale (passate di perft
  nell'ordine `fixed-magic magic ray ray magic fixed-magic`).
- *Sull'albero non committato, sostituita:* `make bench`, con `SCF_BENCH_REPETITIONS` non
  impostata, avviato dopo la stesura delle sezioni 1-9 (data del registro dell'ambiente:
  2026-10-04T05:07:39Z), su una copia dell'albero di lavoro sopra 340515a senza la cartella
  `.git`, per cui il registro diceva «source revision unknown»; poi i tre `make test` sulla stessa
  copia. La prima stesura di questo record la chiamava confermativa. Non è legata a un commit, e
  non conta: la sostituisce la seguente.
- *Confermativa, sul commit 5d25099:* `make bench`, con `SCF_BENCH_REPETITIONS` non impostata,
  nel clone pulito della riga «Revisioni git» (data del registro dell'ambiente:
  2026-10-04T05:50:51Z; «source revision: 5d25099, working tree clean»). La regola della
  sezione 1 è quella del commit, scritta prima di questa esecuzione. Carico medio (1, 5 e 15
  minuti) all'avvio 2.23 2.01 2.22, alla fine 16.08 7.73 4.45, su 10 CPU logiche: durante
  l'ultima parte dell'esecuzione altri processi occupavano la macchina, e il registro non dice
  quali. Il tempo reale dell'intera esecuzione è quasi uguale al suo tempo CPU (li stampa la
  riga «Whole run» dell'output): il processo misurato non è rimasto senza CPU, ma la contesa per
  cache e memoria non è misurata. Esito nella sezione 5.
- *Correttezza, sul commit 5d25099:* `SCF_SLIDERS=fixed-magic make test`,
  `SCF_SLIDERS=magic make test` e `SCF_SLIDERS=ray make test`, uno alla volta, nello stesso
  clone, dopo l'esecuzione confermativa. Ognuno ha stampato nel build l'implementazione chiesta
  e ha chiuso con 191 test, 4068483 asserzioni, 0 fallimenti, comprese le suite
  `optimized-perft`, `optimized-movegen` e `differential`.
- *Tentativo di riproduzione, sul commit 5d25099, non riuscito:* `make bench` in un nuovo clone
  pulito dello stesso commit, eseguito da un controllo indipendente il 2026-10-04 mentre altri
  processi occupavano la macchina (tre processi di un'altra suite di test, ciascuno vicino al
  100% di una CPU; carico medio a 1 minuto 7.27 all'avvio e 9.77 alla fine). Con la regola della
  sezione 1, `:fixed-magic` e `:magic` non si distinguono, né negli attacchi né nel perft; negli
  attacchi entrambi sono più rapidi di `:ray`, nel perft nessuno dei tre si distingue dagli
  altri. I rapporti tra la seconda e la prima passata di `:fixed-magic`, da 1,19 a 1,34, mostrano
  una deriva durante l'esecuzione. Le cifre stampate da quell'esecuzione, da cui questi rapporti
  sono tratti, non sono conservate nel repository ([QA-14](../docs/limiti-e-rischi.md#qa-14)).
- *Ripetizione su una macchina scarica: da fare.* Un secondo tentativo, lo stesso giorno, è stato
  rinviato senza misurare: il carico medio a 1 minuto era vicino a 30, per processi estranei al
  progetto. Se anche su una macchina scarica `:fixed-magic` e `:magic` non si separano con la
  regola della sezione 1, il verdetto della sezione 9 si riapre.
