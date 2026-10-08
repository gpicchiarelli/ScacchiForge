# ADR-0005 — Chiavi Zobrist da un generatore deterministico, mai `sxhash`

- **Stato:** Accettata
- **Data:** 2026-10-03; accettata dall'autore il 2026-10-04, per sua decisione in sessione
- **Rapporto con la specifica:** proposta nuova (non nella specifica); applica «Zobrist hash»
  (TRANSPOSITION TABLE) e «reproducible seeds» (SELF-PLAY)
- **Riferimenti:** [classificazione](../classificazione.md), INV-C3, INV-X6, [QA-01](../limiti-e-rischi.md#qa-01)

## Contesto

Le chiavi Zobrist identificano le posizioni nella TT e nei test. Perché reference e optimized
concordino, perché un fallimento si riproduca e perché il comportamento logico sia identico su ogni
piattaforma (INV-H5), le chiavi devono essere le stesse a ogni esecuzione.

Lo standard Common Lisp non lo garantisce:

- `sxhash` restituisce un fixnum non negativo, quindi non copre 64 bit, e il suo valore tra
  implementazioni e versioni non è specificato;
- `random` non ha un algoritmo specificato, e non c'è un modo standard di seminare un
  `random-state` da un intero.

## Decisione

> **Deciso (autore → ADR-0005)** — Proposta del repository, confermata dall'autore il
> 2026-10-04.

1. Le chiavi Zobrist vengono da un generatore pseudocasuale deterministico, implementato nel
   repository, con un seme dichiarato. La sequenza dipende solo dal seme.
2. `sxhash`, `random` e `*random-state*` non si usano per le chiavi, né per ciò che deve essere
   riproducibile: casualità di test, fuzzer, aperture del self-play, tuning (INV-X6).
3. Il generatore proposto è splitmix64: stato di 64 bit, poche operazioni su interi, identico in
   qualunque implementazione. Alla data di questo ADR il `core` del repository lo implementa.
4. Un test fissa i primi valori della sequenza per il seme documentato e le chiavi di alcune
   posizioni note, così un cambio di generatore o di seme si vede.
5. Un test controlla che le 781 chiavi di base siano distinte e non nulle
   ([`tests/test-core.lisp`](../../tests/test-core.lisp)). La costruzione delle tavole non fa
   controlli. La chiave dell'insieme vuoto di diritti di arrocco vale 0 per costruzione: è lo XOR
   di nessuna chiave.

Classificazione: l'aggiornamento incrementale della chiave è `EXACT` (INV-C3). L'identificazione di
una posizione dalla chiave è `PROBABILISTIC`. Per due posizioni che differiscono in almeno una
caratteristica della chiave (pezzi, lato al tratto, diritti di arrocco, casa en passant disponibile
secondo la politica della chiave), con chiavi indipendenti e uniformi su 64 bit, la probabilità che
le chiavi coincidano è 2^-64. L'indipendenza è un modello: le chiavi vengono da un generatore
deterministico. Due posizioni che differiscono solo negli orologi, o in una casa en passant che
nessun pedone di chi muove attacca, hanno per costruzione la stessa chiave. Gli orologi stanno
fuori dalla chiave, ed è uno dei motivi di TT-2
([classificazione](../classificazione.md#ipotesi-della-transposition-table)).

## Conseguenze

- Le stesse chiavi su ogni piattaforma e a ogni esecuzione; le chiavi non sono casuali nel senso
  forte, ma riproducibili.
- Cambiare il seme cambia tutte le chiavi, e quindi tutti i valori attesi dei test che le contengono.
- Il `core` documenta quali caratteristiche entrano nella chiave (per esempio quando conta la casa
  en passant) e contiene le tavole delle chiavi. Ciascun livello implementa per conto proprio il
  test di disponibilità dell'en passant, così che il confronto differenziale lo giudichi (INV-A3,
  [ADR-0010](0010-regole-di-indipendenza-tra-i-livelli.md)).

## Alternative considerate

- *`sxhash`:* scartata; fixnum, valore non specificato tra implementazioni.
- *`random` di Common Lisp:* scartata; non riproducibile in modo standard.
- *Tabella di chiavi scritta come costante da uno strumento esterno:* scartata; opaca e non
  rigenerabile dal repository.

## Valutazione

- Questione: [QA-01](../limiti-e-rischi.md#qa-01) (conteggio dei falsi riscontri).
- Porterebbe a rivedere la decisione: una misura che mostri dipendenze lineari tra le chiavi o
  una frequenza di falsi riscontri superiore a quella attesa dal modello.
