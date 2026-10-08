# Roadmap

> **Fonte:** «ROADMAP» della [specifica](specifica/specifica-originale.md), con «EVALUATION» per
> la Fase 2, «SEARCH TREE CLASSIFICATION» per gli elementi senza fase e la chiusura di
> «PHILOSOPHY». Le fasi sono le sue, dalla 0 alla 12: tredici fasi. I gate sono una proposta di
> questo repository.

## Come si legge

Una fase è chiusa quando passa il proprio gate, non prima. Questo documento non ha durate né
colonne di stato: lo stato di una fase è l'esito del suo gate, e si legge eseguendo i controlli.
Le uniche date sono quelle delle decisioni dell'autore: il passaggio alla Fase 2
([Fase 1](#fase-1)) e quello alla Fase 3 ([Fase 2](#fase-2)).

La specifica indica anche la prima tappa concreta, molto disciplinata:

```
reference chess model → bitboard optimized model → Perft/fuzz differential testing → benchmark harness
```

Solo quando questa base è inattaccabile si passa ad alpha-beta, PVS e TT.

> **Deciso (autore → [ADR-0012](adr/0012-lettura-del-gate-di-perft.md))** — Il gate della
> Fase 1 è condizione per ogni fase successiva dell'engine ottimizzato. La specifica dice «prima
> di introdurre search aggressiva» nella sezione sul perft (INV-X8) e «solo quando quella base è
> inattaccabile» nella chiusura. Si adotta la lettura più severa
> ([ADR-0012](adr/0012-lettura-del-gate-di-perft.md)).
>
> Eccezione: il riferimento può contenere ricerca e valutazione semplici come oracolo. La
> specifica gli chiede di giudicare anche i «search results dove applicabile» («REFERENCE
> ENGINE») e vuole minimax, negamax, alpha-beta e iterative deepening «come baseline» («SEARCH
> FOUNDATION»). Il gate vale per la ricerca dell'engine ottimizzato. Le baseline del riferimento
> non sono lavoro della Fase 2 e non la chiudono: la Fase 2 si apre solo dopo il gate della
> Fase 1.

Gate comuni a tutte le fasi, in [verifica](verifica.md#gate-di-fase): `make check` passa, ogni
riduzione di lavoro è classificata, ogni nuova regola inviolabile è in
[invarianti](invarianti.md), la documentazione è aggiornata.

## Fase 0

**Specifica:** repository, build system, test, benchmark framework, reference model.

**Gate (proposta):**

| Voce | Si controlla con |
|---|---|
| `make check` passa su un checkout pulito, con SBCL come unico requisito Lisp (INV-A1, [ADR-0004](adr/0004-nessuna-dipendenza-esterna-e-harness-proprio.md)). | `make check` su un checkout nuovo; la CI lo esegue così a ogni push su `main` e a ogni pull request |
| Il modello di riferimento ha test sui tipi e sulle transizioni di stato. | `make test`, suite `core`, `move`, `fen`, `make-unmake` e `zobrist` |
| Il framework di benchmark produce un risultato con il registro dell'ambiente ([misure](misure.md#registro-dellambiente)). | `make bench`, che stampa il registro prima delle misure |
| La documentazione, gli ADR e i link della base esistono e si risolvono. | `make links` |

> **Aperto (QA-10)** — La specifica mette il modello di riferimento in Fase 0 e la generazione
> legale e il perft in Fase 1. Un riferimento senza generazione legale non è un oracolo.
> Proposta: la Fase 0 chiude l'infrastruttura e il modello di stato; la Fase 1 chiude generazione
> legale, make/unmake e perft di entrambi i livelli. [QA-10](limiti-e-rischi.md#qa-10).

## Fase 1

**Specifica:** bitboard, Position, Move, generazione legale delle mosse, make/unmake, Perft.

**Gate (proposta):**

- Perft uguale ai valori attesi per riferimento e ottimizzato, su tutte le posizioni di prova:
  ai valori pubblicati, che giudicano il riferimento dall'esterno, e ai valori di regressione
  (INV-C4, [ADR-0008](adr/0008-perft-gate-obbligatorio.md),
  [ADR-0012](adr/0012-lettura-del-gate-di-perft.md)).
- Il test differenziale confronta gli insiemi di mosse legali dei due livelli, non solo i
  conteggi, sulle posizioni di prova e del fuzzer (INV-C1).
- La suite dei casi speciali ([verifica](verifica.md#suite-dei-casi-speciali)) passa.
- Il fuzzer, con semi dichiarati, non trova violazioni di INV-C1, INV-C2 e dello stato
  incrementale della posizione (INV-C3). Ogni fallimento diventa un test di regressione.
- `Move` è un valore packed e i buffer di mosse sono preallocati (INV-A5).

Oggi il lavoro passa alla Fase 2, per decisione dell'autore del 2026-10-04. Ognuna delle cinque
voci qui sopra ha il comando che la mostra, e quei comandi sono terminati con codice 0 sulla
macchina dell'autore (macOS arm64, SBCL 2.6.9); `make check`, che esegue le suite di `make test`,
è passato anche nella CI sul commit c15291e (run 37183294754, [QA-12](limiti-e-rischi.md#qa-12)).
Il [README](../README.md#status), nella sezione *Status*, rivaluta il gate voce per voce. Le
regole che ogni gate aggiunge ([verifica](verifica.md#gate-di-fase)) si controllano in revisione,
e una revisione dell'autore del lavoro della Fase 1 non è registrata: quella voce non è
soddisfatta, è superata dalla decisione dell'autore di procedere.

## Fase 2

**Specifica:** negamax, alpha-beta, iterative deepening, valutazione classica.

Dalla sezione «EVALUATION», i termini della valutazione classica: materiale, piece-square tables,
mobilità, sicurezza del re, struttura pedonale, pedoni passati, spazio, iniziativa, minacce. Con
rappresentazioni incrementali dove conviene.

**Gate (proposta):**

- La ricerca dell'engine ottimizzato restituisce a profondità fissa lo stesso valore della
  ricerca del riferimento (INV-C1, «dove applicabile»).
- Alpha-beta e negamax semplice restituiscono lo stesso valore a profondità fissa su un insieme di
  posizioni; il valore non cambia permutando le mosse con un seme
  ([verifica](verifica.md#proprietà-di-alpha-beta-puro)).
- L'iterative deepening restituisce a profondità `d` lo stesso valore della ricerca diretta.
- Ogni termine incrementale della valutazione è uguale al ricalcolo (INV-C3). La valutazione è
  invariante per scambio dei colori, vista da chi muove.
- La prima firma di ricerca ([verifica](verifica.md#regressione-di-ricerca)) è registrata.

La Fase 2 è chiusa dalla decisione dell'autore del 2026-10-08 di procedere alla Fase 3, e il
lavoro passa alla Fase 3. Ognuna delle cinque voci qui sopra ha il comando che la mostra
(`make test`, e `make differential-deep` per il valore della ricerca e lo stato incrementale), e
quei comandi sono terminati con codice 0 sulla macchina dell'autore (macOS arm64, SBCL 2.6.9);
`make check`, che esegue `make test`, è passato anche nella CI sui commit cc6fceb e b3190dc
([QA-12](limiti-e-rischi.md#qa-12)). Il
[README](../README.md#status), nella sezione *Status*, dà le voci con i loro comandi. Le regole
che ogni gate aggiunge ([verifica](verifica.md#gate-di-fase)) si controllano in revisione, e una
revisione dell'autore del lavoro della Fase 2 non è registrata: quella voce non è soddisfatta, è
superata dalla decisione dell'autore di procedere, come per la Fase 1.

## Fase 3

**Specifica:** Zobrist, TT, PVS/NegaScout, ordinamento delle mosse.

**Gate (proposta):**

- La chiave incrementale è uguale a quella ricalcolata (INV-C3). Le chiavi vengono dal generatore
  deterministico ([ADR-0005](adr/0005-chiavi-zobrist-da-prng-deterministico.md)).
- In [modalità di verifica](verifica.md#modalità-di-verifica-della-tt), che soddisfa TT-1…TT-4,
  la ricerca con TT restituisce il valore della ricerca senza TT; i falsi riscontri sono scartati
  e contati; la mossa TT è controllata come legale (INV-C5, INV-C6). Le posizioni GHI provano
  l'opzione scelta per [QA-02](limiti-e-rischi.md#qa-02), non questa uguaglianza.
- PVS e NegaScout restituiscono il valore di alpha-beta.
- Il tipo di nodo (PV, Cut, All) è esplicito nella ricerca e registrato: atteso prima di cercare
  il nodo, osservato dopo ([architettura](architettura.md#ricerca)).
- Si misurano hit rate, costo della lookup, diverse dimensioni e politiche di sostituzione, e
  l'efficienza dell'ordinamento a parte ([misure](misure.md)). Non si assume che più memoria
  renda di più.

Il codice della Fase 3 esiste nel livello ottimizzato: la transposition table con le modalità
normale e di verifica, l'ordinamento delle mosse, PVS e NegaScout con i tipi di nodo, la ricerca di
default e la sua firma ([ADR-0021](adr/0021-transposition-table-del-livello-ottimizzato.md),
[ADR-0022](adr/0022-pvs-negascout-e-tipi-di-nodo.md),
[ADR-0023](adr/0023-ordinamento-delle-mosse-della-fase-3.md), in stato Proposta). Quale comando
mostra ogni voce del gate è nel [README](../README.md#status). Il gate non è dichiarato chiuso: gli
ADR sono proposte, nessuna revisione dell'autore è registrata, e le tre tecniche cambiano i nodi
di una ricerca, per cui INV-X3 chiede il percorso intero di ricerca, self-play compreso, che non
è fatto ([EXP-0003](../research/exp-0003-ricerca-della-fase-3.md), Proposto).

## Fase 4

**Specifica:** quiescenza, SEE, killer/history/countermove, aspirazione.

**Gate (proposta):**

- Il SEE ottimizzato è uguale a un SEE di riferimento semplice, con il proprio modello dichiarato,
  sulle posizioni del fuzzer.
- L'ordinamento (killer, history, countermove) non cambia il valore di alpha-beta puro; la sua
  efficienza è misurata.
- L'aspirazione con ri-ricerca restituisce il valore della ricerca a finestra piena (−∞, +∞).
- Se l'ordinamento o la finestra dipendono dal tipo di nodo, lo dichiarano nella classificazione.
- La quiescenza è `HEURISTIC`: il suo effetto passa da un record di ricerca (self-play con test
  statistico), non da un'affermazione.

## Fase 5

**Specifica:** null move, LMR, futility, razoring, ProbCut, singular extensions.

**Gate (proposta):**

- Ogni tecnica segue la [metodologia](../research/README.md): ipotesi, razionale, implementazione,
  microbenchmark, benchmark di engine, self-play, validazione statistica, accettazione o rifiuto
  (INV-X3).
- Ogni tecnica ha classificazione, parametri in configurazione (INV-X7) e un interruttore che, da
  spento, restituisce la firma della fase precedente.
- Ogni tecnica dichiara se e come dipende dal tipo di nodo (PV, Cut, All). La specifica chiede di
  usarlo per modulare potature, riduzioni ed estensioni.
- Null move: la suite di zugzwang ([verifica](verifica.md#suite-per-tecnica)).
- LMR: la funzione `R = f(...)` della specifica è studiata, non sostituita da una soglia fissa.
- ProbCut: il modello statistico e i dati con cui si stimano i parametri sono dichiarati.

## Fase 6

**Specifica:** ricerche alternative: MTD(f), SSS*, DUAL*, transposition-driven search.

**Gate (proposta):**

- Ognuna restituisce lo stesso valore di alpha-beta a profondità fissa, in
  [modalità di verifica](verifica.md#modalità-di-verifica-della-tt).
- Il confronto con PVS è un benchmark scientifico su nodi, tempo, profondità, hit rate della TT,
  cutoff rate, forza e stabilità. Nessun algoritmo è assunto migliore a priori.
- Prima di implementare la transposition-driven search si chiude [QA-13](limiti-e-rischi.md#qa-13).
  La lettura candidata è uno schema di ricerca distribuita: se adottata, il lavoro passa alla
  Fase 11.

## Fase 7

**Specifica:** profiling aggressivo, ottimizzazione della cache, dispatch CPU, SIMD.

**Gate (proposta):**

- Ogni ottimizzazione `EXACT` lascia invariata la firma di ricerca e passa il test differenziale.
- Prima e dopo: microbenchmark e benchmark di engine, allocazione nel hot path, registro
  dell'ambiente. Disassembly dove si afferma qualcosa sul codice generato.
- Ogni backend ha il fallback generico; il dispatch è isolato (INV-H1, INV-H4).
- Le questioni su cui l'ottimizzazione poggia sono chiuse da un esperimento, non da un'ipotesi:
  [QA-03](limiti-e-rischi.md#qa-03), [QA-04](limiti-e-rischi.md#qa-04),
  [QA-05](limiti-e-rischi.md#qa-05).

## Fase 8

**Specifica:** NNUE e accumulatore incrementale.

**Gate (proposta):**

- Il riferimento scalare di inferenza definisce l'aritmetica ([QA-15](limiti-e-rischi.md#qa-15)).
- L'accumulatore aggiornato incrementalmente è uguale a quello ricalcolato (INV-C3).
- Il formato della rete ha una versione. L'addestramento è riproducibile: identità dei dati, seme,
  procedura.
- La forza si valida con test statistico, a parità di tempo CPU contro la valutazione classica, non
  a parità di nodi: la rete costa di più per nodo.

## Fase 9

**Specifica:** AVX2, VNNI, AVX-512, NEON, SVE/SVE2.

**Gate (proposta):**

- Ogni backend è bit-identico al riferimento scalare (INV-H3).
- Se la funzione della CPU manca, il dispatch sceglie il fallback.
- Si misura ogni backend, sull'hardware che lo possiede, compreso l'effetto sulla frequenza. Non
  si afferma che AVX-512 sia più veloce di AVX2 senza una misura.
- Un backend non eseguito su hardware reale non si dichiara verificato: [QA-12](limiti-e-rischi.md#qa-12).

## Fase 10

**Specifica:** tuning automatico, self-play, ottimizzazione dei parametri.

**Gate (proposta):**

- Il self-play è riproducibile: con gli stessi semi e a nodi fissi, le stesse partite.
- Lo strumento statistico è provato su partite simulate con Elo noto ([misure](misure.md#statistica)).
- I parametri sono fuori dal codice (INV-X7). Un risultato di tuning registra seme, identità dei
  dati, baseline e una valutazione su dati non usati per tarare.

## Fase 11

**Specifica:** ricerca parallela, Lazy SMP, architettura consapevole di NUMA (*NUMA-aware*).

**Gate (proposta):**

- Con un thread la firma di ricerca è quella della fase precedente.
- L'integrità delle entry della TT in concorrenza è provata con test di stress
  ([QA-07](limiti-e-rischi.md#qa-07)). Nessun lock globale nel percorso critico: la specifica
  chiede di evitarli (INV-A6), il gate li esclude.
- La scalabilità si misura come forza per CPU-secondo al crescere dei thread, non come solo NPS;
  si studiano contesa, coerenza di cache, false sharing e banda di memoria.
- La ricerca parallela non è deterministica: si valida con statistica, non con uguaglianza.
- Le conclusioni su NUMA valgono solo dove c'è hardware NUMA su cui misurare.

## Fase 12

**Specifica:** politiche di ricerca apprese sperimentali e potatura adattiva.

**Gate (proposta):**

- Ogni politica appresa ha un record di ricerca con la sua classificazione, identità dei dati e
  seme. Riduzioni ed estensioni apprese: `HEURISTIC`, `LEARNED`, efficacia `EMPIRICAL`.
  Ordinamento appreso: `EXACT` sul valore di alpha-beta puro, `HEURISTIC` da quando una riduzione
  dipende dall'ordine; modello `LEARNED`, efficacia `EMPIRICAL`
  ([classificazione](classificazione.md#ottimizzazione-dei-parametri)).
- Ogni politica può essere spenta e tornare alla politica fissa (INV-X5).
- Si valida con test statistico a parità di tempo CPU contro la baseline, e i gate di correttezza
  restano soddisfatti.

## Senza fase

> **Aperto (QA-11)** — La specifica descrive il server, il corpus di posizioni, l'infrastruttura
> di addestramento, i test cross-platform e la classificazione dei nodi in PV, Cut e All
> («SEARCH TREE CLASSIFICATION»), ma non li assegna a una fase.
> [QA-11](limiti-e-rischi.md#qa-11).

> **Proposta** — Il corpus cresce con la Fase 1, che ne ha bisogno per fuzzer e perft;
> l'addestramento segue la Fase 8; la regressione cross-platform accompagna ogni fase sulle
> piattaforme raggiungibili; il server si decide con un ADR. La classificazione dei nodi entra
> con PVS nella Fase 3, che distingue già i nodi PV dagli altri; le fasi 4 e 5 la usano per
> modulare finestra, ordinamento, potature, riduzioni ed estensioni. Oggi è nel codice della
> Fase 3, registrata e non usata ([ADR-0022](adr/0022-pvs-negascout-e-tipi-di-nodo.md),
> Proposta).
