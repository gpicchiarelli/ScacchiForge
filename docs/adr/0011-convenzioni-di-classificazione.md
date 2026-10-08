# ADR-0011 — Convenzioni di classificazione: regole d'uso, marcatura, tabella delle tecniche

- **Stato:** Accettata
- **Data:** 2026-10-04; accettata dall'autore il 2026-10-04, per sua decisione in sessione
- **Rapporto con la specifica:** proposta nuova (non nella specifica); applica
  [ADR-0003](0003-classificazione-delle-riduzioni-di-lavoro.md) («PRINCIPIO FONDAMENTALE»).
  Confermata dall'autore il 2026-10-04.
- **Riferimenti:** [classificazione](../classificazione.md), INV-X1, RSK-06

## Contesto

La specifica fissa le sette etichette e la regola «almeno una»
([ADR-0003](0003-classificazione-delle-riduzioni-di-lavoro.md)). Non dice come le etichette si
combinano, dove si scrivono, né quale spetta a ciascuna tecnica.

## Decisione

> **Deciso (autore → ADR-0011)** — Proposta del repository, confermata dall'autore il
> 2026-10-04.

1. **Regole d'uso** ([classificazione](../classificazione.md#regole-duso)): più etichette
   ammesse; `EMPIRICAL` e `LEARNED` non sostituiscono una garanzia; ordine di garanzia; nel
   dubbio la più debole; una combinazione ha la garanzia del componente più debole; si promuove
   con evidenza; che cosa si classifica.
2. **Marcatura** ([classificazione](../classificazione.md#come-si-marca)): nel docstring
   (`Classification:`, `Basis:`, `Evidence:`), nei documenti, nei commit, nelle pull request e nei
   record di ricerca.
3. **Ipotesi della transposition table** TT-1…TT-4, nominate una volta
   ([classificazione](../classificazione.md#ipotesi-della-transposition-table)).
4. **Tabella delle tecniche.** È una proposta: ogni riga diventa vincolante solo quando un ADR la
   decide.

Classificazione: nessuna riduzione di lavoro introdotta.

## Conseguenze

- L'etichetta sta accanto al codice che la rende vera; il commit dice quale test la sostiene.
- La classe di un algoritmo e quella di una sua implementazione si dichiarano separatamente: un
  algoritmo può essere `THEOREM`, un'implementazione dice nel docstring su quale base e con
  quale evidenza ne eredita la garanzia.

## Alternative considerate

- *Etichette solo nei documenti:* scartata; l'etichetta deve stare accanto al codice che la rende
  vera.
- *Una sola etichetta per tecnica:* scartata; la specifica dice «almeno una», e da dove viene
  l'evidenza (`EMPIRICAL`, `LEARNED`) è cosa diversa dalla garanzia.

## Valutazione

- Rischio: RSK-06. Invariante: INV-X1.
- Un controllo automatico della presenza del campo `Classification:` nei docstring delle funzioni
  che riducono lavoro è una possibilità, non una decisione.
- Porterebbe a rivedere le convenzioni: etichette che nella pratica restano sempre `HEURISTIC` per
  pigrizia, o campi omessi con regolarità.
