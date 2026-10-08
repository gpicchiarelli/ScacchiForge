# ADR-0009 — Convenzione linguistica: documentazione in italiano, codice in inglese

- **Stato:** Accettata
- **Data:** 2026-10-03; accettata dall'autore il 2026-10-04, per sua decisione in sessione
- **Rapporto con la specifica:** proposta nuova (non nella specifica); ispirata alla convenzione
  di ArcDocDB, con una differenza: qui anche i termini di dominio nel codice sono in inglese.
  Confermata dall'autore il 2026-10-04.
- **Riferimenti:** [glossario](../glossario.md#convenzione-linguistica)

## Contesto

La specifica è in italiano, con termini tecnici in inglese. Il repository ha lettori interni e
pubblici. L'autore usa già una convenzione negli altri progetti.

## Decisione

> **Deciso (autore → ADR-0009)** — Proposta del repository, confermata dall'autore il
> 2026-10-04.

1. In **italiano**: `CONTRIBUTING.md`, `CHANGELOG.md`, `CLAUDE.md`, `assets/README.md` e tutto ciò
   che sta sotto `docs/` e `research/`.
2. In **inglese**: `README.md`, `SECURITY.md`, `SUPPORT.md`, `CODE_OF_CONDUCT.md`, i moduli delle
   issue e il modello di pull request; il codice sorgente, gli identificativi, i docstring e i
   nomi dei test.
3. I termini tecnici consolidati restano in inglese anche nei documenti italiani. L'elenco è
   uno solo, nel [glossario](../glossario.md#convenzione-linguistica); gli altri file vi rimandano.
4. Le sette etichette di classificazione si scrivono in inglese e in maiuscolo.
5. I messaggi di commit sono in italiano; la riga `Classification:` resta in inglese.

Classificazione: nessuna riduzione di lavoro introdotta.

## Conseguenze

- I lettori pubblici trovano in inglese ciò che riguarda l'uso e la sicurezza; chi contribuisce
  trova in italiano il metodo.
- Il glossario è la tabella di corrispondenza tra i termini e l'unico elenco dei termini che
  restano in inglese.

## Alternative considerate

- *Tutto in inglese:* scartata; la specifica e il metodo di lavoro dell'autore sono in italiano.
- *Tutto in italiano, codice compreso:* scartata; gli identificativi tecnici e i file pubblici in
  inglese raggiungono più lettori.

## Valutazione

- Verifica: revisione.
- Porterebbe a rivedere la decisione: l'arrivo di contributori che non leggono l'italiano.
