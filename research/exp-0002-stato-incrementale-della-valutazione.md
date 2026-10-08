# EXP-0002 — Stato incrementale della valutazione: aggiornamento in make e unmake contro ricalcolo

- **Stato:** Accettato
- **Data di apertura:** 2026-10-04
- **Data di chiusura:** 2026-10-08, secondo
  [ADR-0017](../docs/adr/0017-percorso-di-ricerca-per-le-alternative-exact.md)
- **Autore:** proposta del repository
- **Revisione di base:** il commit che porta la variante senza stato della sezione 3 e questo
  record con la regola della sezione 1, invariata; il suo hash è nella sezione 10, con
  l'esecuzione confermativa. La baseline è quella variante, nella stessa revisione
- **Etichetta proposta:** `[EXACT]`
- **Etichetta finale:** `[EXACT]` (sezione 9)
- **Fase:** 2 ([roadmap](../docs/roadmap.md#fase-2))
- **Decisione collegata:** [ADR-0018](../docs/adr/0018-definizione-della-valutazione-classica.md),
  punto 6, e [ADR-0019](../docs/adr/0019-valutazione-e-ricerca-del-livello-ottimizzato.md), punto
  2, entrambi accettati dall'autore il 2026-10-07; [ADR-0017](../docs/adr/0017-percorso-di-ricerca-per-le-alternative-exact.md),
  accettato, che dice quali tappe si applicano

> **Nota sull'ordine delle tappe.** Lo stato incrementale è nel codice dal commit cc6fceb, prima
> di questo record: contro l'ordine che [research](README.md) chiede, come per
> [EXP-0001](exp-0001-attacchi-dei-pezzi-a-lunga-gittata.md). Prima di questo record ci sono solo
> misure esplorative: le righe della valutazione di `make bench` (il risparmio per chiamata)
> esistono da cc6fceb, e in una revisione è stato confrontato fuori dal repository, con uno script
> non committato, il perft di una revisione senza lo stato (0408743) con quello dell'albero di
> lavoro. Quelle cifre non sono riportate (INV-X2) e non contano come conferma. La metrica
> principale della sezione 1, il tempo di una ricerca con e senza lo stato, non è stata misurata:
> la variante senza stato non esiste ancora.

## 1. Ipotesi

Con lo stato incrementale (variante A: make e unmake aggiornano `psq-mg`, `psq-eg` e `phase-raw`,
e la ricerca valuta le foglie con `bitboard-evaluate`) alpha-beta a profondità fissa del livello
ottimizzato costa meno tempo CPU che senza (variante B: make e unmake non toccano lo stato della
valutazione, e la ricerca valuta le foglie con `bitboard-evaluate-from-scratch`). Le due varianti
visitano lo stesso albero e restituiscono la stessa firma (sezione 4): cambia solo il tempo.

- Metrica principale: tempo CPU per ricerca nelle righe della ricerca di `make bench` (alpha-beta
  del livello ottimizzato alla profondità della firma, sulle stesse posizioni,
  [misure](../docs/misure.md#due-livelli-di-benchmark)). A parità di nodi è il tempo per nodo.
  Secondarie, riportate e non decisive: il tempo per chiamata di perft (che cosa lo stato costa
  in make e unmake dove non si valuta mai) e i nanosecondi per chiamata delle righe della
  valutazione (che cosa risparmia a ogni valutazione). Sono metriche di throughput, l'ultimo
  gradino della [gerarchia](../docs/misure.md#gerarchia-delle-metriche); per ADR-0017 (punto 3)
  le altre cambiano solo attraverso il tempo per nodo.
- Effetto minimo che interessa: nessuna soglia relativa. Interessa ogni differenza che la misura
  distingue secondo la regola seguente; una differenza più piccola si dichiara «non
  distinguibile», non «nulla».
- Regola di decisione, sull'esecuzione confermativa, con le due varianti compilate una volta
  ciascuna e misurate in passate nell'ordine A B B A:
  - «A più rapida di B» se, in ognuna delle righe della ricerca, il massimo di A è minore del
    minimo di B, e la mediana di A è minore di quella di B in ciascuna delle due passate;
  - «B più rapida di A» con i ruoli scambiati;
  - altrimenti la differenza è non distinguibile.
- Verdetto che ne segue: con «A più rapida di B» il record si chiude Accettato e lo stato resta.
  Altrimenti la convenienza che la specifica chiede («Utilizzare rappresentazioni incrementali
  dove conveniente», «EVALUATION») non è mostrata: il record si chiude Rifiutato, e togliere lo
  stato è una decisione dell'autore, con un ADR che sostituisca ADR-0018 e
  ADR-0019, ora accettati.

La regola è una proposta del repository; si può cambiare solo prima dell'esecuzione
confermativa, e il record dice quando è stata cambiata.

## 2. Razionale matematico

Materiale, piece-square tables e fase sono somme, su tutti i pezzi, di un termine che dipende
solo dal pezzo e dalla sua casa. Una mossa cambia da due a quattro di questi termini, uno per
ogni pezzo che lascia una casa o vi arriva: due per una mossa semplice e per una promozione
senza cattura, tre per una cattura (anche en passant o con promozione), quattro per l'arrocco.
Le tre somme si aggiornano quindi con poche letture di tavola e poche addizioni, e l'unmake le
rilegge dallo stack di undo. Il ricalcolo da zero visita ogni pezzo della posizione.

In alpha-beta a profondità fissa senza quiescenza ogni nodo tranne la radice costa un make e un
unmake, e ogni foglia una valutazione. La variante A paga l'aggiornamento a ogni make e a ogni
unmake e risparmia il ricalcolo a ogni foglia; la variante B fa il contrario. Quale delle due
costi meno dipende dalla frazione di foglie fra i nodi e da quanto pesino, in una valutazione, le
tre somme rispetto agli altri termini (mobilità, sicurezza del re, minacce), che si calcolano per
intero in entrambe. Il ragionamento non dice quale prevalga: lo dice la misura.

- Etichetta proposta e motivo: `[EXACT]`. Le somme aggiornate sono uguali a quelle calcolate da
  zero dopo ogni make e ogni unmake (INV-C8, docstring di `bitboard-make-move` in
  [`src/optimized/make.lisp`](../src/optimized/make.lisp)); quindi le due valutazioni danno lo
  stesso punteggio e le due varianti la stessa ricerca.
- Ipotesi da cui dipende: la velocità dipende dalla forma dell'albero (le posizioni e la
  profondità della firma) e dal codice che SBCL produce; la correttezza no.
- Errore possibile: un aggiornamento sbagliato per un tipo di mossa raro (promozione con
  cattura, en passant, arrocco); lo cercano i test della sezione 4.

## 3. Implementazione

Esiste la variante A: [`src/optimized/make.lisp`](../src/optimized/make.lisp) (make e unmake),
[`src/optimized/bitboard-position.lisp`](../src/optimized/bitboard-position.lisp) (lo stato, il
calcolo da zero, il controllo di coerenza, l'uguaglianza) e
[`src/optimized/evaluation.lisp`](../src/optimized/evaluation.lisp) (`bitboard-evaluate` legge lo
stato). Esiste anche la valutazione da zero, `bitboard-evaluate-from-scratch`.

Esiste anche la variante B, scritta per questo record:

- l'interruttore di compilazione `SCF_EVAL_STATE` (`incremental`, il default, oppure
  `recompute`), letto in [`src/optimized/policy.lisp`](../src/optimized/policy.lisp) come
  `SCF_SLIDERS` e fissato quando si compila il hot path: ogni file del hot path, e
  `bitboard-position.lisp`, controlla al caricamento di essere stato compilato con la scelta
  richiesta. Le macro `when-incremental-evaluation` e `if-incremental-evaluation` tolgono dalla
  variante B ogni lettura e scrittura dello stato in make e unmake; `bitboard-evaluate` vi calcola
  materiale, piece-square tables e fase dai bitboard, come `bitboard-evaluate-from-scratch`; il
  controllo di coerenza e l'uguaglianza non vi leggono lo stato;
- le righe di `make bench` per le due varianti, la ricerca (le stesse posizioni delle righe della
  ricerca) e il perft (le stesse posizioni delle righe di perft), compilate una volta ciascuna in
  `build/bench/state-…/` e misurate in passate A B B A
  ([`benchmarks/search-bench.lisp`](../benchmarks/search-bench.lisp)); ogni ricerca è controllata
  sulla firma e ogni perft sul suo conteggio, e il report stampa l'esito della regola della
  sezione 1 su quell'esecuzione.

- Parametri esposti in configurazione: `SCF_EVAL_STATE`.
- Interruttore che spegne la tecnica e restituisce il comportamento della baseline:
  `SCF_EVAL_STATE=recompute`.
- File toccati: `src/optimized/policy.lisp`, `make.lisp`, `evaluation.lisp`,
  `bitboard-position.lisp`, `package.lisp`; `benchmarks/search-bench.lisp`,
  `benchmarks/report.lisp`; i test dello stato (`tests/test-optimized-evaluation.lisp`,
  `tests/support.lisp`).

Reversibilità: con la variante B lo stato esce da make e unmake; i test di INV-C8 restano per la
variante A finché la variante A esiste.

## 4. Verifica di correttezza

- Perft, se cambia la generazione delle mosse: non cambia; `optimized-perft` deve passare con le
  due varianti.
- Test differenziale, se cambia il livello ottimizzato: per la variante A,
  `optimized-evaluation/make-and-unmake-keep-the-evaluation-state`,
  `optimized-evaluation/the-two-evaluations-and-the-breakdown-agree`, il controllo di coerenza del
  test differenziale delle mosse e `differential/evaluation-in-lockstep-playouts`, in
  `make check` ([verifica](../docs/verifica.md#valutazione-e-ricerca-del-livello-ottimizzato));
  per la variante B, le suite `optimized-evaluation`, `optimized-search` e `differential`
  compilate con l'interruttore.
- Firma di ricerca: invariata. `optimized-search/search-signature-is-reproduced` deve passare con
  le due varianti; è l'equivalenza di [ADR-0017](../docs/adr/0017-percorso-di-ricerca-per-le-alternative-exact.md)
  (punto 1) per la ricerca.
- Suite per tecnica: nessuna.

Eseguito sull'albero di lavoro prima del commit della revisione di base, sulla macchina del
registro della sezione 10: `make check` (variante A) e `SCF_EVAL_STATE=recompute make test`
(variante B) terminano entrambi con 259 test e 0 fallimenti, compresa la firma di ricerca, e
`SCF_EVAL_STATE=recompute make differential-deep` con 12 test e 0 fallimenti; nella
variante B i tre test che ispezionano lo stato controllano solo ciò che la variante tiene, e
`optimized-evaluation/the-evaluation-state-follows-the-build` controlla che nella variante A make
aggiorni lo stato e nella variante B lo lasci com'è.

## 5. Microbenchmark

Le righe della valutazione di `make bench` danno, per la variante A, `bitboard-evaluate` contro
`bitboard-evaluate-from-scratch` sulle stesse posizioni casuali con seme dichiarato: ciò che lo
stato risparmia a ogni valutazione. Le righe di perft delle due varianti danno ciò che lo stato
costa in make e unmake, dove il perft non valuta mai. Metriche secondarie, non decisive (sezione
1). Nell'esecuzione confermativa (sezione 10) la mediana della variante B è sotto quella della
variante A in ognuna delle quattro righe di perft: lo stato costa in make e unmake, come il
razionale della sezione 2 prevede. Le cifre non sono copiate qui
([QA-14](../docs/limiti-e-rischi.md#qa-14)): le stampa `make bench` sulla revisione di base.

## 6. Benchmark di engine

Le righe della ricerca di `make bench` per le due varianti, secondo la regola della sezione 1:
stessi nodi, tempo diverso. Nell'esecuzione confermativa (sezione 10), in ognuna delle cinque
righe della ricerca il massimo della variante A è sotto il minimo della variante B, e la mediana
di A è sotto quella di B in ciascuna delle due passate: la regola dà «A più rapida di B», e
`make bench` stampa lo stesso esito. Le due varianti hanno visitato gli stessi nodi e trovato gli
stessi valori: ogni ricerca è controllata sulla firma. Le cifre non sono copiate qui
([QA-14](../docs/limiti-e-rischi.md#qa-14)).

## 7. Self-play

Non si applica ([ADR-0017](../docs/adr/0017-percorso-di-ricerca-per-le-alternative-exact.md),
punto 3): le due varianti hanno le stesse uscite, quindi a nodi fissi giocherebbero le stesse
partite, e a tempo fisso una differenza di forza è la differenza di velocità della sezione 6.

## 8. Validazione statistica

Non si applica, per la stessa ragione.

## 9. Verdetto

**Accettato**, il 2026-10-08, secondo [ADR-0017](../docs/adr/0017-percorso-di-ricerca-per-le-alternative-exact.md): lo stato incrementale resta. Le
condizioni di ADR-0017, ciascuna con la sua evidenza in questo record:

- *`[EXACT]` con uscite identiche:* le due varianti danno la stessa valutazione e la stessa
  ricerca (sezione 2; INV-C8).
- *Equivalenza in `make check` o in un target profondo documentato:* le suite di `make check`
  con la variante A e di `SCF_EVAL_STATE=recompute make test` con la variante B, firma di ricerca
  compresa, e `make differential-deep` con la variante B (sezione 4).
- *Microbenchmark e `make bench`, con il registro dell'ambiente e una regola di decisione:* la
  regola della sezione 1, scritta prima dell'esecuzione e non cambiata, e il suo esito, «A più
  rapida di B» (sezione 6).
- *Revisione committata e pulita:* il clone del commit dd5a2a5, «working tree clean» (sezione
  10).
- *Self-play e validazione statistica:* non si applicano (ADR-0017, punto 3).

La misura è quella di una macchina in un momento: Apple M4 e SBCL 2.6.9, x86-64 non misurato, la
macchina occupata dall'interfaccia (sezione 10). Una ripetizione che non separasse le due
varianti con la stessa regola riaprirebbe il verdetto, e andrebbe riportata accanto a questa.

- Etichetta finale e su quale evidenza: `[EXACT]` per lo stato incrementale, con l'evidenza
  della sezione 4.
- Che cosa cambia in [classificazione](../docs/classificazione.md) o in un ADR: nulla nella
  classe; lo scostamento da INV-X3 che
  [ADR-0019](../docs/adr/0019-valutazione-e-ricerca-del-livello-ottimizzato.md) registrava per lo
  stato incrementale è chiuso da questo record.
- Come si torna indietro: `SCF_EVAL_STATE=recompute` (sezione 3).

## 10. Riproducibilità

| Dato | Valore |
|---|---|
| Comandi esatti | `make bench` su un clone pulito della revisione di base: misura le due varianti, compilate con l'interruttore della sezione 3, e stampa l'esito della regola |
| Semi | quelli che `make bench` stampa nel registro dell'ambiente |
| Identità dei dati (hash) | nessun file di posizioni: le posizioni sono nel registro dell'ambiente |
| Versione di SBCL e parametri di avvio | dal registro dell'ambiente |
| Macchina e sistema operativo | dal registro dell'ambiente |
| Revisioni git | da compilare |
| Posizione dei risultati | da decidere ([QA-14](../docs/limiti-e-rischi.md#qa-14)) |

Esecuzioni:

- *Esplorativa, prima della revisione di base:* una prova funzionale di `make bench` con
  `SCF_BENCH_REPETITIONS=1` sull'albero di lavoro non committato, per controllare che le righe
  delle due varianti girino e che ogni ricerca e ogni perft corrispondano alla firma e ai
  conteggi. Non conta: le sue cifre non sono riportate.
- *Confermativa, sul commit dd5a2a5:* `make bench`, con `SCF_BENCH_REPETITIONS` non impostata
  (cinque campioni per passata), in un clone pulito (`git clone` del repository e
  `git checkout dd5a2a5`), il 2026-10-08. Il registro dell'ambiente dice «dd5a2a5, working tree
  clean», e `git status --porcelain` era vuoto anche dopo. Carico medio (1, 5 e 15 minuti) su 10
  CPU logiche: all'avvio 4.31 4.52 3.73, alla fine 4.32 4.43 3.86. La macchina era occupata
  dall'interfaccia grafica e da un processo Perl estraneo, nessuno vicino al 100% di una CPU.
  L'esecuzione è terminata con codice 0 e ha stampato «Decision rule of research/exp-0002,
  section 1, on the search rows of this run: A faster than B.» Esito nelle sezioni 5 e 6.
