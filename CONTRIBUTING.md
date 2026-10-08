# Contribuire

ScacchiForge è una piattaforma di ricerca su chess engine in Common Lisp/SBCL. Si contribuisce con
codice, test, misure, esperimenti e documentazione. Le fasi e i loro gate sono nella
[roadmap](docs/roadmap.md).

## Principi

- **Ogni riduzione del lavoro si classifica** con almeno una delle sette etichette
  ([classificazione](docs/classificazione.md)). Non si confonde un'euristica con un teorema.
- **La correttezza viene prima.** L'engine ottimizzato si giudica con il riferimento
  ([architettura](docs/architettura.md)).
- **Nessuna cifra di prestazione senza una misura riproducibile** ([misure](docs/misure.md)).
  Altrimenti è un target o una stima, e lo si scrive.
- **Solo SBCL tra i requisiti Lisp.** Nessuna libreria di terzi
  ([ADR-0004](docs/adr/0004-nessuna-dipendenza-esterna-e-harness-proprio.md)).
- La [specifica](docs/specifica/specifica-originale.md) è la fonte di verità; la cambia solo un
  ADR che dichiara l'emendamento.

## Flusso

1. Una modifica di requisito, di architettura o di convenzione parte da un
   [ADR](docs/adr/README.md) (modello: [0000](docs/adr/0000-modello.md)). Un ADR accettato non si
   riscrive, si sostituisce.
2. Una tecnica nuova di ricerca o di valutazione parte da un record in [`research/`](research/README.md),
   dal [modello](research/TEMPLATE.md): ipotesi, razionale, misure, esito. Per un'alternativa
   `[EXACT]` con le stesse uscite il percorso è quello di
   [ADR-0017](docs/adr/0017-percorso-di-ricerca-per-le-alternative-exact.md).
3. Ogni riduzione di lavoro porta la sua etichetta: nel docstring, nel commit, nella pull request.
4. Se cambia la generazione delle mosse, si esegue il perft prima della pull request.
5. Se cambia il livello ottimizzato, si esegue il test differenziale contro il riferimento. Una
   modifica che dichiara `EXACT` non cambia la firma di ricerca.
6. La documentazione si aggiorna nello **stesso commit** della modifica che la rende falsa.
7. Gli identificativi (`INV-`, `ADR-`, `QA-`, `RSK-`, `EXP-`, `TT-`) sono stabili: non si
   rinumerano.

## Prima di aprire una pull request

```bash
make check
```

Compila senza avvisi, esegue i test, il linter, gli autotest degli strumenti (linter, controllo
dei link, caricamento rigoroso) e il controllo di link e ancore. SBCL è l'unico requisito Lisp; i
target usano make (è stato usato solo GNU make). `make help` elenca tutti i target
([Makefile](Makefile)); i perft profondi (`make perft-deep`), il test differenziale su milioni
di posizioni (`make differential-deep`), i test con il hot path a `safety 3`
(`make test-checked`), i benchmark (`make bench`), l'ispezione del hot path (`make hot-path`), la
ricerca dei numeri magici (`make magics`) e il ricalcolo della firma di ricerca
(`make signatures`, che riscrive `tests/search-signature.sexp`) sono fuori da `make check`. La
variabile d'ambiente
`SCF_SLIDERS` (`fixed-magic`, `magic`, `ray`) sceglie gli attacchi dei pezzi a lunga gittata con
cui si compila il livello ottimizzato, per ogni target che carica il sistema
([ADR-0016](docs/adr/0016-attacchi-dei-pezzi-a-lunga-gittata.md)); `SCF_EVAL_STATE`
(`incremental`, `recompute`) sceglie allo stesso modo se make e unmake tengano lo stato
incrementale della valutazione ([EXP-0002](research/exp-0002-stato-incrementale-della-valutazione.md)). Ognuno di questi target
ricompila ogni sistema di `scacchiforge.asd` che carica (`tools/load.lisp`), quindi non riusa i
file compilati da un target precedente con un altro `SCF_SLIDERS` o da `make test-checked`. Un
caricamento non forzato, fatto a mano, di file compilati con un altro `SCF_SLIDERS` o con
un'altra policy si ferma con un errore (`check-compiled-choice`,
[`src/optimized/policy.lisp`](src/optimized/policy.lisp)); lo stesso fa `:force t` di ASDF su un
sistema diverso da `scacchiforge`, che ricompila solo il sistema nominato. I target si eseguono
uno alla volta: compilano negli stessi file di `build/`.

In più, secondo ciò che si cambia:

| Se cambia | Serve anche |
|---|---|
| la generazione delle mosse (riferimento o ottimizzato) | il perft ([verifica](docs/verifica.md#perft)); `make perft-deep` quando tocca casi che i perft rapidi non coprono |
| il livello ottimizzato | il test differenziale (`make test`; `make differential-deep` su milioni di posizioni); la firma di ricerca invariata se la classe è `EXACT` |
| il hot path del livello ottimizzato | `make test-checked` e `make hot-path` ([ADR-0014](docs/adr/0014-policy-di-compilazione-del-livello-ottimizzato.md)) |
| gli attacchi dei pezzi a lunga gittata, il seme o la ricerca dei numeri magici | `make test` con `SCF_SLIDERS` impostata a ciascuna implementazione; `make magics` se cambiano il seme, la ricerca o le disposizioni delle tavole (lo strumento cerca senza costruire prima le tavole dai numeri nel file: [ADR-0016](docs/adr/0016-attacchi-dei-pezzi-a-lunga-gittata.md#conseguenze)); `make bench` per le misure, e il record [EXP-0001](research/exp-0001-attacchi-dei-pezzi-a-lunga-gittata.md) |
| lo stato incrementale della valutazione, make e unmake | `make test` e `SCF_EVAL_STATE=recompute make test`; `make differential-deep` |
| una potatura, una riduzione, un'estensione, la valutazione | un record di ricerca e un self-play con test statistico |
| un'uscita della ricerca: un peso o una formula della valutazione, l'ordine delle mosse, la profondità o le posizioni della firma | `make signatures` nello stesso commit, che riscrive `tests/search-signature.sexp`; la differenza del file si legge prima del commit, e il messaggio dice quali componenti cambiano e perché. Non si esegue per far passare una modifica `[EXACT]`: se la firma cambia, la modifica non è `[EXACT]` o ha un errore ([verifica](docs/verifica.md#regressione-di-ricerca)) |
| una dichiarazione di velocità | microbenchmark e benchmark di engine contro la baseline, con il registro dell'ambiente |
| un'alternativa `[EXACT]` con le stesse uscite dell'implementazione esistente o del riferimento | l'equivalenza, esaustiva o differenziale, come test in `make check` o in un target profondo documentato, e il perft; il microbenchmark e `make bench` con una regola di decisione, eseguito su una revisione committata e pulita; niente self-play né validazione statistica ([ADR-0017](docs/adr/0017-percorso-di-ricerca-per-le-alternative-exact.md)) |
| la documentazione | `make links` |

## Classificazione

> **Deciso (autore → [ADR-0011](docs/adr/0011-convenzioni-di-classificazione.md))** — Formato
> in [classificazione](docs/classificazione.md#come-si-marca).

Nel docstring (in inglese):

```lisp
(defun null-move-applicable-p (position depth beta)
  "Decide whether the null-move test is tried at this node.

Classification: [HEURISTIC]
Basis: assumes that passing never helps the side to move; false in zugzwang.
Evidence: none yet."
  ...)
```

Nei commit e nelle pull request, una riga finale `Classification: [TAG]`, oppure
`Classification: none` se la modifica non riduce lavoro. Nel dubbio, l'etichetta più debole.

## Commit

> **Deciso (autore → [ADR-0009](docs/adr/0009-convenzione-linguistica.md))** — Messaggio in
> italiano; la riga `Classification:` resta in inglese. Che il corpo dica quale test sostiene
> l'etichetta è la marcatura di [ADR-0011](docs/adr/0011-convenzioni-di-classificazione.md).

> **Proposta** — Un titolo breve e un corpo che dice perché, come nell'esempio.

```
Controlla la legalità della mossa letta dalla TT

La mossa TT si verifica come legale nella posizione corrente prima di
eseguirla (INV-C6). Test: entry alterate nel test di TT.

Classification: none
```

## Convenzioni

- Documentazione in italiano; codice, identificativi, docstring e nomi dei test in inglese. I
  termini tecnici consolidati restano in inglese; l'elenco è nel
  [glossario](docs/glossario.md#convenzione-linguistica).
- Ciò che non viene dalla specifica è marcato `Proposta`, `Deciso (FONTE → ADR-nnnn)` o
  `Aperto (QA-nn)` ([convenzioni](docs/README.md#convenzioni)).
- Una cifra di prestazione ha accanto il comando che la produce e l'ambiente
  ([registro dell'ambiente](docs/misure.md#registro-dellambiente)).
- Un miglioramento non si dichiara sulla base di una sola partita o di un solo benchmark.

## Licenza e originalità

Contribuendo accetti che il contributo sia distribuito con la licenza BSD-2-Clause del progetto
([LICENSE](LICENSE)). Il codice è originale: nessun codice di Stockfish o derivato, nessuna
implementazione proprietaria di altri engine
([ADR-0007](docs/adr/0007-licenza-bsd-2-clause-e-originalita.md)). Costanti o dati presi da una
fonte esterna citano fonte e licenza
([ADR-0013](docs/adr/0013-interpretazione-operativa-dell-originalita.md)).
