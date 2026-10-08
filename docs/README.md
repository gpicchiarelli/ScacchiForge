<p align="center">
  <picture>
    <source media="(prefers-color-scheme: dark)" srcset="../assets/img/mark-dark.svg">
    <img src="../assets/img/mark-light.svg" alt="" width="48" height="48">
  </picture>
</p>

# Documentazione di ScacchiForge

Questa cartella trasforma la [specifica originale](specifica/specifica-originale.md) in documenti
tematici navigabili. Ogni sezione della specifica rimanda ad almeno un documento: lo mostra la
tabella [dalla specifica ai documenti](#dalla-specifica-ai-documenti).

I documenti descrivono come il progetto è progettato e verificato. Lo stato di una fase è l'esito
del suo gate ([roadmap](roadmap.md)): una fase è chiusa quando il gate passa, mai prima. Che cosa
esiste oggi nel repository è elencato in
[architettura](architettura.md#che-cosa-esiste-oggi-e-che-cosa-è-previsto); che il codice esista
non dice che sia corretto.

## Come leggere

Ordine consigliato per chi arriva per la prima volta:

1. [Classificazione](classificazione.md) — le sette etichette: che cosa si può affermare di una
   tecnica, e che cosa no.
2. [Architettura](architettura.md) — i livelli, il riferimento e l'ottimizzato, la deduplicazione.
3. [Invarianti](invarianti.md) — le regole che nessuna implementazione può violare.
4. [Verifica](verifica.md) — perft, fuzzing, test differenziale, gate.
5. [Misure](misure.md) — benchmark, metriche, self-play, statistica.
6. [Roadmap](roadmap.md) — le fasi 0…12 e i loro gate.
7. [Limiti e rischi](limiti-e-rischi.md) — ciò che non si sa, con l'esperimento o la decisione
   (ADR) che lo chiude.
8. [ADR](adr/README.md) — le decisioni e il loro perché.

## Mappa dei documenti

La colonna «Fonte» riporta le sezioni che l'intestazione di ogni documento cita.

| Documento | Contenuto | Fonte |
|---|---|---|
| [Classificazione](classificazione.md) | Le sette etichette, le regole d'uso, la marcatura, le ipotesi della TT, la tabella delle tecniche con la classe proposta | PRINCIPIO FONDAMENTALE, SEARCH REDUCTIONS AND PRUNING, TRANSPOSITION TABLE; per i nomi della tabella delle tecniche anche SEARCH FOUNDATION, LMR, NULL MOVE, QUIESCENCE, MOVE ORDERING, DEDUPLICATION, EVALUATION, NNUE, MOVE GENERATION, CPU OPTIMIZATION, NATIVE MICROKERNELS, MULTI-THREAD, PARAMETER OPTIMIZATION |
| [Architettura](architettura.md) | Sette separazioni, struttura, stato del repository, regole tra i livelli, uguaglianza tra livelli, rappresentazione e generazione delle mosse, ricerca, deduplicazione, valutazione e NNUE, hardware, SBCL, multi-thread, server | ARCHITETTURA GENERALE, REFERENCE ENGINE, BOARD REPRESENTATION, MOVE REPRESENTATION, MOVE GENERATION, SEARCH FOUNDATION, SEARCH TREE CLASSIFICATION, DEDUPLICATION, EVALUATION, NNUE, SEARCH + EVALUATION, PARAMETER OPTIMIZATION, CPU OPTIMIZATION, COMMON LISP / SBCL, MULTI-THREAD, NUMA, SERVER ARCHITECTURE, PHILOSOPHY |
| [Verifica](verifica.md) | Strategia di verifica, perft, casi speciali, fuzzing, test differenziale, firma di ricerca, modalità di verifica della TT, gate | REFERENCE ENGINE, MOVE GENERATION, PERFT, NULL MOVE, NNUE, TESTING, CROSS-PLATFORM, POSITION CORPUS, PERFORMANCE GATES |
| [Misure](misure.md) | Due livelli di benchmark, gerarchia delle metriche, self-play, statistica, corpus, baseline | OBIETTIVO MATEMATICO, PERFORMANCE INFRASTRUCTURE, PERFORMANCE GATES, METRICHE PRINCIPALI, SELF-PLAY, POSITION CORPUS, RESEARCH METHODOLOGY; per le richieste di misura anche SEARCH FOUNDATION, MOVE ORDERING, TRANSPOSITION TABLE |
| [Roadmap](roadmap.md) | Fasi 0…12 con il gate di ciascuna; elementi senza fase | ROADMAP, EVALUATION, SEARCH TREE CLASSIFICATION, PHILOSOPHY |
| [Valutazione](valutazione.md) | La definizione esatta della valutazione classica (proposta, [ADR-0018](adr/0018-definizione-della-valutazione-classica.md)): i nove termini con formule e pesi interi, fase e miscela con arrotondamento, punto di vista, simmetria dei colori, stato incrementale, limite del punteggio, convenzioni per la ricerca, esempi calcolati, provenienza (le coincidenze note con engine pubblicati) | EVALUATION, REFERENCE ENGINE, SEARCH FOUNDATION, DEDUPLICATION, SEARCH + EVALUATION |
| [Invarianti](invarianti.md) | Elenco numerato (`INV-…`) con fonte, stato e verifica | i vincoli verificabili; la sezione di ciascuno è nella colonna «Fonte» dell'elenco |
| [Glossario](glossario.md) | Termini, con l'originale inglese; l'elenco dei termini che restano in inglese | — |
| [Limiti e rischi](limiti-e-rischi.md) | Limiti dichiarati, osservazioni su SBCL, rischi `RSK-…`, questioni aperte `QA-…` | COMMON LISP / SBCL, NATIVE MICROKERNELS, CPU OPTIMIZATION, TRANSPOSITION TABLE, MULTI-THREAD, CROSS-PLATFORM |
| [ADR](adr/README.md) | Registro delle decisioni | ogni ADR cita le sue sezioni nel campo «Rapporto con la specifica» |
| [Ricerca](../research/README.md) | Metodologia e registro degli esperimenti | EXPERIMENTAL SEARCH, RESEARCH METHODOLOGY |

La [specifica originale](specifica/specifica-originale.md) è il testo del committente, riportato
senza modifiche.

## Dalla specifica ai documenti

Ogni sezione della specifica, nell'ordine in cui compare, con i documenti la cui intestazione la
cita e l'ADR accettato che la registra. Il vincolo di originalità dell'introduzione è in
[ADR-0007](adr/0007-licenza-bsd-2-clause-e-originalita.md) e in INV-X9.

| Sezione della specifica | Documenti | ADR accettato |
|---|---|---|
| PRINCIPIO FONDAMENTALE | [classificazione](classificazione.md) | [0003](adr/0003-classificazione-delle-riduzioni-di-lavoro.md) |
| OBIETTIVO MATEMATICO | [misure](misure.md) | [0006](adr/0006-gerarchia-delle-metriche.md) |
| ARCHITETTURA GENERALE | [architettura](architettura.md) | [0002](adr/0002-implementazione-di-riferimento-come-oracolo.md) |
| REFERENCE ENGINE | [architettura](architettura.md), [verifica](verifica.md), [valutazione](valutazione.md) | [0002](adr/0002-implementazione-di-riferimento-come-oracolo.md) |
| BOARD REPRESENTATION | [architettura](architettura.md) | — |
| MOVE REPRESENTATION | [architettura](architettura.md) | — |
| MOVE GENERATION | [classificazione](classificazione.md), [architettura](architettura.md), [verifica](verifica.md) | — |
| PERFT | [verifica](verifica.md) | [0008](adr/0008-perft-gate-obbligatorio.md) |
| SEARCH FOUNDATION | [classificazione](classificazione.md), [architettura](architettura.md), [misure](misure.md), [valutazione](valutazione.md) | — |
| SEARCH TREE CLASSIFICATION | [architettura](architettura.md), [roadmap](roadmap.md) | — |
| SEARCH REDUCTIONS AND PRUNING | [classificazione](classificazione.md) | [0003](adr/0003-classificazione-delle-riduzioni-di-lavoro.md) |
| LMR | [classificazione](classificazione.md) | — |
| NULL MOVE | [classificazione](classificazione.md), [verifica](verifica.md) | — |
| QUIESCENCE | [classificazione](classificazione.md) | — |
| MOVE ORDERING | [classificazione](classificazione.md), [misure](misure.md) | — |
| TRANSPOSITION TABLE | [classificazione](classificazione.md), [misure](misure.md), [limiti e rischi](limiti-e-rischi.md) | — |
| DEDUPLICATION | [classificazione](classificazione.md), [architettura](architettura.md), [valutazione](valutazione.md) | [0003](adr/0003-classificazione-delle-riduzioni-di-lavoro.md) |
| EVALUATION | [classificazione](classificazione.md), [architettura](architettura.md), [roadmap](roadmap.md), [valutazione](valutazione.md) | — |
| NNUE | [classificazione](classificazione.md), [architettura](architettura.md), [verifica](verifica.md) | — |
| SEARCH + EVALUATION | [architettura](architettura.md), [valutazione](valutazione.md) | — |
| PARAMETER OPTIMIZATION | [classificazione](classificazione.md), [architettura](architettura.md) | — |
| EXPERIMENTAL SEARCH | [ricerca](../research/README.md) | — |
| MULTI-THREAD | [classificazione](classificazione.md), [architettura](architettura.md), [limiti e rischi](limiti-e-rischi.md) | — |
| NUMA | [architettura](architettura.md) | — |
| CPU OPTIMIZATION | [classificazione](classificazione.md), [architettura](architettura.md), [limiti e rischi](limiti-e-rischi.md) | — |
| COMMON LISP / SBCL | [architettura](architettura.md), [limiti e rischi](limiti-e-rischi.md) | [0001](adr/0001-common-lisp-sbcl.md) |
| NATIVE MICROKERNELS | [classificazione](classificazione.md), [limiti e rischi](limiti-e-rischi.md) | [0001](adr/0001-common-lisp-sbcl.md) |
| PERFORMANCE INFRASTRUCTURE | [misure](misure.md) | — |
| PERFORMANCE GATES | [verifica](verifica.md), [misure](misure.md) | — |
| METRICHE PRINCIPALI | [misure](misure.md) | [0006](adr/0006-gerarchia-delle-metriche.md) |
| SELF-PLAY | [misure](misure.md) | — |
| POSITION CORPUS | [verifica](verifica.md), [misure](misure.md) | — |
| TESTING | [verifica](verifica.md) | — |
| CROSS-PLATFORM | [verifica](verifica.md), [limiti e rischi](limiti-e-rischi.md) | — |
| SERVER ARCHITECTURE | [architettura](architettura.md) | — |
| RESEARCH METHODOLOGY | [misure](misure.md), [ricerca](../research/README.md) | — |
| ROADMAP | [roadmap](roadmap.md) | — |
| PHILOSOPHY | [architettura](architettura.md), [roadmap](roadmap.md) | — |

## Convenzioni

**Livelli di autorità.** In caso di conflitto prevale, nell'ordine:

1. la [specifica originale](specifica/specifica-originale.md);
2. gli [ADR](adr/README.md) accettati, che possono emendare la specifica dichiarandolo;
3. gli [invarianti](invarianti.md);
4. i documenti tematici.

Un ADR in stato *Proposta* non vincola.

**Che cosa è specifica e che cosa no.** Nei documenti tematici il testo non marcato riporta ciò
che la specifica prescrive; l'intestazione di ogni documento indica le sezioni da cui viene. Fa
eccezione ciò che descrive lo stato del repository: la sezione di
[architettura](architettura.md#che-cosa-esiste-oggi-e-che-cosa-è-previsto) che lo dichiara, e
altrove frasi che cominciano con «Oggi». Tutto il resto è marcato:

> **Proposta** — interpretazione o scelta di progetto non presente nella specifica. Va
> confermata; finché non lo è, non vincola l'implementazione.

> **Deciso (FONTE → ADR-nnnn)** — decisione registrata nell'ADR indicato. FONTE dice da dove
> viene: `specifica «SEZIONE»` se la prescrive la specifica, `QA-nn` se l'ADR chiude una
> questione aperta, `autore` se è una scelta dell'autore. Il testo che segue descrive la
> questione; la decisione è nell'ADR.

> **Aperto (QA-nn)** — punto non ancora deciso; rimanda alle
> [questioni aperte](limiti-e-rischi.md#questioni-aperte), con l'esperimento o la decisione (ADR)
> che lo chiude.

**Portata di un marcatore.** Un marcatore vale per il proprio blocco e per il contenuto che lo
segue, fino al titolo successivo dello stesso livello o di livello superiore, oppure fino al
marcatore successivo.

Negli [invarianti](invarianti.md) e negli [ADR](adr/README.md) lo stato è sempre esplicito.

**Identificativi.** `INV-…` invarianti, `ADR-…` decisioni, `QA-…` questioni aperte, `RSK-…`
rischi, `EXP-…` esperimenti, `TT-…` ipotesi della transposition table. Gli identificativi sono
stabili: non si rinumerano, si ritirano. Una voce chiusa si marca, non si cancella.

**Lingua.** Documentazione in italiano. I termini tecnici consolidati restano in inglese; l'elenco
è uno solo, nel [glossario](glossario.md#convenzione-linguistica). Codice, docstring e nomi dei
test sono in inglese ([ADR-0009](adr/0009-convenzione-linguistica.md)).

## Come si mantiene

- Un cambio di requisito parte dalla specifica (o da un ADR che la emenda), poi si propaga a
  invarianti e documenti tematici nello stesso commit (INV-X12).
- Una questione aperta si chiude con un ADR; la voce resta, marcata «Risolta da ADR-nnnn».
- I numeri di prestazione entrano nei documenti solo se prodotti da un comando eseguito, con
  l'ambiente registrato ([misure](misure.md)); altrimenti sono target o stime (INV-X2).
- Una nuova sezione citata nell'intestazione di un documento si aggiunge alle due tabelle sopra.
- I link e le ancore si verificano con `make links`.
