# ADR-0001 — Common Lisp/SBCL come linguaggio del nucleo

- **Stato:** Accettata
- **Data:** 2026-10-03
- **Rapporto con la specifica:** registra le sezioni «COMMON LISP / SBCL» e «NATIVE MICROKERNELS»
- **Riferimenti:** [architettura](../architettura.md#common-lisp-e-sbcl),
  [limiti e rischi](../limiti-e-rischi.md#microkernel-nativi), INV-A5, INV-A8, INV-H1, INV-H2

## Contesto

La specifica chiede un engine originale in Common Lisp/SBCL. Chiede di mantenere il garbage
collector, di tenere quasi a zero l'allocazione nel hot path di ricerca e di ammettere codice
nativo solo in casi precisi. Chiede anche di non trasformare Common Lisp «in una caricatura di C».

## Decisione

1. Il linguaggio è Common Lisp. SBCL è l'implementazione primaria.
2. Il GC resta. È libero in server, tooling, configurazione, logging, orchestrazione e test.
3. Nel hot path di ricerca: allocazione quasi nulla, stack e buffer di mosse preallocati, array
   tipizzati, strutture compatte; evitare boxing, consing e chiusure allocate. Il comportamento
   reale si verifica con profiling e disassembly.
4. Il nucleo dell'engine resta Common Lisp. FFI e kernel nativi sono ammessi esclusivamente se
   valgono tutte e cinque le condizioni: il profiling dimostra un hot spot; SBCL non produce
   codice adeguato; il kernel è isolabile; esiste un fallback portabile; esiste un test di
   equivalenza.
5. Si usa il linguaggio dove dà sicurezza e produttività; si specializzano solo i kernel
   realmente critici.

Classificazione: nessuna riduzione di lavoro introdotta. Un eventuale kernel nativo sarebbe
`EXACT`, con test di equivalenza (INV-H2).

## Conseguenze

- Un solo linguaggio e un solo modello di memoria nel nucleo.
- Il comportamento del GC e della generazione di codice di SBCL diventa un vincolo di progetto.
  Quanto di ciò che la specifica chiede sia ottenibile in SBCL, su quali piattaforme, è in parte
  da misurare: [QA-03](../limiti-e-rischi.md#qa-03), [QA-04](../limiti-e-rischi.md#qa-04),
  [QA-05](../limiti-e-rischi.md#qa-05).
- Conciliare la possibilità dei kernel nativi con «SBCL unica toolchain»
  ([ADR-0004](0004-nessuna-dipendenza-esterna-e-harness-proprio.md)) richiede un ADR, se mai
  servisse: [QA-06](../limiti-e-rischi.md#qa-06).

## Alternative considerate

- *Nucleo in C, C++ o Rust:* esclusa dalla specifica («il core dell'engine deve rimanere Common
  Lisp»).
- *Altre implementazioni Common Lisp:* non escluse, ma la specifica indica SBCL come primaria e
  nessuna altra è verificata.

## Valutazione

- Rischi: RSK-01, RSK-02, RSK-03. Questioni: QA-03, QA-04, QA-05, QA-06.
- Porterebbe a rivedere la decisione: una misura che mostri un hot spot non risolvibile in Common
  Lisp a un costo accettabile (condizioni 1 e 2); in quel caso si scrive un nuovo ADR.
