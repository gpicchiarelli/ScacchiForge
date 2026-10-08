# Glossario

## Convenzione linguistica

- La documentazione è in italiano. I termini tecnici consolidati restano in inglese: sono quelli
  che questo glossario scrive in inglese nella colonna «Termine», per esempio perft, make/unmake,
  bitboard, TT, NPS, SEE, LMR, NNUE, SPRT, null move, profiling, hot path. Questo è l'unico
  elenco: gli altri documenti vi rimandano.
- Una forma per termine. «Null move» e «profiling» restano in inglese; «casa», non «casella»,
  per una delle 64 case; «invariante» è maschile («gli invarianti»).
- Il codice, gli identificativi, i docstring e i nomi dei test sono in inglese.
- Le sette etichette di [classificazione](classificazione.md) si scrivono in maiuscolo e in inglese:
  `THEOREM`, `EXACT`, `BOUNDED`, `PROBABILISTIC`, `HEURISTIC`, `EMPIRICAL`, `LEARNED`.
- I tipi di bound della TT si scrivono in maiuscolo: `EXACT`, `LOWERBOUND`, `UPPERBOUND`.
  `EXACT` è anche un'etichetta di classificazione: il contesto dice quale.

## Ricerca

| Termine | Definizione |
|---|---|
| **valore minimax** (*minimax value*) | `V(s) = max/min V(s')`: il valore di una posizione se entrambe le parti giocano al meglio. A profondità finita è il valore dell'albero troncato, con la valutazione statica alle foglie. |
| **negamax** | Forma di minimax che usa un solo ramo di codice: il valore è dato dal punto di vista di chi muove e si nega a ogni livello. |
| **alpha-beta** | Ricerca minimax con una finestra (α, β) di valori ancora rilevanti. Smette di esaminare un nodo quando le mosse restanti non possono cambiare il risultato. Con finestra piena restituisce il valore minimax. |
| **finestra piena** | La finestra (−∞, +∞). In questi documenti non indica la finestra (α, β) di un nodo. |
| **taglio beta** (*beta cutoff*) | Interruzione dell'esame delle mosse di un nodo perché una mossa ha dato un valore ≥ β. |
| **fail-high, fail-low** | Il risultato è ≥ β (limite inferiore del valore) oppure ≤ α (limite superiore). |
| **iterative deepening** | Ricerca a profondità 1, 2, …, d, ognuna sfruttando ciò che ha lasciato la precedente (TT, variante principale). |
| **finestra di aspirazione** (*aspiration window*) | Ricerca alla radice con una finestra stretta attorno al valore atteso. Se il risultato cade fuori dalla finestra o sul suo bordo (≤ α o ≥ β), si ripete con una finestra più larga. |
| **ricerca a finestra nulla** (*null-window search*) | Ricerca con finestra (α, α+1) su punteggi interi: risponde soltanto a «il valore supera α?». |
| **PVS, NegaScout** | *Principal Variation Search*. La prima mossa si cerca con la finestra (α, β) del nodo, le altre a finestra nulla; se una restituisce α < v < β, si ricerca con la finestra (α, β). NegaScout è la stessa idea. Oggi nel livello ottimizzato NegaScout ne differisce in due punti: la ri-ricerca parte da v − 1 invece che da α, e un risultato già esatto non si ricerca ([ADR-0022](adr/0022-pvs-negascout-e-tipi-di-nodo.md), Proposta). |
| **MTD(f)** | Sequenza di ricerche a finestra nulla che converge al valore minimax, appoggiandosi alla TT. |
| **SSS\*, DUAL\*** | Algoritmi di ricerca *best-first* a profondità fissa. |
| **transposition-driven search** | Termine della specifica. In letteratura indica uno schema di ricerca distribuita guidato dalla TT (*transposition-table-driven work scheduling*, Romein e altri, 2002, in [classificazione](classificazione.md#riferimenti)): ogni posizione si affida al processore che possiede la sua entry. È la lettura candidata; il significato per il progetto è aperto: [QA-13](limiti-e-rischi.md#qa-13). |
| **variante principale** (*principal variation*, PV) | La sequenza di mosse migliori per entrambe le parti, secondo la ricerca. |
| **nodo PV** (*PV node*) | Nodo con finestra aperta (β − α > 1) il cui valore sarà esatto; sta sul cammino della variante principale. Tipo 1 di Knuth e Moore. |
| **nodo Cut** (*Cut node*) | Nodo in cui ci si aspetta un taglio beta: basta una mossa buona, quindi l'ordinamento conta. Tipo 2. |
| **nodo All** (*All node*) | Nodo in cui ci si aspetta che nessuna mossa superi α: vanno esaminate tutte; il valore è un limite superiore. Tipo 3. |
| **ordinamento delle mosse** (*move ordering*) | L'ordine in cui si provano le mosse. In alpha-beta puro non cambia il valore, cambia i nodi. |
| **effetto orizzonte** (*horizon effect*) | Errore dovuto alla profondità finita: una perdita inevitabile spostata oltre l'orizzonte sembra evitata. |
| **quiescenza** (*quiescence search*) | Ricerca di foglia che esamina solo mosse rumorose (catture, promozioni, a volte scacchi) finché la posizione è quieta. Definisce il valore della foglia. |
| **stand-pat** | In quiescenza, usare la valutazione statica come limite inferiore: chi muove può non catturare. |
| **null move** | Passare il turno. Se anche così, con profondità ridotta, il valore resta ≥ β, si taglia. |
| **zugzwang** | Posizione in cui chi muove starebbe meglio passando. È il caso in cui il null move sbaglia. |
| **verification search** | Ricerca a profondità ridotta, senza null move, che conferma un taglio ottenuto con il null move. |
| **futility pruning** | A profondità bassa, se valutazione statica più margine non supera α, si saltano le mosse tranquille. |
| **reverse futility** | A profondità bassa, se valutazione statica meno margine supera β, si taglia senza cercare. |
| **razoring** | A profondità bassa, se la valutazione statica è molto sotto α, si passa a una quiescenza di verifica invece di cercare a fondo. |
| **LMR** | *Late Move Reductions*. Le mosse tardive nell'ordine si cercano a profondità ridotta; se superano α si ricercano a profondità piena. La specifica chiede una riduzione `R` funzione di molti segnali, non una soglia. |
| **ProbCut** | Taglio basato su un modello statistico: una ricerca poco profonda predice il valore di quella profonda con una dispersione stimata. |
| **singular extension** | Estende la mossa TT se, con quella mossa esclusa, tutte le alternative risultano peggiori di un margine in una ricerca ridotta. |
| **check extension** | Estensione di profondità quando chi muove è sotto scacco. |
| **delta pruning** | In quiescenza, si saltano le catture che, col valore del pezzo preso più un margine, non portano il valore sopra α. |
| **SEE** | *Static Exchange Evaluation*. Stima senza ricerca dell'esito di una serie di catture su una casa, assumendo che ogni parte catturi con il pezzo meno prezioso e possa fermarsi. Entrano nello scambio anche i pezzi a lunga gittata che si scoprono dietro chi cattura (raggi X). |
| **killer move** | Mossa tranquilla che ha causato un taglio in un nodo fratello alla stessa distanza dalla radice. |
| **history heuristic** | Tabella che accumula quanto spesso una mossa tranquilla ha causato tagli, usata per ordinare. |
| **countermove** | Mossa che ha confutato la mossa precedente dell'avversario. |
| **continuation history** | History condizionata dalle mosse precedenti. |
| **QNodes** | Nodi visitati dalla quiescenza. |
| **branching factor** | Numero medio di figli di un nodo; quello *effettivo* si ricava dalla crescita dei nodi con la profondità. La definizione usata va dichiarata ([misure](misure.md#metriche-da-definire-una-volta)). |

## Transposition table e hashing

| Termine | Definizione |
|---|---|
| **TT** (*transposition table*) | Tabella indicizzata dalla chiave Zobrist che memorizza risultati di ricerca (valore, profondità, tipo di bound, mossa migliore, generazione) per riusarli quando la stessa posizione si ripresenta. Trasforma l'albero di gioco in un grafo. |
| **bound** | Il tipo di valore memorizzato: `EXACT` (valore esatto), `LOWERBOUND` (valore ≥ memorizzato), `UPPERBOUND` (valore ≤ memorizzato). |
| **chiave Zobrist** (*Zobrist key*) | Hash di una posizione: XOR di chiavi casuali, una per ogni caratteristica (pezzo su casa, lato al tratto, diritti di arrocco, en passant). Si aggiorna in modo incrementale. |
| **collisione, falso riscontro** | Due posizioni diverse con la stessa chiave, o con gli stessi bit di chiave confrontati. |
| **politica di sostituzione** (*replacement policy*) | Quale entry cede il posto a una nuova. |
| **generazione** (*generation*) | Contatore che marca le entry di una ricerca, per riconoscere le vecchie. |
| **hit rate** | Frazione di sonde che trova una entry. |
| **GHI** | *Graph history interaction*. Il valore di una posizione dipende dal percorso (ripetizioni, regola delle cinquanta mosse), ma la TT la identifica solo dalla posizione. |

## Generazione delle mosse e rappresentazione

| Termine | Definizione |
|---|---|
| **casa** (*square*) | Una delle 64 case della scacchiera. |
| **bitboard** | Intero a 64 bit in cui ogni bit è una casa della scacchiera. |
| **magic bitboard** | Tecnica che calcola gli attacchi dei pezzi a lunga gittata con una moltiplicazione per un numero «magico» e un indice in una tabella precalcolata. |
| **PEXT** | Istruzione BMI2 (*parallel bit extract*) che estrae i bit di un valore scelti da una maschera. Usata come indice diretto nelle tabelle di attacco al posto della moltiplicazione magica. |
| **POPCNT** | Conta i bit a 1 di un intero. |
| **pseudo-legale, legale** | Una mossa pseudo-legale rispetta il movimento dei pezzi. È legale se non lascia il proprio re sotto scacco e, per l'arrocco, se il re non parte, non passa e non arriva su una casa attaccata. |
| **inchiodatura** (*pin*) | Un pezzo che non può lasciare una linea senza esporre il proprio re. |
| **scacco scoperto** (*discovered check*) | Scacco dato da un pezzo che si scopre quando un altro si muove. |
| **doppio scacco** (*double check*) | Re sotto scacco da due pezzi: l'unica risposta è muovere il re. |
| **en passant** | Cattura di un pedone che ha appena fatto una spinta doppia, come se si fosse fermato una casa prima. |
| **make/unmake** | Eseguire una mossa sulla posizione e annullarla, senza copiare la posizione, con uno stack di stato preallocato. |
| **`Move` packed** | Mossa codificata in un solo intero, senza oggetti allocati. |
| **FEN** | Notazione testuale di una posizione. |
| **perft** | Conteggio delle foglie dell'albero delle mosse legali a una data profondità. È un gate. |
| **`divide`** | Perft diviso per mossa radice, per localizzare gli errori. |
| **riferimento, oracolo** (*reference implementation, oracle*) | Implementazione volutamente semplice, contro cui si verifica l'engine ottimizzato. |

## Valutazione e addestramento

| Termine | Definizione |
|---|---|
| **valutazione statica** | `Eθ(s)`: un punteggio per una posizione, senza ricerca. |
| **PST** | *Piece-square table*: un valore per ogni coppia (pezzo, casa). |
| **centipawn** | Un centesimo del valore di un pedone: l'unità dei punteggi della valutazione. |
| **fase della partita** (*game phase*) | Quanto materiale non di pedone resta sulla scacchiera; in [valutazione](valutazione.md#fase-della-partita) va da 0 (finale di soli re e pedoni) a 62 (posizione iniziale). |
| **miscela fra mediogioco e finale** (*tapered evaluation*) | Media, pesata con la fase, di un punteggio di mediogioco e di uno di finale. L'arrotondamento è definito in [valutazione](valutazione.md#miscela-e-arrotondamento). |
| **pedone passato, isolato, doppiato, arretrato** (*passed, isolated, doubled, backward pawn*) | Le definizioni esatte usate dalla valutazione sono in [valutazione](valutazione.md#struttura-pedonale) e nella sezione che la segue. |
| **NNUE** | *Efficiently Updatable Neural Network*. Rete il cui primo strato dipende da feature sparse e si aggiorna incrementalmente a ogni mossa. |
| **accumulatore** (*accumulator*) | Il vettore di uscita del primo strato di una NNUE. Una mossa aggiunge e toglie le colonne dei pesi delle feature cambiate. |
| **feature** | Un ingresso binario della rete, per esempio «pezzo X sulla casa Y». |
| **quantizzazione** (*quantization*) | Rappresentazione di pesi e attivazioni con interi di poche cifre binarie. |
| **tuning alla Texel** (*Texel tuning*) | Taratura dei pesi della valutazione minimizzando l'errore quadratico tra l'esito delle partite e una funzione logistica del punteggio, su posizioni etichettate. |
| **SPSA** | *Simultaneous Perturbation Stochastic Approximation*. Stima il gradiente perturbando tutti i parametri insieme, con due valutazioni per iterazione. |

## Hardware e piattaforma

| Termine | Definizione |
|---|---|
| **SIMD** | Un'istruzione che opera su più dati insieme. |
| **AVX2, AVX-512, VNNI** | Insiemi di istruzioni SIMD x86 (VNNI per prodotti scalari su interi). |
| **NEON, SVE, SVE2** | Insiemi di istruzioni SIMD ARM. |
| **BMI2** | Estensione x86 con PEXT e PDEP. |
| **dispatch CPU** | Scelta a runtime dell'implementazione in base alle funzioni della CPU rilevate. |
| **fallback** | L'implementazione generica che c'è sempre. |
| **FFI, microkernel nativo** | Chiamata di codice non Lisp; un kernel isolato scritto in tale codice. Ammesso solo alle cinque condizioni della specifica. |
| **Lazy SMP** | Ricerca parallela in cui più thread cercano la stessa radice quasi indipendenti, comunicando soprattutto tramite la TT. |
| **NUMA** | Memoria non uniforme: il costo di accesso dipende dal socket. |
| **false sharing** | Thread che scrivono dati distinti nella stessa linea di cache e si rallentano a vicenda. |
| **hot path** | Il codice eseguito per ogni nodo di ricerca. |
| **boxing** | Rappresentare un valore primitivo (per esempio un intero a 64 bit) come oggetto allocato, quando non può restare in un registro o in una struttura tipizzata. |
| **consing** | Allocare memoria nello heap di Lisp. Nel hot path si evita perché carica il GC. |
| **GC** | *Garbage collector*. |

## Misura e metodo

| Termine | Definizione |
|---|---|
| **NPS** | Nodi al secondo. L'ultima delle metriche ([misure](misure.md#gerarchia-delle-metriche)). |
| **Elo** | Misura della differenza di forza tra due giocatori, ricavata dal punteggio in un confronto. |
| **SPRT** | *Sequential Probability Ratio Test*. Test sequenziale con errori `α` e `β` dichiarati, che decide quando fermarsi. |
| **intervallo di confidenza** | Procedura che produce intervalli i quali, su campioni ripetuti, contengono il valore vero con la frequenza dichiarata, sotto le ipotesi del modello. Di un singolo intervallo non si dice che contenga il valore con quella probabilità. |
| **profiling** | Misura di dove un programma spende tempo o memoria, per funzione o per istruzione. Serve a trovare gli hot spot prima di ottimizzare. |
| **self-play** | Partite tra versioni dell'engine per misurare differenze di forza. |
| **firma di ricerca** (*search signature*) | Valore, mossa, nodi e variante principale a profondità fissa su una suite: la parte logica del comportamento della ricerca ([verifica](verifica.md#regressione-di-ricerca)). |
| **baseline** | Risultati di riferimento, con il loro ambiente, a cui si confronta una modifica. |
| **microbenchmark, benchmark di engine** | I due livelli di misura ([misure](misure.md#due-livelli-di-benchmark)). |
| **registro dell'ambiente** | I dati che rendono riproducibile una misura. |
| **corpus** | L'insieme di posizioni per regressione, profiling, addestramento e tuning. |

## Documentazione del progetto

| Termine | Definizione |
|---|---|
| **etichetta, classificazione** | Una delle sette etichette che dicono che cosa si può affermare di una riduzione di lavoro ([classificazione](classificazione.md)). |
| **gate** | Condizione da soddisfare per chiudere una modifica o una fase ([verifica](verifica.md), [roadmap](roadmap.md)). |
| **ADR** | *Architecture Decision Record*. Registra una decisione ([ADR](adr/README.md)). |
| **invariante** (`INV-…`) | Regola che nessuna implementazione può violare ([invarianti](invarianti.md)). Maschile: «gli invarianti». |
| **QA** (`QA-nn`) | Questione aperta, con l'esperimento o la decisione (ADR) che la chiude ([limiti-e-rischi](limiti-e-rischi.md#questioni-aperte)). |
| **record di ricerca** (`EXP-nnnn`) | Registro di un esperimento ([research](../research/README.md)). |
