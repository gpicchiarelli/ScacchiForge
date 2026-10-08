# ADR-0007 — Licenza BSD-2-Clause e originalità del codice

- **Stato:** Accettata
- **Data:** 2026-10-03
- **Rapporto con la specifica:** registra il vincolo di originalità dell'introduzione della
  specifica. La licenza è una scelta dell'autore, registrata nel file
  [LICENSE](../../LICENSE), non della specifica. L'interpretazione operativa del vincolo che il
  repository propone è in [ADR-0013](0013-interpretazione-operativa-dell-originalita.md).
- **Riferimenti:** INV-X9

## Contesto

La specifica chiede un engine originale, «senza utilizzare Stockfish, codice derivato da Stockfish
o implementazioni proprietarie di altri engine». L'autore distribuisce il progetto con licenza
BSD-2-Clause.

## Decisione

1. Il progetto è distribuito con licenza BSD-2-Clause. Autore: Giacomo Picchiarelli.
2. Il codice è originale: nessun uso di Stockfish, di codice derivato da Stockfish o di
   implementazioni proprietarie di altri engine (INV-X9).

Classificazione: nessuna riduzione di lavoro introdotta.

## Conseguenze

- Stockfish è distribuito con licenza GPL, copyleft: codice derivato non sarebbe compatibile con
  BSD-2-Clause. Per questo il vincolo di originalità protegge anche la licenza.
- Come si applica il vincolo ad algoritmi pubblicati, costanti e dati di fatto:
  [ADR-0013](0013-interpretazione-operativa-dell-originalita.md).

## Alternative considerate

- *Una licenza copyleft (GPL):* permetterebbe di derivare codice, ma contraddice la specifica
  e la scelta dell'autore.

## Valutazione

- Verifica: revisione.
- Porterebbe a rivedere la decisione: un cambio di licenza voluto dall'autore, con un nuovo ADR.
