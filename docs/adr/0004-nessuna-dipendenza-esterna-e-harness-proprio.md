# ADR-0004 — Nessuna dipendenza esterna; harness di test proprio

- **Stato:** Accettata
- **Data:** 2026-10-03; accettata dall'autore il 2026-10-04, per sua decisione in sessione
- **Rapporto con la specifica:** proposta nuova (non nella specifica); sostituisce il piano
  iniziale che prevedeva FiveAM, Alexandria e trivial-features. Confermata dall'autore il
  2026-10-04.
- **Riferimenti:** [ADR-0001](0001-common-lisp-sbcl.md), [verifica](../verifica.md), INV-A1

## Contesto

La specifica non dice nulla sulle librerie. Il progetto vuole costruire e misurare tutto con SBCL
e nient'altro: il riferimento deve essere leggibile da solo, e ogni dipendenza è codice che il
confronto differenziale non giudica. La prima bozza del repository dichiarava FiveAM, Alexandria
e trivial-features.

## Decisione

> **Deciso (autore → ADR-0004)** — Proposta del repository, confermata dall'autore il
> 2026-10-04.

1. SBCL è l'unica toolchain. I sistemi ASDF `scacchiforge`, `scacchiforge/test` e
   `scacchiforge/bench` dipendono solo da SBCL e da ASDF. Nessun Quicklisp, nessuna libreria Lisp
   di terzi.
2. I contrib distribuiti con SBCL non sono dipendenze di terzi: si usano quando servono e si
   dichiarano nel sistema ASDF che li richiede. Il livello di riferimento non ne usa (INV-A1).
3. I test usano un harness proprio, nel repository: registrazione dei test, asserzioni,
   esecuzione e riepilogo con codice di uscita.
4. Gli strumenti di sviluppo (build, controllo dei link, linter) sono script Common Lisp
   eseguiti dai target del [Makefile](../../Makefile) con
   `sbcl --noinform --no-userinit --non-interactive --load tools/<nome>.lisp`.

Classificazione: nessuna riduzione di lavoro introdotta.

## Conseguenze

- Più codice da scrivere: asserzioni, runner, generazione di dati di prova.
- Nessun gestore di pacchetti per compilare: bastano SBCL e ASDF.
- Test, perft, fuzzer e confronto differenziale si integrano nello stesso runner e nello stesso
  codice di uscita, senza adattarsi a un framework.
- Costruire e misurare su una nuova piattaforma richiede soltanto SBCL
  ([QA-12](../limiti-e-rischi.md#qa-12)).

## Alternative considerate

- *FiveAM e Alexandria via Quicklisp (piano iniziale):* scartata; introduce codice di terzi e un
  gestore di pacchetti. Da riaprire se l'autore lo preferisce.
- *Contrib di SBCL per i test (per esempio `sb-rt`, presente tra i contrib installati):* ammesso
  in linea di principio, non scelto; l'harness proprio serve anche a perft, fuzzer e confronto.
  Non è stato valutato in dettaglio.

## Valutazione

- Invariante: INV-A1. Verifica: `make check` su un checkout pulito con la sola SBCL.
- Porterebbe a rivedere la decisione: un harness che diventa più grande del codice che verifica,
  o l'autore che preferisce un framework.
