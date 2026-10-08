# ADR-0020 — I parametri della valutazione diventano dati dalla Fase 10

- **Stato:** Accettata
- **Data:** 2026-10-07; decisione dell'autore del 2026-10-04, in sessione
- **Rapporto con la specifica:** chiude [QA-19](../limiti-e-rischi.md#qa-19); stabilisce da
  quando INV-X7 («PARAMETER OPTIMIZATION»: «Ogni parametro importante deve poter essere
  modificato senza cambiare il codice») si applica ai parametri della valutazione classica
- **Riferimenti:** [valutazione](../valutazione.md#riepilogo-dei-parametri),
  [invarianti](../invarianti.md) (INV-X7, INV-C1),
  [ADR-0018](0018-definizione-della-valutazione-classica.md),
  [ADR-0019](0019-valutazione-e-ricerca-del-livello-ottimizzato.md),
  [roadmap](../roadmap.md#fase-10)

## Contesto

I parametri della valutazione classica sono costanti (`defconstant`, `sb-ext:defglobal`) in cima
a `src/reference/classical.lisp` e a `src/optimized/evaluation-tables.lisp`, una copia per
livello, confrontate dal test differenziale. Cambiare un peso vuol dire cambiare il codice dei
due livelli. INV-X7, Deciso, chiede il contrario, perché un esperimento di taratura cambi dati e
non programma. Nessun parametro oggi cambia da dati: la taratura è della
[Fase 10](../roadmap.md#fase-10). Le opzioni erano tre ([QA-19](../limiti-e-rischi.md#qa-19)):
un file di dati letto al caricamento da ciascun livello, i parametri nel `core`, oppure rinviare
INV-X7 per la valutazione alla Fase 10.

## Decisione

> **Deciso (autore → ADR-0020)** — Scelta dell'autore del 2026-10-04.

1. INV-X7 si applica ai parametri della valutazione classica dalla
   [Fase 10](../roadmap.md#fase-10). Fino ad allora restano costanti nel codice dei due livelli,
   come oggi.
2. Il gate della Fase 10 comprende la forma con cui i parametri si cambiano senza cambiare il
   codice. La forma (un file di dati, o altro) si decide allora, con un ADR, misurandone il
   costo nel hot path con le righe della valutazione di `make bench`.
3. Finché vale il punto 1, un peso si cambia in un solo commit: nel
   [documento](../valutazione.md) con i suoi esempi calcolati, nelle due copie, nei valori
   attesi dei test che ne dipendono e nella firma di ricerca (`make signatures`).

**Classificazione:** nessuna riduzione di lavoro introdotta.

**Invarianti:** INV-X7 resta Deciso; questo ADR ne fissa l'applicazione alla valutazione. INV-C1
(i due livelli danno la stessa valutazione) continua a controllare le due copie.

**Verifica:** il test differenziale della valutazione (`make test`, `make differential-deep`) e
i valori attesi di [valutazione](../valutazione.md#esempi-calcolati) nei test. Un errore uguale
nelle due copie non lo vede il test differenziale: lo vedono gli esempi calcolati a mano.

## Conseguenze

- Le costanti restano tipizzate e note al compilatore: nessun costo nel hot path finché non c'è
  la taratura.
- Un errore di valore copiato nelle due copie resta visibile solo agli esempi calcolati a mano
  (RSK-05). È lo stesso rischio di un file di dati comune ai due livelli.
- La Fase 10 eredita un lavoro preciso: rendere i parametri dati, prima di tararli.

## Alternative considerate

- *Un file di dati ora, letto da ciascun livello:* scartato per ora. Cambia la forma prima che
  serva, e i pesi letti nel hot path diventano variabili, con un costo da misurare.
- *I parametri nel `core`:* scartato. Un solo posto, ma ancora codice: non soddisfa INV-X7, e il
  `core` condiviso toglie al test differenziale anche la verifica delle due copie.

## Valutazione

- Rischio: RSK-05. Verifica: gli esempi calcolati di [valutazione](../valutazione.md) nei test.
- Porterebbe a rivedere la decisione: un esperimento che chieda di cambiare i pesi prima della
  Fase 10, che dovrebbe allora cambiare il codice dei due livelli in ogni sua variante.
