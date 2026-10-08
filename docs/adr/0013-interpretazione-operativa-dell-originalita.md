# ADR-0013 — Interpretazione operativa dell'originalità

- **Stato:** Accettata
- **Data:** 2026-10-04; accettata dall'autore il 2026-10-04, per sua decisione in sessione
- **Rapporto con la specifica:** proposta nuova (non nella specifica); interpreta il vincolo di
  originalità registrato in [ADR-0007](0007-licenza-bsd-2-clause-e-originalita.md). Confermata
  dall'autore il 2026-10-04.
- **Riferimenti:** INV-X9, [ADR-0007](0007-licenza-bsd-2-clause-e-originalita.md)

## Contesto

La specifica vieta «Stockfish, codice derivato da Stockfish o implementazioni proprietarie di
altri engine». Non dice che cosa conti come derivato: un algoritmo pubblicato, una tabella di
costanti, un valore di perft.

## Decisione

> **Deciso (autore → ADR-0013)** — Proposta del repository, confermata dall'autore il
> 2026-10-04.

1. Gli algoritmi pubblicati e le idee si possono implementare, perché sono conoscenza pubblica:
   alpha-beta, PVS, LMR, la NNUE come concetto.
2. Non si copiano codice, tabelle di costanti ottimizzate, pesi di reti né dati di addestramento
   di altri engine.
3. I dati di fatto (valori pubblicati di perft, posizioni note in FEN) sono ammessi con la fonte
   citata.
4. I pesi e i parametri del progetto sono prodotti dalla sua infrastruttura.
5. Un caso dubbio si porta all'autore.

Classificazione: nessuna riduzione di lavoro introdotta.

## Conseguenze

- Il codice si scrive da descrizioni pubbliche degli algoritmi, non da altro codice.
- Ogni costante o dato preso da una fonte esterna cita la fonte e la sua licenza.

## Alternative considerate

- *Vietare anche i dati di fatto di altri progetti (valori di perft, posizioni di prova):*
  scartata; sono fatti, non codice, e servono come oracolo esterno
  ([ADR-0012](0012-lettura-del-gate-di-perft.md)).
- *Ammettere costanti tarate da altri engine, con la fonte citata:* scartata; una tabella tarata
  da un altro engine è il prodotto del suo lavoro, non un'idea pubblicata.

## Valutazione

- Verifica: revisione. Una pull request che porta costanti o dati da fonti esterne lo dichiara.
- Porterebbe a rivedere l'interpretazione: un caso dubbio che queste regole non decidono.
