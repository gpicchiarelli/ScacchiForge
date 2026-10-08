# ADR-0022 — PVS, NegaScout, tipi di nodo e ricerca di default della Fase 3

- **Stato:** Proposta
- **Data:** 2026-10-08
- **Rapporto con la specifica:** proposta nuova (non nella specifica); applica «SEARCH
  FOUNDATION» (PVS e NegaScout da implementare e confrontare, nessun algoritmo migliore a priori),
  «SEARCH TREE CLASSIFICATION» (nodi PV, Cut e All espliciti) e il gate della
  [Fase 3](../roadmap.md#fase-3); applica [ADR-0019](0019-valutazione-e-ricerca-del-livello-ottimizzato.md)
  (firma di ricerca) alla ricerca della Fase 3.
- **Riferimenti:** [architettura](../architettura.md#ricerca),
  [classificazione](../classificazione.md#ricerca-di-base),
  [verifica](../verifica.md#regressione-di-ricerca), [misure](../misure.md), INV-C1, INV-A5,
  INV-X3, [QA-11](../limiti-e-rischi.md#qa-11),
  [ADR-0019](0019-valutazione-e-ricerca-del-livello-ottimizzato.md),
  [ADR-0021](0021-transposition-table-del-livello-ottimizzato.md),
  [ADR-0023](0023-ordinamento-delle-mosse-della-fase-3.md),
  [EXP-0003](../../research/exp-0003-ricerca-della-fase-3.md)

## Contesto

Il gate della Fase 3 chiede che PVS e NegaScout restituiscano il valore di alpha-beta e che il tipo
di nodo (PV, Cut, All) sia esplicito nella ricerca e registrato, atteso prima di cercare il nodo e
osservato dopo ([architettura](../architettura.md#ricerca)). La classificazione dei nodi non ha
una fase nella specifica ([QA-11](../limiti-e-rischi.md#qa-11)); la [roadmap](../roadmap.md#senza-fase)
propone che entri con PVS. Le ricerche della Fase 2 (negamax, alpha-beta, iterative deepening,
[ADR-0019](0019-valutazione-e-ricerca-del-livello-ottimizzato.md)) restano le baseline. La firma
di ricerca registra oggi alpha-beta senza TT né ordinamento: con la Fase 3 cambia la ricerca che
si vuole proteggere da cambi non voluti, e occorre dire quale registra.

## Decisione

> **Proposta** — Proposta del repository, in attesa della decisione dell'autore.

1. **Il nodo della Fase 3.** `search-node`
   ([`src/optimized/search.lisp`](../../src/optimized/search.lisp)) cerca un nodo con uno di tre
   schemi di finestra, scelto per la ricerca: alpha-beta (ogni mossa con la finestra del nodo),
   PVS (la prima mossa con la finestra del nodo, ogni altra con la finestra nulla `(a, a + 1)`,
   `a` l'alpha corrente, e di nuovo con `(a, β)` se il risultato cade strettamente dentro) e
   NegaScout (punto 2). Fail-soft, con le convenzioni della ricerca del riferimento. Può ordinare
   le mosse ([ADR-0023](0023-ordinamento-delle-mosse-della-fase-3.md)) e usare la TT
   ([ADR-0021](0021-transposition-table-del-livello-ottimizzato.md)). Le baseline,
   `negamax-node` e `alpha-beta-node`, restano quelle della Fase 2, invariate: una ricerca
   `:alpha-beta` senza ordinamento, TT, tipi di nodo né aggancio d'ordine esegue
   `alpha-beta-node`. Gli algoritmi si scelgono con un argomento (`:negamax`, `:alpha-beta`,
   `:pvs`, `:negascout`).
2. **NegaScout come variante propria.** Differisce da PVS in due punti (Reinefeld, 1983):
   - la finestra della ri-ricerca è `(s − 1, β)`, con `s` il risultato della ricerca a finestra
     nulla, invece di `(a, β)`. Il valore è almeno `s`, quindi cade strettamente dentro, salvo
     che sia almeno `β`, e la variante trovata è esatta. Reinefeld usa `(s, β)`: un valore
     uguale a `s` cadrebbe sul bordo, e la variante sotto quel figlio non sarebbe esatta; il
     punto in meno è la sola differenza da quella forma;
   - una mossa non si ricerca quando il suo risultato è già esatto: quando il figlio è una
     foglia (profondità 0), o quando è a profondità 1, ha cercato le sue mosse (la sua variante
     non è vuota) e ha fallito in basso, così che il risultato è il massimo di valutazioni
     esatte delle foglie.

   Dove coincidono: nei nodi a finestra nulla nessuna delle due ricerca di nuovo; quando
   `s = a + 1` le due finestre di ri-ricerca sono uguali. Il test
   `optimized-pvs/pvs-and-negascout-differ` mostra che sulle posizioni di ricerca sono due ricerche
   diverse (ri-ricerche e nodi).
3. **Tipi di nodo.** Ogni nodo riceve il tipo atteso prima di essere cercato, con la regola di
   Knuth e Moore: la radice è PV; il primo figlio di un nodo PV è PV, gli altri Cut; ogni figlio
   di un nodo Cut è All; ogni figlio di un nodo All è Cut; una ri-ricerca è PV. Il tipo osservato
   viene dal risultato e dalla finestra: Cut a `β` o sopra, All ad `α` o sotto, PV strettamente
   dentro. La ricerca conta i nove accoppiamenti in un vettore preallocato del contesto; le
   statistiche della ricerca li restituiscono. Nella Fase 3 nessuna finestra, nessun ordinamento e
   nessun taglio dipende dal tipo di nodo: si registra e si misura. Le baseline non lo
   registrano; una ricerca `:alpha-beta` lo registra con `:node-types`, eseguendo `search-node`.
4. **Iterative deepening** su ogni algoritmo. Ogni iterazione è una ricerca completa della sua
   profondità; alla successiva passa, con l'ordinamento, la variante principale (la mossa PV,
   cercata per prima a ogni nodo di quella linea) e, con una TT, le entry, che danno la mossa TT
   e i tagli che la modalità ammette; la TT tiene una generazione per tutta la corsa.
5. **Ricerca di default della Fase 3** (`*bitboard-default-search*`, `bitboard-default-search`):
   iterative deepening di PVS con l'ordinamento della Fase 3 e una TT nuova di 65536 slot con la
   politica a due slot. La modalità della TT la sceglie chi chiama: normale per il gioco, di
   verifica per i test e per la firma. Le funzioni `bitboard-search` e
   `bitboard-iterative-deepening` senza argomenti restano le baseline di alpha-beta, come nella
   Fase 2.
6. **Firma di ricerca.** [`tests/search-signature.sexp`](../../tests/search-signature.sexp)
   (formato 2) registra due ricerche alla stessa profondità sulle stesse posizioni: alpha-beta
   della Fase 2 (`:entries`, invariata) e la ricerca di default della Fase 3 con la TT in modalità
   di verifica (`:default-search`, `:default-entries`; il numero di nodi è la somma delle
   iterazioni). Le due hanno lo stesso valore, e un test lo controlla; il riferimento rigioca le
   varianti delle due, e in `make differential-deep` ne confronta i valori con il proprio
   alpha-beta. Lo scrive solo `make signatures`; una modifica dell'ordinamento, della TT o degli
   schemi di finestra cambia i nodi della seconda, non il valore.
7. **Statistiche** di una ricerca: nodi, tagli beta, tagli alla prima mossa, nodi sotto la radice
   che hanno cercato una mossa, ri-ricerche, mosse PV cercate per prime, i nove conteggi dei tipi
   di nodo e, con una TT, i suoi contatori.

**Classificazione:** PVS e NegaScout `[EXACT]`: restituiscono il valore di alpha-beta, e con la
finestra piena alla radice il valore di negamax. La base è nel docstring di `search-node`:
risultati interi, quindi una finestra nulla non ha punteggi interni, e un risultato della
ricerca a finestra nulla è un bound dal lato giusto; le ri-ricerche di NegaScout hanno la stessa
garanzia. Con la TT in modalità normale la combinazione è `[HEURISTIC]` sul valore a profondità
fissa (regola 5 di [classificazione](../classificazione.md#regole-duso)). L'arresto
dell'iterative deepening su un matto resta `[EXACT]` per il valore; con l'ordinamento o la TT la
mossa migliore è una mossa dello stesso matto forzato, non sempre la stessa della ricerca diretta.
I tipi di nodo non riducono lavoro: non portano etichetta.

**Invarianti:** INV-C1 (il valore della ricerca di default contro il riferimento, nella suite
`differential`), INV-A5 (la ricerca della Fase 3 con un contesto e una TT preallocati non alloca
per nodo). **INV-X3** non è soddisfatto: PVS, NegaScout e la ricerca di default cambiano i nodi,
un'uscita della ricerca, quindi vale il percorso intero, che non è fatto
([EXP-0003](../../research/exp-0003-ricerca-della-fase-3.md), Proposto). Uno scostamento
dichiarato.

**Verifica:** la suite `optimized-pvs` di `make test`: il nodo della Fase 3 in modalità alpha-beta
contro la baseline (valore, mossa, nodi, variante); PVS e NegaScout, con e senza ordinamento, e
alpha-beta ordinato, senza TT e con la TT in modalità di verifica, contro il valore della
baseline sulle posizioni di ricerca, su posizioni casuali con seme e con le mosse permutate dai
semi; le varianti rigiocate dal riferimento; i
conteggi dei tipi di nodo; l'albero minimo di Knuth e Moore con un ordinamento perfetto (un
aggancio dei test che ordina le mosse per il loro valore di negamax): numero di nodi uguale
all'albero minimo contato a parte, ogni nodo del tipo atteso, nessuna ri-ricerca; l'iterative
deepening con la TT in modalità di verifica a ogni profondità; l'allocazione. La suite
`optimized-tt` per la TT, il test della firma e, nella suite `differential`, il valore e la
variante della ricerca di default contro il riferimento. L'elenco è in
[verifica](../verifica.md#ricerca-della-fase-3).

## Conseguenze

- La firma ha due parti. Una modifica `[EXACT]` delle baseline o della ricerca della Fase 3 non
  cambia nessuna delle due; una modifica dell'ordinamento o della TT cambia i nodi della seconda.
- Il nodo della Fase 3 paga per nodo controlli che le baseline non hanno (algoritmo, ordinamento,
  presenza della TT, tipi di nodo). Le baseline restano per il confronto: il test
  `the-phase-3-alpha-beta-node-equals-the-baseline` lega le due.
- `make hot-path` scansiona anche `search-node`, `order-node-moves`, `bitboard-tt-probe` e
  `bitboard-tt-store`. Le chiamate piene di `search-node` sono quelle verso la sonda,
  l'inserimento, l'ordinamento, la generazione, make, unmake, la valutazione, lo scacco e la
  permutazione dei test; il `funcall` dell'aggancio d'ordine dei test passa per un oggetto
  funzione, e la scansione non lo nomina. Su SBCL 2.6.9, macOS arm64, la scansione non trova
  sequenze di allocazione né aritmetica generica nelle quattro funzioni, e i file
  `transposition.lisp` e `ordering.lisp` non danno note di efficienza; le note di `search.lisp`
  sono quelle della Fase 2 ([ADR-0019](0019-valutazione-e-ricerca-del-livello-ottimizzato.md),
  Conseguenze).
- Nessuna affermazione di forza: nessuna partita è stata giocata.

## Alternative considerate

- *PVS e NegaScout come un solo algoritmo con due nomi*: la letteratura li tratta spesso come
  equivalenti. Scartata: il gate li nomina entrambi, e le due differenze del punto 2 sono reali e
  misurabili.
- *NegaScout con la finestra di Reinefeld `(s, β)`*: la variante sotto un figlio che vale
  esattamente `s` non sarebbe esatta, e i test che rigiocano le varianti non varrebbero per
  NegaScout. Scartata per un punto di finestra.
- *Sostituire `alpha-beta-node` con `search-node` in modalità alpha-beta*: un solo nodo da
  mantenere. Scartata per ora: le baseline restano il termine di confronto della Fase 2 e delle
  righe di [EXP-0002](../../research/exp-0002-stato-incrementale-della-valutazione.md).
- *La firma solo della ricerca di default*: si perderebbe la protezione delle baseline, e le righe
  di `make bench` della ricerca e di EXP-0002 non avrebbero più i loro nodi registrati.
- *La firma della ricerca di default con la TT in modalità normale*: il suo valore a profondità
  fissa non è garantito uguale a quello di alpha-beta, quindi né il riferimento né un test di
  uguaglianza la potrebbero giudicare.
- *Usare il tipo di nodo già nella Fase 3* (per esempio niente ricerca a finestra nulla nei nodi
  All): cambierebbe uscite senza un record di ricerca. Le fasi 4 e 5 lo useranno, dichiarandolo.

## Valutazione

- Rischi: RSK-06 (etichette ottimistiche: la combinazione con la TT normale è `[HEURISTIC]`),
  RSK-01 (allocazione: il test della suite `optimized-pvs`).
- Si verifica con le suite dette, su ogni piattaforma su cui `make check` gira.
- Porterebbero a rivedere la decisione: l'esito di
  [EXP-0003](../../research/exp-0003-ricerca-della-fase-3.md); una ricerca a finestra nulla che
  restituisce un bound dal lato sbagliato (un test che fallisce); misure che mostrano il costo dei
  controlli per nodo nel nodo della Fase 3 superiore a ciò che toglie.
