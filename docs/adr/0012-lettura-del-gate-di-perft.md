# ADR-0012 — Lettura del gate di perft e provenienza dei valori attesi

- **Stato:** Accettata
- **Data:** 2026-10-04; accettata dall'autore il 2026-10-04, per sua decisione in sessione
- **Rapporto con la specifica:** proposta nuova (non nella specifica); applica
  [ADR-0008](0008-perft-gate-obbligatorio.md) («PERFT») e legge insieme «PERFT», «REFERENCE
  ENGINE», «SEARCH FOUNDATION» e la chiusura di «PHILOSOPHY». Confermata dall'autore il 2026-10-04.
- **Riferimenti:** [verifica](../verifica.md#perft), [roadmap](../roadmap.md#come-si-legge),
  INV-C4, INV-X8, RSK-05, RSK-11, [QA-10](../limiti-e-rischi.md#qa-10)

## Contesto

La specifica dice due cose sul momento della ricerca. In «PERFT»: «Prima di introdurre search
aggressiva» tutte le posizioni di perft devono passare. Nella chiusura: «Solo quando quella base è
inattaccabile» si passa ad alpha-beta, PVS e TT.

Chiede anche che il riferimento faccia da oracolo per i «search results dove applicabile»
(«REFERENCE ENGINE») e che minimax, negamax, alpha-beta e iterative deepening si implementino
«come baseline» («SEARCH FOUNDATION»).

Non dice da dove vengono i valori attesi di perft.

## Decisione

> **Deciso (autore → ADR-0012)** — Proposta del repository, confermata dall'autore il
> 2026-10-04.

1. **Il gate della Fase 1 precede ogni fase successiva dell'engine ottimizzato.** È la lettura
   più severa delle due frasi citate.
2. **Eccezione per il riferimento.** Il riferimento può contenere ricerca e valutazione semplici
   (negamax, alpha-beta senza altre potature, iterative deepening, valutazione di materiale) come
   oracolo dei risultati di ricerca. Non sono lavoro della Fase 2 e non la chiudono: la Fase 2 si
   apre solo dopo il gate della Fase 1.
3. **Due tipi di valori attesi.**
   - *Valori pubblicati:* una fonte pubblica è citata. Giudicano il riferimento dall'esterno.
   - *Valori di regressione:* valori che nessuna fonte pubblica riporta, per esempio l'output di
     questo engine registrato perché un cambiamento di comportamento si veda presto. Non sono un
     oracolo esterno: se uno non torna, il test fallisce, ma non dice da solo quale dei due
     valori è giusto.
4. **Dove sta la provenienza.** Nel file dei test,
   [`tests/test-perft.lisp`](../../tests/test-perft.lisp): le fonti nell'intestazione, e per ogni
   posizione quali profondità sono pubblicate. Non nei documenti.
5. **Che cosa giudica il gate di INV-C4.** Il riferimento si giudica dall'esterno solo sui valori
   pubblicati. I valori di regressione restano nel gate come controllo di non regressione.
6. `divide` (perft per ogni mossa radice) localizza un errore, confrontandolo con un valore
   pubblicato o con l'altro livello.
7. Chi cambia la generazione delle mosse, nel riferimento o nell'ottimizzato, esegue il perft
   prima di aprire una pull request.
8. I perft profondi sono un target a parte, `make perft-deep`, fuori da `make check`.

Classificazione: nessuna riduzione di lavoro introdotta.

## Conseguenze

- Il riferimento può avere oggi negamax, alpha-beta e iterative deepening
  ([`src/reference/search.lisp`](../../src/reference/search.lisp)) senza che il gate della Fase 1
  sia passato. Una ricerca dell'engine ottimizzato no.
- Un valore di regressione registra ciò che l'engine fa, giusto o sbagliato: un errore già
  presente quando il valore è stato registrato passa (RSK-05). Lo coglie solo un valore
  pubblicato.

## Alternative considerate

- *Lettura letterale di «search aggressiva»:* ammettere alpha-beta, PVS e TT anche nell'engine
  ottimizzato prima del gate, vietando solo potature e riduzioni. Scartata: la chiusura della
  specifica nomina proprio alpha-beta, PVS e TT tra ciò che viene dopo.
- *Nessuna ricerca, nemmeno nel riferimento, prima del gate:* scartata; la specifica chiede al
  riferimento di fare da oracolo anche per la ricerca, e le baseline servono a giudicare ciò che
  viene dopo.
- *Solo valori pubblicati nel gate:* toglierebbe le profondità che nessuna fonte pubblica
  riporta. Non scelta: quei valori mostrano presto un cambiamento di comportamento, purché
  dichiarati come regressione.

## Valutazione

- Rischi: RSK-05, RSK-11. Questione: [QA-10](../limiti-e-rischi.md#qa-10).
- Porterebbe a rivedere la lettura: una fonte pubblica che contraddica un valore di regressione,
  oppure la scelta dell'autore della lettura letterale.
