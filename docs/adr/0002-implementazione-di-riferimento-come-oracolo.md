# ADR-0002 — L'implementazione di riferimento come oracolo

- **Stato:** Accettata
- **Data:** 2026-10-03
- **Rapporto con la specifica:** registra «ARCHITETTURA GENERALE» e «REFERENCE ENGINE». Le regole
  di indipendenza tra i livelli che il repository propone sono in
  [ADR-0010](0010-regole-di-indipendenza-tra-i-livelli.md).
- **Riferimenti:** [architettura](../architettura.md), [verifica](../verifica.md), INV-C1, INV-A4

## Contesto

L'ottimizzazione tende a rendere il codice difficile da verificare. La specifica pone la
correttezza prima della velocità e vuole che un'implementazione semplice resti sempre disponibile
per giudicare quella veloce.

## Decisione

1. Sette livelli separati rigorosamente: implementazione di riferimento, engine ottimizzato,
   livello sperimentale di ricerca, backend specifici per hardware, infrastruttura di benchmark,
   infrastruttura di addestramento, infrastruttura di test.
2. Il riferimento è volutamente semplice e leggibile. È l'oracolo per generazione delle mosse
   legali, make/unmake, transizioni di stato, stato Zobrist, valutazione, aggiornamenti delle
   feature NNUE e, dove applicabile, risultati di ricerca.
3. L'implementazione ottimizzata si confronta continuamente con il riferimento, su milioni di
   posizioni casuali: `optimized(position) == reference(position)` (INV-C1).
4. L'ottimizzazione non rende mai impossibile la verifica della correttezza (INV-A4).

Classificazione: nessuna riduzione di lavoro introdotta. Il riferimento definisce che cosa vuol
dire `EXACT` per ogni altro livello.

## Conseguenze

- Due implementazioni da mantenere, e un riferimento più lento dell'ottimizzato.
- Un errore che non sta nel `core` e in cui i due livelli divergono è rilevabile dal confronto. Un
  errore comune a entrambi no (RSK-05): per questo il riferimento si giudica anche con valori
  pubblicati ([ADR-0012](0012-lettura-del-gate-di-perft.md)). Ciò che sta nel `core` non è
  giudicato dal confronto.
- Il significato di «uguale» va definito per funzione ([architettura](../architettura.md#che-cosa-significa-uguale)).
- Le regole che rendono vera la separazione sono proposte a parte:
  [ADR-0010](0010-regole-di-indipendenza-tra-i-livelli.md).

## Alternative considerate

- *Un'unica implementazione con asserzioni:* scartata, perché non c'è un oracolo indipendente.
- *Riferimento derivato da un engine esistente:* scartata, per l'originalità
  ([ADR-0007](0007-licenza-bsd-2-clause-e-originalita.md)).

## Valutazione

- Rischio: RSK-05. Verifica: test differenziale e fuzzer ([verifica](../verifica.md)).
- La decisione viene dalla specifica: la cambia solo un ADR che la emenda. Un errore sfuggito al
  confronto porta a rivedere le regole di [ADR-0010](0010-regole-di-indipendenza-tra-i-livelli.md),
  non il ruolo dell'oracolo.
