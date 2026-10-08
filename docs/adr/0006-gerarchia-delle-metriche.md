# ADR-0006 — Gerarchia delle metriche: Elo per CPU-secondo prima dell'NPS

- **Stato:** Accettata
- **Data:** 2026-10-03
- **Rapporto con la specifica:** registra «OBIETTIVO MATEMATICO» e «METRICHE PRINCIPALI»
- **Riferimenti:** [misure](../misure.md#gerarchia-delle-metriche), INV-X11, [QA-08](../limiti-e-rischi.md#qa-08)

## Contesto

Un engine può avere un NPS alto e giocare male, e un engine con una valutazione costosa può avere
un NPS basso e giocare bene. La specifica non vuole un laboratorio che ottimizza la metrica
facile.

## Decisione

1. L'obiettivo è `max Strength / CPU-time`. In secondo luogo: minimizzare i nodi per decisione e i
   CPU-ms per posizione risolta; massimizzare la profondità a tempo fisso.
2. Priorità delle metriche: Elo per CPU-secondo; forza a tempo fisso; nodi per posizione tattica
   risolta; CPU-ms per decisione; profondità a tempo fisso; NPS.
3. L'NPS non è l'indicatore principale di qualità e non basta da solo per una decisione (INV-X11).
4. Un miglioramento non si dichiara sulla base di una sola partita o di un solo benchmark (INV-X4).

> **Aperto (QA-08)** — «Elo per CPU-secondo» non è una quantità per secondo, e la specifica non
> ne dà una lettura operativa: [QA-08](../limiti-e-rischi.md#qa-08). Due letture proposte sono in
> [misure](../misure.md#che-cosa-vuol-dire-elo-per-cpu-secondo).

Classificazione: nessuna riduzione di lavoro introdotta.

## Conseguenze

- Ogni modifica si giudica con la forza per CPU-secondo, non con la velocità del solo codice.
- Il self-play diventa il giudice finale, con i costi statistici che comporta
  ([misure](../misure.md#statistica)).
- Una cifra di prestazione compare solo se un comando nel repository la produce (INV-X2).

## Alternative considerate

- *NPS come metrica principale:* esclusa dalla specifica.
- *Partite a nodi fissi come giudice unico:* scartata; non vede il costo per nodo.

## Valutazione

- Rischi: RSK-07, RSK-08, RSK-13. Questioni: QA-08, QA-09.
- Porterebbe a rivedere la gerarchia: una misura che mostri che le priorità 3-5 predicono la forza
  meglio del self-play in una classe di modifiche.
