# ADR-0003 — Classificazione delle riduzioni di lavoro

- **Stato:** Accettata
- **Data:** 2026-10-03
- **Rapporto con la specifica:** registra «PRINCIPIO FONDAMENTALE», la regola di marcatura di
  «SEARCH REDUCTIONS AND PRUNING» e «DEDUPLICATION». Le regole d'uso, la marcatura e la tabella
  delle tecniche che il repository propone sono in
  [ADR-0011](0011-convenzioni-di-classificazione.md).
- **Riferimenti:** [classificazione](../classificazione.md), [architettura](../architettura.md#deduplicazione), INV-X1

## Contesto

Una potatura efficace sembra un teorema finché non fallisce in uno zugzwang. La specifica chiede
di non confondere mai le due cose e di dichiarare ciò che si può affermare di ogni tecnica.

## Decisione

1. Ogni riduzione del lavoro computazionale è classificata con almeno una di sette etichette:
   `THEOREM`, `EXACT`, `BOUNDED`, `PROBABILISTIC`, `HEURISTIC`, `EMPIRICAL`, `LEARNED`.
2. Una tecnica non garantita matematicamente è `HEURISTIC`. Non si usano soglie arbitrarie senza
   benchmark.
3. La deduplicazione è un principio architetturale in sei forme: memoization, calcolo
   incrementale, precalcolo, riuso, compressione, località di cache. Non si fa una lookup se il
   suo costo supera quello del calcolo; si misurano sempre hit rate e costo della lookup.

Classificazione: la decisione è la regola stessa; non introduce riduzioni di lavoro.

## Conseguenze

- Ogni modifica che riduce lavoro dichiara che cosa si può affermare di essa.
- Una classe `EXACT` diventa controllabile: la firma di ricerca non cambia
  ([verifica](../verifica.md#regressione-di-ricerca)).
- Costo: scrivere e mantenere le etichette. Beneficio: una promozione senza evidenza non passa la
  revisione.
- Come si combinano e dove si scrivono le etichette, e quale propone il repository per ogni
  tecnica: [ADR-0011](0011-convenzioni-di-classificazione.md).

## Alternative considerate

- *Due sole classi, esatta e non esatta:* scartata; la specifica ne vuole sette, e distinguere un
  bound da una probabilità cambia come si verifica.

## Valutazione

- Rischio: RSK-06. Invariante: INV-X1.
- La decisione viene dalla specifica: la cambia solo un ADR che la emenda.
