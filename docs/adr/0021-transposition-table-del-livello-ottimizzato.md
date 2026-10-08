# ADR-0021 — Transposition table del livello ottimizzato

- **Stato:** Proposta
- **Data:** 2026-10-08
- **Rapporto con la specifica:** proposta nuova (non nella specifica); applica «TRANSPOSITION
  TABLE» (*game tree → game graph*; la collisione o la perdita di una entry non deve mai
  compromettere la correttezza; diverse dimensioni e politiche di sostituzione, senza assumere che
  più memoria renda di più) e «DEDUPLICATION» (memoization) nel livello ottimizzato, per il gate
  della [Fase 3](../roadmap.md#fase-3). Propone le opzioni di default per
  [QA-01](../limiti-e-rischi.md#qa-01) e [QA-02](../limiti-e-rischi.md#qa-02), che restano aperte
  finché l'autore non decide.
- **Riferimenti:** [classificazione](../classificazione.md#ipotesi-della-transposition-table)
  (TT-1…TT-4), [verifica](../verifica.md#modalità-di-verifica-della-tt),
  [architettura](../architettura.md#deduplicazione), [misure](../misure.md), INV-C5, INV-C6,
  INV-A5, INV-X3, INV-X7, [QA-01](../limiti-e-rischi.md#qa-01),
  [QA-02](../limiti-e-rischi.md#qa-02), [QA-05](../limiti-e-rischi.md#qa-05), RSK-04,
  [ADR-0005](0005-chiavi-zobrist-da-prng-deterministico.md),
  [ADR-0010](0010-regole-di-indipendenza-tra-i-livelli.md),
  [ADR-0011](0011-convenzioni-di-classificazione.md),
  [ADR-0014](0014-policy-di-compilazione-del-livello-ottimizzato.md),
  [ADR-0017](0017-percorso-di-ricerca-per-le-alternative-exact.md),
  [ADR-0022](0022-pvs-negascout-e-tipi-di-nodo.md),
  [ADR-0023](0023-ordinamento-delle-mosse-della-fase-3.md),
  [EXP-0003](../../research/exp-0003-ricerca-della-fase-3.md)

## Contesto

Il gate della Fase 3 chiede che, in modalità di verifica, la ricerca con la TT restituisca il
valore della ricerca senza TT, che i falsi riscontri siano scartati e contati e che la mossa TT
sia controllata come legale (INV-C5, INV-C6); chiede anche di misurare hit rate, costo della
lookup, diverse dimensioni e politiche di sostituzione. Le ipotesi TT-1…TT-4 sono del repository e
accettate ([ADR-0011](0011-convenzioni-di-classificazione.md)); la modalità di verifica era una
proposta di [verifica](../verifica.md#modalità-di-verifica-della-tt) senza codice. La specifica
non dice come si tratta la storia né come si rende innocua una collisione di chiave: sono
[QA-02](../limiti-e-rischi.md#qa-02) e [QA-01](../limiti-e-rischi.md#qa-01), aperte. Il passaggio
alla Fase 3 è una decisione dell'autore del 2026-10-08.

## Decisione

> **Proposta** — Proposta del repository, in attesa della decisione dell'autore.

1. **Codice proprio.** La TT è del livello ottimizzato, in
   [`src/optimized/transposition.lisp`](../../src/optimized/transposition.lisp), un file del hot
   path ([ADR-0014](0014-policy-di-compilazione-del-livello-ottimizzato.md)). Il riferimento non
   ha una TT: il riferimento giudica il valore delle ricerche che la usano, come per ogni altra
   ricerca del livello ottimizzato ([ADR-0010](0010-regole-di-indipendenza-tra-i-livelli.md)).
2. **Entry compatte in array tipizzati.** Due vettori preallocati di `(unsigned-byte 64)`, uno
   slot per elemento: la chiave intera e una parola di dati che impacchetta la mossa migliore (20
   bit, la mossa packed del `core`), il punteggio relativo al nodo (16 bit), la profondità (7
   bit), il tipo di bound (2 bit: esatto, inferiore, superiore; 0 indica uno slot vuoto) e la
   generazione della ricerca che l'ha scritta (8 bit). 16 byte per slot. Il bucket di una chiave
   sono i suoi bit bassi.
3. **Dimensione e politica come argomenti.** `make-bitboard-transposition-table` prende il numero
   di slot (una potenza di due, da 2 a 2^30; 65536 se manca), la politica di sostituzione e la
   modalità: non si cambia il codice per cambiarle (INV-X7 per questi parametri). Le politiche
   sono tre:
   - `:always`: uno slot per bucket, sempre sostituito;
   - `:depth-preferred`: uno slot per bucket, sostituito se è vuoto, se viene da una ricerca
     precedente (un'altra generazione) o se la nuova entry è profonda almeno quanto la vecchia;
     altrimenti la nuova non si scrive;
   - `:two-slot` (il default): due slot per bucket, il primo come `:depth-preferred`, il secondo
     prende ogni entry che il primo rifiuta.

   Lo slot che contiene la stessa posizione si riscrive sempre.
4. **Due modalità.** `:normal`, quella del gioco: la ricerca può tagliare su una entry profonda
   almeno quanto il nodo. `:verification`, quella di
   [verifica](../verifica.md#modalità-di-verifica-della-tt), usata dai test e dalla firma, mai
   dal gioco: la ricerca taglia solo su una entry della stessa profondità del nodo (TT-1), e ogni
   slot conserva un controllo indipendente della posizione, nove parole (le sei bitboard per tipo
   di pezzo, le due occupazioni per colore, una parola con lato al tratto, diritti di arrocco e
   casa en passant come la chiave la conta), 72 byte in più per slot. Uno slot con la chiave
   uguale e il controllo diverso è un falso riscontro: si scarta e si conta (TT-3).
5. **Sonda e inserimento** stanno nel hot path e non allocano. Una maschera di chiave, tutta a
   uno se non la imposta un test, si applica alla chiave prima dell'indice e del confronto: con
   pochi bit forza falsi riscontri.
6. **Uso nella ricerca** ([ADR-0022](0022-pvs-negascout-e-tipi-di-nodo.md)). Una entry si usa
   per un taglio solo sotto la radice, solo con una profondità ammessa dalla modalità e solo come
   il bound che è: un punteggio esatto fuori dalla finestra o sul suo bordo, un bound inferiore a
   beta o sopra, uno superiore ad alpha o sotto. Un punteggio esatto strettamente dentro una
   finestra aperta non taglia: così ogni nodo di una variante principale esatta si cerca, e la
   variante resta intera. I punteggi di matto si scrivono relativi al nodo e si convertono alla
   lettura. La mossa TT serve solo all'ordinamento
   ([ADR-0023](0023-ordinamento-delle-mosse-della-fase-3.md)), e solo se è fra le mosse legali
   che il generatore ha scritto per il nodo: una mossa che non c'è si scarta e si conta, e la
   ricerca esegue solo mosse del generatore (INV-C6).
7. **QA-01, default proposto.** La chiave intera di 64 bit si confronta a ogni sonda; la mossa TT
   si controlla come legale prima dell'uso (punto 6); in modalità di verifica ogni slot ha il
   controllo indipendente del punto 4, e un falso riscontro si scarta e si conta. In modalità
   normale un falso riscontro della chiave intera resta possibile (`[PROBABILISTIC]`,
   [ADR-0005](0005-chiavi-zobrist-da-prng-deterministico.md)): può cambiare un valore, mai far
   eseguire una mossa illegale. QA-01 resta aperta: decide l'autore.
8. **QA-02, default proposto.** La ricerca non rileva ripetizioni né la regola delle cinquanta
   mosse, quindi nessun valore memorizzato dipende dal percorso, e TT-2 vale; gli orologi stanno
   fuori dalla chiave. La TT non memorizza nessun punteggio che dipende dalla storia. QA-02 resta
   aperta per quando la ricerca rileverà le ripetizioni: allora una di queste opzioni dovrà
   cambiare.
9. **Statistiche.** La tabella conta sonde, riscontri, falsi riscontri, riscontri con una
   profondità usabile, tagli, inserimenti fatti e rifiutati, sostituzioni di un'altra posizione,
   mosse TT cercate per prime e mosse TT scartate perché non legali.

**Classificazione:**

- TT con bound esatto, inferiore e superiore, in modalità di verifica: `[EXACT]` sotto
  TT-1…TT-4 (la ricerca con la TT restituisce il valore della ricerca senza); in modalità normale
  `[HEURISTIC]` sul valore a profondità fissa (il riuso di entry più profonde) e `[PROBABILISTIC]`
  per l'identificazione della posizione dalla chiave.
- Politiche di sostituzione: `[EXACT]` sotto TT-1…TT-4; l'efficacia `[EMPIRICAL]`, da misurare
  ([EXP-0003](../../research/exp-0003-ricerca-della-fase-3.md)).
- Il controllo indipendente della modalità di verifica: `[EXACT]`, nessuna collisione.

I docstring di `bitboard-tt-probe`, `bitboard-tt-store` e `search-node` portano le etichette.

**Invarianti:** INV-C5 (la lettura operativa proposta: in modalità di verifica la perdita e la
collisione di una entry non cambiano il valore), INV-C6, INV-A5 (sonda e inserimento non
allocano), INV-X7 (dimensione e politica come argomenti). **INV-X3** non è soddisfatto: la TT
cambia i nodi di una ricerca, un'uscita, quindi vale il percorso intero di
[research](../../research/README.md), compresi self-play e validazione statistica, che non sono
stati fatti (non esiste un'infrastruttura di self-play: Fase 10). Il record è
[EXP-0003](../../research/exp-0003-ricerca-della-fase-3.md), Proposto. Un ADR in stato Proposta
non esenta da un invariante Deciso: è uno scostamento dichiarato, come lo erano EXP-0001 ed
EXP-0002.

**Verifica:** la suite `optimized-tt` di `make test`
([verifica](../verifica.md#modalità-di-verifica-della-tt)): la parola di dati, gli argomenti, le
tre politiche sulle loro regole, ogni entry lasciata da una ricerca come bound vero del valore
della sua posizione, la modalità di verifica contro la ricerca senza TT con tabelle da 2 a 65536
slot, falsi riscontri forzati scartati e contati, mosse di altre posizioni e entry alterate mai
eseguite, una posizione raggiunta per due percorsi; il test di allocazione della suite
`optimized-pvs`; le righe di `make bench` per dimensioni e politiche, hit rate e costo della
lookup.

## Conseguenze

- La memoria di una tabella è un argomento: 16 byte per slot, 88 in modalità di verifica. Una
  tabella si alloca una volta; la ricerca non alloca. Che cosa costi tenere grandi array al GC e
  all'RSS durante una ricerca a tempo non è misurato: [QA-05](../limiti-e-rischi.md#qa-05) resta
  aperta. Le righe di `make bench` stampano i millisecondi di GC di ogni riga.
- La firma di ricerca registra la ricerca di default con la TT in modalità di verifica
  ([ADR-0022](0022-pvs-negascout-e-tipi-di-nodo.md)): il valore è quello di alpha-beta, e lo
  giudica il riferimento. La modalità normale non è nella firma: il suo valore a profondità fissa
  non è garantito, e la esercitano i test di legalità e di robustezza e le righe di `make bench`.
- Non esiste ancora un ciclo di gioco: la modalità normale la usano solo i test e i benchmark.
- Una ricerca senza TT paga un controllo per nodo sulla presenza della tabella.

## Alternative considerate

- *Chiave parziale nella entry* (per esempio 32 bit): metà della memoria per le chiavi, più
  falsi riscontri, `[PROBABILISTIC]` con un rischio che cresce con i bit tolti. Scartata per ora:
  QA-01 propone la chiave intera.
- *Un vettore per campo* (mossa, punteggio, profondità separati): più vettori e più linee di
  cache per sonda. Scartata.
- *Bucket di quattro slot con invecchiamento*: più complessa da verificare; si può misurare dopo,
  contro le tre politiche di oggi.
- *Una seconda chiave Zobrist indipendente come controllo*: chiederebbe una seconda chiave
  incrementale in make e unmake, pagata da ogni ricerca e dal perft; il controllo sulle bitboard
  non ha collisioni e costa solo in modalità di verifica. Scartata.
- *Riuso di entry più profonde anche in modalità di verifica*: viola TT-1, e il valore non è più
  quello della ricerca a profondità fissa.
- *Tagli alla radice*: la ricerca resterebbe senza mossa migliore né variante. Scartata.
- *Tagli su un punteggio esatto anche dentro la finestra*: la variante principale si
  interromperebbe al nodo tagliato. Scartata.

## Valutazione

- Rischi: RSK-04 (collisioni e storia: la modalità di verifica, la mossa TT controllata e le
  etichette oneste), RSK-02 (GC durante una ricerca: [QA-05](../limiti-e-rischi.md#qa-05)).
- Si verifica con la suite `optimized-tt` su ogni piattaforma su cui `make check` gira, e con
  `make differential-deep` per il valore della ricerca di default contro il riferimento.
- Porterebbero a rivedere la decisione: un falso riscontro della chiave intera in modalità di
  verifica, che direbbe che le chiavi non si comportano come il modello di ADR-0005; righe di
  `make bench` in cui la tabella costa più del lavoro che risparmia (la regola di
  [architettura](../architettura.md#deduplicazione)); la rilevazione delle ripetizioni, che
  riapre QA-02; l'esito di [EXP-0003](../../research/exp-0003-ricerca-della-fase-3.md).
