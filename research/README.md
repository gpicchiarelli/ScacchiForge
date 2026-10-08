# Ricerca

> **Fonte:** «EXPERIMENTAL SEARCH» e «RESEARCH METHODOLOGY» della
> [specifica](../docs/specifica/specifica-originale.md).

Questa cartella è il laboratorio. Qui vive il registro degli esperimenti: ogni tecnica nuova passa
da un record prima di entrare nell'engine. Un'idea che «sembra più veloce» non è una tecnica
accettata (INV-X3).

## Metodologia

La specifica fissa la sequenza. Ogni tappa ha una sezione nel [modello](TEMPLATE.md).

```
Hypothesis
   ↓
Mathematical rationale
   ↓
Implementation
   ↓
Microbenchmark
   ↓
Engine benchmark
   ↓
Self-play
   ↓
Statistical validation
   ↓
Accept / Reject
```

| Tappa | Sezione del modello | Che cosa produce |
|---|---|---|
| Hypothesis | 1 | un'affermazione che può essere smentita, con la metrica e l'effetto minimo |
| Mathematical rationale | 2 | perché dovrebbe funzionare, le ipotesi, l'etichetta proposta |
| Implementation | 3 | la modifica dietro un interruttore, i parametri in configurazione |
| Microbenchmark | 5 | il costo del meccanismo contro il calcolo che sostituisce |
| Engine benchmark | 6 | l'effetto su nodi, profondità, TT, allocazione, GC |
| Self-play | 7 | partite contro la baseline in condizioni dichiarate |
| Statistical validation | 8 | il test dichiarato prima dei dati e il suo esito |
| Accept / Reject | 9 | il verdetto e l'etichetta finale |

Il modello ha in più la sezione 4, la verifica di correttezza, e la 10, la riproducibilità.

> **Deciso (QA-17 → [ADR-0017](../docs/adr/0017-percorso-di-ricerca-per-le-alternative-exact.md))**
> — Per un'alternativa `[EXACT]` le cui uscite sono identiche a quelle dell'implementazione
> esistente o del riferimento, provate da un'equivalenza esaustiva o differenziale e dal perft, la
> sequenza è soddisfatta dall'equivalenza, dal microbenchmark e dal benchmark di engine,
> `make bench` con il registro dell'ambiente e una regola di decisione, eseguito su una revisione
> committata e pulita. Le tappe Self-play e Statistical validation non si applicano: a nodi fissi
> le partite sono identiche, e a tempo fisso una differenza di forza è una differenza di
> velocità, già misurata dal benchmark. L'equivalenza è un test in `make check` o in un target
> profondo documentato. Non vale per una tecnica che cambia un'uscita (il valore di una ricerca,
> la mossa scelta, il numero di nodi di una ricerca): per quella vale la sequenza intera.

## Che cosa si può sperimentare

La specifica elenca: potature alternative, LMR adattivo, ordinamento delle mosse appreso,
riduzioni apprese, estensioni apprese, finestre di aspirazione adattive, politiche alternative
per la TT, valutazioni alternative, algoritmi di ricerca alternativi.

## Requisiti di ogni esperimento

La specifica vuole che sia riproducibile, configurabile, confrontabile con la baseline, misurabile
e reversibile (INV-X5).

> **Proposta** — Come ciascun requisito si soddisfa.

| Requisito | Come |
|---|---|
| Riproducibile | semi dichiarati, comandi esatti, identità dei dati, registro dell'ambiente ([misure](../docs/misure.md#registro-dellambiente)) |
| Configurabile | ogni parametro importante in configurazione, non nel codice (INV-X7) |
| Confrontabile | la baseline è la revisione di base del record, sulla stessa macchina |
| Misurabile | la metrica e l'effetto minimo sono scritti nell'ipotesi, prima delle misure |
| Reversibile | un interruttore che spento restituisce la firma di ricerca della baseline ([verifica](../docs/verifica.md#regressione-di-ricerca)) |

## Come si apre un esperimento

> **Proposta**

1. Copiare [TEMPLATE.md](TEMPLATE.md) in `research/exp-nnnn-nome.md`. L'identificativo `EXP-nnnn`
   è stabile: non si rinumera e non si riusa.
2. Scrivere ipotesi e razionale prima del codice, e scegliere l'etichetta proposta di
   [classificazione](../docs/classificazione.md).
3. Implementare dietro un interruttore. Spento, il comportamento è quello della baseline.
4. Verificare la correttezza: perft se cambia la generazione, test differenziale se cambia
   l'ottimizzato, firma di ricerca ([verifica](../docs/verifica.md)).
5. Misurare nell'ordine: microbenchmark, benchmark di engine, self-play. Dichiarare il test
   statistico prima di vedere i dati.
6. Chiudere con il verdetto. Se accettato, la tecnica entra con la sua etichetta e la decisione
   diventa un ADR o una riga decisa della tabella di classificazione. Se rifiutato, il record
   resta: un risultato negativo è un risultato.

Gli stati di un record sono: Proposto, In corso, Accettato, Rifiutato, Abbandonato.

I file di supporto (configurazioni, dati di sintesi) stanno in `research/exp-nnnn-nome/`. Il
codice sperimentale non sta qui: vive nel livello a cui appartiene, dietro l'interruttore.

## Elenco degli esperimenti

| ID | Titolo | Stato |
|---|---|---|
| [EXP-0001](exp-0001-attacchi-dei-pezzi-a-lunga-gittata.md) | Attacchi dei pezzi a lunga gittata: magic bitboard contro raggi | Accettato, secondo [ADR-0017](../docs/adr/0017-percorso-di-ricerca-per-le-alternative-exact.md) |
| [EXP-0002](exp-0002-stato-incrementale-della-valutazione.md) | Stato incrementale della valutazione: aggiornamento in make e unmake contro ricalcolo | Accettato, secondo [ADR-0017](../docs/adr/0017-percorso-di-ricerca-per-le-alternative-exact.md) |
| [EXP-0003](exp-0003-ricerca-della-fase-3.md) | Ricerca della Fase 3: transposition table, PVS e NegaScout, ordinamento delle mosse | Proposto |

EXP-0001 è stato aperto dopo che la tecnica era già il default di
[ADR-0016](../docs/adr/0016-attacchi-dei-pezzi-a-lunga-gittata.md), allora in stato Proposta,
contro l'ordine che questa pagina chiede. Lo scostamento da INV-X3 era
[QA-17](../docs/limiti-e-rischi.md#qa-17), risolta il 2026-10-04 da
[ADR-0017](../docs/adr/0017-percorso-di-ricerca-per-le-alternative-exact.md); con le condizioni
di quell'ADR il record è chiuso, Accettato (sezione 9 del record).

EXP-0002 è stato aperto dopo che lo stato incrementale della valutazione era entrato nel codice
(commit cc6fceb), proposto da
[ADR-0018](../docs/adr/0018-definizione-della-valutazione-classica.md) e
[ADR-0019](../docs/adr/0019-valutazione-e-ricerca-del-livello-ottimizzato.md), in stato Proposta:
anche questo contro l'ordine che questa pagina chiede. Lo stato ha l'equivalenza con il calcolo
da zero, non la misura che ADR-0017 chiede; il record ne ha scritto la regola di decisione prima
della misura, poi la variante senza stato è entrata nel commit dd5a2a5, e l'esecuzione
confermativa su quel commit ha chiuso il record, Accettato, il 2026-10-08 (sezione 9 del record).

EXP-0003 è stato aperto con il codice della Fase 3, non prima: la transposition table, PVS e
NegaScout e l'ordinamento delle mosse sono entrati nel codice insieme al record, proposti da
[ADR-0021](../docs/adr/0021-transposition-table-del-livello-ottimizzato.md),
[ADR-0022](../docs/adr/0022-pvs-negascout-e-tipi-di-nodo.md) e
[ADR-0023](../docs/adr/0023-ordinamento-delle-mosse-della-fase-3.md), in stato Proposta. Le tre
tecniche cambiano i nodi di una ricerca, un'uscita: ADR-0017 non si applica, e per accettarle
servono anche self-play e validazione statistica, che il repository non può ancora eseguire
(Fase 10). Il valore lo controllano i test, come evidenza per campioni; l'efficacia non è
misurata con la sequenza intera.
