# ADR-0010 — Regole di indipendenza tra i livelli

- **Stato:** Accettata
- **Data:** 2026-10-04; accettata dall'autore il 2026-10-04, per sua decisione in sessione
- **Rapporto con la specifica:** proposta nuova (non nella specifica); applica
  [ADR-0002](0002-implementazione-di-riferimento-come-oracolo.md) («ARCHITETTURA GENERALE»,
  «REFERENCE ENGINE»). Confermata dall'autore il 2026-10-04.
- **Riferimenti:** [architettura](../architettura.md#regole-tra-i-livelli), INV-A1, INV-A2,
  INV-A3, RSK-05

## Contesto

La specifica vuole che l'ottimizzato si confronti sempre con il riferimento
([ADR-0002](0002-implementazione-di-riferimento-come-oracolo.md)). Il confronto giudica solo ciò
che i due livelli calcolano ciascuno per conto proprio. Ciò che condividono, o che uno prende
dall'altro, non è giudicato.

## Decisione

> **Deciso (autore → ADR-0010)** — Proposta del repository, confermata dall'autore il
> 2026-10-04.

1. Il riferimento non dipende dall'ottimizzato e non ha dipendenze esterne (INV-A1, INV-A2).
2. Un modulo `core` condiviso contiene solo definizioni: costanti, codifica della mossa, tavole di
   chiavi, generatore pseudocasuale (INV-A3). Nessun algoritmo.
3. Una regola che entrambi i livelli applicano si documenta nel `core`, ma ciascun livello la
   implementa per conto proprio, così che il confronto la giudichi. Esempio: quando la casa en
   passant entra nella chiave.
4. L'ottimizzato usa il riferimento solo per convertire una posizione da e verso la propria
   struttura. Non lo usa per calcolare ciò che il confronto giudica: mosse, chiavi, valutazione.
5. Il riferimento non vede mai la struttura dell'ottimizzato.
6. Il riferimento è a sua volta giudicato da fonti esterne: i valori pubblicati di perft
   ([ADR-0012](0012-lettura-del-gate-di-perft.md)).
7. La forma interna del riferimento (per esempio un array di 64 case) non è prescritta.

Classificazione: nessuna riduzione di lavoro introdotta.

## Conseguenze

- Oggi la conversione sta nel livello ottimizzato e legge la struttura del riferimento
  ([`src/optimized/bitboard-position.lisp`](../../src/optimized/bitboard-position.lisp)).
  L'ottimizzato dipende quindi dal riferimento, per la conversione; il contrario no. I punti 1 e 4
  lo ammettono.
- La disponibilità della cattura en passant, che decide la chiave, è calcolata tre volte: nel
  riferimento (`en-passant-capture-available-p`,
  [`src/reference/attacks.lisp`](../../src/reference/attacks.lisp)) e due volte sui bitboard,
  con l'aritmetica delle colonne nella chiave calcolata da zero
  (`bitboard-en-passant-available-p`,
  [`src/optimized/bitboard-position.lisp`](../../src/optimized/bitboard-position.lisp)) e con la
  tavola degli attacchi di pedone nella chiave incrementale (`en-passant-key-part`,
  [`src/optimized/make.lisp`](../../src/optimized/make.lisp)). Il test differenziale confronta
  le due chiavi dell'ottimizzato fra loro e con quella del riferimento dopo ogni mossa. La
  politica è scritta una volta, in [`src/core/zobrist.lisp`](../../src/core/zobrist.lisp).
- Il punto 4 lo controlla il test `optimized-level-names-only-the-reference-position-interface`
  ([`tests/test-bitboard.lisp`](../../tests/test-bitboard.lisp)): i sorgenti di
  `src/optimized/` nominano del riferimento solo il tipo della posizione, i suoi accessori e il
  costruttore. Il test legge i sorgenti, non li esegue: una chiamata costruita a run time, per
  esempio da un nome in una stringa, gli sfugge, e resta alla revisione.

## Alternative considerate

- *Scambio solo come testo (FEN, mosse in coordinate), con la conversione nei test:* era la regola
  scritta prima di questo ADR. Separa di più i livelli, ma chiede un secondo parser FEN
  nell'ottimizzato. Il codice attuale non la segue. Resta una scelta aperta all'autore.
- *`core` più grande, con la generazione delle mosse:* scartata, perché ciò che è condiviso non si
  confronta.

## Valutazione

- Rischio: RSK-05. Verifica: ordine di caricamento dei sistemi ASDF, revisione, test
  differenziale ([verifica](../verifica.md#test-differenziale)).
- Porterebbe a rivedere le regole: un errore trovato per altra via, che stava nel `core` o in una
  funzione del riferimento usata dall'ottimizzato, e che il confronto non poteva vedere.
