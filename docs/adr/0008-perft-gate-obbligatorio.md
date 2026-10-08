# ADR-0008 — Perft come gate obbligatorio

- **Stato:** Accettata
- **Data:** 2026-10-03
- **Rapporto con la specifica:** registra «PERFT». La lettura del gate, la provenienza dei valori
  attesi e le regole di esecuzione che il repository propone sono in
  [ADR-0012](0012-lettura-del-gate-di-perft.md).
- **Riferimenti:** [verifica](../verifica.md#perft), [roadmap](../roadmap.md#fase-1), INV-C4, INV-X8

## Contesto

Una ricerca aggressiva sopra una generazione di mosse sbagliata produce errori che nessuna misura
di forza spiega. Il perft è il modo più economico di scoprire un errore nella generazione.

## Decisione

1. Perft è un gate obbligatorio. Prima di introdurre ricerca aggressiva tutte le posizioni di
   perft devono passare.
2. Si testano arrocco, en passant, promozione, inchiodature, scacchi, scacchi scoperti e casi
   limite.
3. Si crea un fuzzer di posizioni legali.

Classificazione: nessuna riduzione di lavoro introdotta. Verifica di `EXACT`.

## Conseguenze

- Nessuna ricerca aggressiva prima che il gate di perft passi (INV-X8). Che cosa conti come
  ricerca aggressiva, e che cosa il riferimento possa contenere prima del gate, lo propone
  [ADR-0012](0012-lettura-del-gate-di-perft.md).
- I perft profondi sul riferimento possono essere lenti: è il prezzo dell'oracolo.
- Il conteggio non vede tutto: errori che si compensano, insiemi di mosse diversi con la stessa
  cardinalità. Per questo, quando esisterà un generatore ottimizzato, il test differenziale
  confronterà gli insiemi di mosse, non solo i totali.

## Alternative considerate

- *Perft solo in un controllo periodico, non per modifica:* scartata; l'errore si scopre tardi.
- *Solo test differenziale, senza valori pubblicati:* scartata; entrambi i livelli possono
  concordare nello stesso errore.

## Valutazione

- Invarianti: INV-C4, INV-X8. Verifica: i test in [`tests/`](../../tests/).
- Porterebbe a rivedere la decisione: un errore di generazione trovato con altri mezzi mentre il
  perft passava; il caso entra nella suite.
