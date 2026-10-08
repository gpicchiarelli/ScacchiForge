# ADR-0014 — Policy di compilazione del livello ottimizzato

- **Stato:** Accettata
- **Data:** 2026-10-04; accettata dall'autore il 2026-10-04, per sua decisione in sessione
- **Rapporto con la specifica:** proposta nuova (non nella specifica); applica «COMMON LISP /
  SBCL» (hot path con allocazione quasi nulla, array tipizzati, niente boxing, comportamento
  verificato con profiling e disassembly) e «REFERENCE ENGINE» («L'ottimizzazione non deve mai
  rendere impossibile la verifica della correttezza»). Confermata dall'autore il 2026-10-04.
- **Riferimenti:** [classificazione](../classificazione.md#regole-duso) (regola 7),
  [verifica](../verifica.md#gate-di-modifica), INV-A4, INV-A5, INV-X3,
  [ADR-0015](0015-generatore-di-mosse-del-livello-ottimizzato.md),
  [QA-03](../limiti-e-rischi.md#qa-03), [QA-14](../limiti-e-rischi.md#qa-14),
  [QA-17](../limiti-e-rischi.md#qa-17)

## Contesto

SBCL compila secondo la policy `optimize`. Con `speed` alta produce codice specializzato sui
tipi dichiarati e segnala con note di efficienza ciò che non riesce a specializzare. Con
`safety 0` toglie i controlli dei limiti degli array e dei tipi dichiarati: un indice fuori dai
limiti o una dichiarazione falsa non segnalano più un errore, cambiano il comportamento o
scrivono fuori da un vettore.

La regola 7 della [classificazione](../classificazione.md#regole-duso) dice che
un'ottimizzazione per tipi dichiarati è `EXACT` se le dichiarazioni sono vere, e che con
`safety` bassa una dichiarazione falsa cambia il comportamento. Serve quindi un modo di eseguire
i test con ogni dichiarazione controllata.

Il livello ottimizzato ha un hot path (generazione, filtro di legalità, make/unmake, perft) che
deve essere veloce per costruzione e corretto per verifica. I suoi file che non sono nel hot path
(utilità sui bit, posizione e conversione, costruzione delle tavole) dichiarano
`(speed 1) (safety 2)` e restano così: le loro funzioni inline, quando il hot path le usa, si
compilano con la policy del file che le chiama.

## Decisione

> **Deciso (autore → ADR-0014)** — Proposta del repository, confermata dall'autore il
> 2026-10-04.

1. **Una policy, scritta in un solo punto.** I file del hot path del livello ottimizzato
   (`rays`, `sliders`, `attacks`, `make`, `movegen`, `legal`, `perft` in `src/optimized/`,
   elencati in `*hot-path-files*`) si compilano con `(optimize (speed 3) (safety 1) (debug 0))`.
   La policy sta in [`src/optimized/policy.lisp`](../../src/optimized/policy.lisp); ogni file
   del hot path la proclama con `(declaim-optimized-policy)` dove comincia la sua parte calda.
   Ciò che un file del hot path contiene fuori dal hot path sta, con la policy degli altri file
   del livello, `(speed 1) (safety 2)`, prima di quella riga (i macro, i cui espansori girano
   durante la compilazione: in `sliders`, `movegen` e `perft`) oppure dopo una
   `(declaim (optimize (speed 1) (safety 2)))` che chiude la parte calda (le funzioni che
   allocano per chiamanti fuori dal hot path: `bitboard-pseudo-legal-moves` e
   `bitboard-legal-moves` in `legal`, `bitboard-perft` e `bitboard-perft-divide` in `perft`).
   SBCL limita una `declaim optimize` fatta in un file alla compilazione di quel file, quindi la
   policy non raggiunge gli altri.
2. **`safety 1`, non `safety 0`.** Con `safety 1` SBCL conserva il controllo dei limiti di ogni
   accesso a un array e un controllo indebolito dei tipi dichiarati. Un indice sbagliato segnala
   un errore invece di scrivere fuori dal vettore. Su questo poggia la disposizione dei buffer di
   mosse ([ADR-0015](0015-generatore-di-mosse-del-livello-ottimizzato.md)): un buffer troppo
   piccolo dà un errore, mai un conteggio sbagliato (test
   `a-buffer-too-small-signals-an-error-not-a-wrong-count`,
   [`tests/test-optimized.lisp`](../../tests/test-optimized.lisp)). `safety 0` non si usa nel
   livello ottimizzato.
3. **Build controllata.** `make test-checked` compila gli stessi file con
   `(optimize (speed 1) (safety 3) (debug 2))` (feature `:scacchiforge-checked`) ed esegue tutte
   le suite. Ogni dichiarazione di tipo è controllata per intero mentre i test girano: è
   l'evidenza che la regola 7 chiede per dire `EXACT` un'ottimizzazione per tipi dichiarati. Si
   esegue quando cambia il hot path. Non fa parte di `make check`. ASDF non sa con quale policy
   è stato compilato un file: ogni file del hot path, quando si carica, controlla di essere
   stato compilato con la policy che l'immagine chiede e altrimenti si ferma con un errore
   (`check-compiled-choice`, [`src/optimized/policy.lisp`](../../src/optimized/policy.lisp)), e
   ogni target che carica il sistema ricompila ogni sistema di `scacchiforge.asd` che carica
   ([`tools/load.lisp`](../../tools/load.lisp)). Un target eseguito dopo `make test-checked`,
   per esempio `make perft-deep`, non usa quindi i file compilati a `safety 3`.
4. **Note e disassembly con un comando.** Nel build le note di efficienza di SBCL sono
   silenziate nei file del hot path. `make hot-path`
   ([`tools/hot-path.lisp`](../../tools/hot-path.lisp)) ricompila quei file, in `build/hot-path/`,
   con le note visibili e stampa: le note; per ogni funzione eseguita a ogni nodo, la lunghezza
   del disassemblato e le chiamate complete, le chiamate di routine (l'aritmetica generica fra
   queste) e le allocazioni che vi sono nominate, dopo aver provato la stessa scansione su
   funzioni piantate; i passi con cui `sb-ext:get-bytes-consed` conta l'allocazione e i byte
   allocati da perft dopo un riscaldamento; il tempo CPU di tre perft in quattro varianti del hot
   path: la policy di default, la stessa con generazione, make e unmake chiamati da `perft-node`
   invece che espansi (punto 6), `safety 0` e la policy controllata. Ogni variante si compila una
   volta; le varianti si eseguono in due passate, in ordine e in ordine inverso, così che una
   deriva della macchina le raggiunga allo stesso modo. Ogni campione ripete la chiamata finché
   dura almeno mezzo secondo di CPU; l'output dà il tempo per chiamata, con mediana, minimo e
   massimo e la mediana di ciascuna passata. Le ultime due parti sono misure della macchina che
   le esegue, non risultati. Chi cambia il hot path esegue `make hot-path` e ne legge l'output.
5. **L'allocazione è un test.** `perft-allocates-nothing-after-warm-up`
   ([`tests/test-optimized.lisp`](../../tests/test-optimized.lisp)) esegue, dopo un
   riscaldamento, perft che fanno e disfano più di un milione di mosse e richiede al più 1 MiB
   allocato. `sb-ext:get-bytes-consed` si muove di un'intera regione di allocazione alla volta, non
   di un oggetto alla volta (`make hot-path` stampa il passo), quindi un'esecuzione breve non
   prova niente; su più di un milione di mosse, un oggetto di 16 byte per mossa darebbe almeno
   16 MB. Il limite vuol dire meno di un byte per mossa.
6. **Le funzioni di nodo espanse nel perft.** `perft-node` espande inline generazione
   pseudo-legale, filtro di legalità, make e unmake; ogni altro chiamante li chiama. Lo decide
   `*inline-node-functions*` ([`src/optimized/policy.lisp`](../../src/optimized/policy.lisp)),
   vera nel build; `make hot-path` compila anche la variante con le chiamate e la misura accanto
   alle altre.

**Classificazione:** la policy non riduce lavoro di per sé. I tipi dichiarati nel hot path sono
`EXACT` se veri (regola 7); l'evidenza è che tutte le suite passano anche con la build
controllata.

**Invarianti:** INV-A4 (la verifica resta possibile: build controllata, controlli dei limiti
sempre presenti), INV-A5 (allocazione quasi nulla: test di allocazione).

**Verifica:** `make check` (policy di default), `make test-checked` (`safety 3`),
`make hot-path` (note, disassemblato, allocazione, tempi).

## Conseguenze

- Un file nuovo del hot path proclama `(declaim-optimized-policy)` prima della sua parte calda,
  con i macro sopra quella riga (punto 1), e si aggiunge a `*hot-path-files*`. `make bench`
  stampa nel registro dell'ambiente la policy di ogni file misurato, compresa questa, e nomina
  una volta ogni file che fa una proclamazione, anche se la fa due volte come `perft`
  ([`benchmarks/system-info.lisp`](../../benchmarks/system-info.lisp)); il build la stampa
  nella riga `build: optimized hot path compiled with`.
- Le note di `make hot-path` segnalano il ritorno di un intero di 64 bit in forma boxed
  («unsigned word to integer coercion» verso il valore restituito). Vengono dalle copie fuori
  linea delle funzioni inline e da `bitboard-checkers`, che non è inline e che il perft non
  chiama (la usano i test differenziali). Nel hot path le funzioni inline sono espanse e non
  allocano: lo mostrano il disassemblato e il test di allocazione. Poiché i macro stanno prima
  della policy, i loro espansori, che girano durante la compilazione, non danno note: una nota
  sotto una riga `in: DEFMACRO` vorrebbe dire che un macro è finito dopo
  `(declaim-optimized-policy)`.
- `make test-checked` non è in `make check` e la CI non lo esegue: una dichiarazione falsa
  introdotta da una modifica la trova solo chi lo esegue.
- Sulla macchina su cui è stato scritto questo ADR (Apple M4, SBCL 2.6.9, macOS), `make hot-path`
  ha dato, per ciascuno dei tre perft che misura e in ciascuna delle due passate, tempi CPU
  minori con `safety 0` che con la policy di default, e maggiori con la policy controllata che
  con quella di default; in ogni riga gli intervalli fra minimo e massimo delle varianti sono
  separati. Su questa macchina la policy controllata costa quindi tempo, in modo costante. La
  variante con le funzioni di nodo chiamate (punto 6) è più lenta del default, con intervalli
  separati. Le cifre non si copiano qui ([QA-14](../limiti-e-rischi.md#qa-14)): `make hot-path`
  le stampa. È la misura di una macchina in un momento; su altre macchine e altre versioni di
  SBCL non è stata eseguita.

## Alternative considerate

- *`(speed 3) (safety 0)`:* scartata. Toglie i controlli dei limiti: un errore diventa una
  scrittura fuori dal vettore invece di un errore segnalato, e la disposizione dei buffer di
  ADR-0015 perde la sua garanzia.
- *La policy controllata come default:* scartata per ora. Ogni esecuzione controllerebbe per
  intero le dichiarazioni, ma sulla macchina citata sopra la policy controllata è più lenta di
  quella di default in ogni riga di `make hot-path` (Conseguenze), e la build controllata dà già
  quel controllo a chi esegue `make test-checked`. Su x86-64 e con la versione di SBCL della CI
  `make hot-path` non è stato eseguito.
- *Nessuna policy dichiarata:* scartata. Il codice dipenderebbe dalla policy globale
  dell'immagine che compila, che il repository non controlla.
- *Una `declaim optimize` scritta a mano in ogni file:* scartata. La build controllata
  richiederebbe di cambiare ogni file; con un solo punto la cambia una feature.

## Valutazione

- Rischio: una dichiarazione falsa che la policy di default non controlla per intero; la
  controlla `make test-checked`, se eseguito.
- L'espansione delle funzioni di nodo (punto 6) è una scelta di velocità che non cambia che cosa
  si calcola; non ha un record di ricerca, e come le si applica INV-X3 è
  [QA-17](../limiti-e-rischi.md#qa-17).
- Porterebbe a rivedere la decisione: `make hot-path`, su più macchine e versioni di SBCL, che
  mostri la policy controllata non distinguibile da quella di default, con intervalli che si
  sovrappongono in ogni riga (sulla macchina misurata oggi sono separati, e la controllata è più
  lenta): allora può diventare il default; oppure un hot path della ricerca in cui `safety 1`
  costi molto più di `safety 0` e i controlli dei limiti si possano garantire in altro modo, con
  una dimostrazione.
