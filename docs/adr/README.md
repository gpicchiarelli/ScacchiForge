# Registro delle decisioni architetturali (ADR)

Un ADR registra **una** decisione: contesto, scelta, conseguenze e come se ne valuta la tenuta.
Gli ADR sono la memoria del progetto: spiegano perché è fatto così.

## Regole

- Numerazione progressiva a quattro cifre. Un ADR non si rinumera e non si cancella.
- Stati: **Proposta** → **Accettata** → eventualmente **Sostituita da ADR-nnnn** o **Ritirata**.
  Il campo «Stato» porta uno solo di questi valori; una nota sullo stato va in questo indice.
- Un ADR accettato non si riscrive: per cambiare decisione se ne scrive uno nuovo che lo
  sostituisce.
- Una decisione che non viene dalla [specifica](../specifica/specifica-originale.md) è **Proposta**
  finché l'autore non la conferma. Una che la emenda lo dichiara nel campo «Rapporto con la
  specifica».
- Un ADR accettato contiene solo ciò che è deciso, dalla specifica o dall'autore. Le regole che il
  repository propone per applicarlo stanno in un ADR a parte, in stato **Proposta**, che lo cita.
- Ogni [questione aperta](../limiti-e-rischi.md#questioni-aperte) si chiude con un ADR; la voce
  resta, marcata «Risolta da ADR-nnnn».
- Modello: [0000-modello.md](0000-modello.md).

## Decisioni accettate

Registrano ciò che la specifica già prescrive, o una scelta dell'autore. Le sezioni «Alternative»
e «Valutazione» sono contributi del repository, non della specifica.

| ADR | Decisione | Stato |
|---|---|---|
| [0001](0001-common-lisp-sbcl.md) | Common Lisp/SBCL come linguaggio del nucleo; kernel nativi a cinque condizioni | Accettata (dalla specifica) |
| [0002](0002-implementazione-di-riferimento-come-oracolo.md) | L'implementazione di riferimento come oracolo | Accettata (dalla specifica; regole di applicazione in 0010) |
| [0003](0003-classificazione-delle-riduzioni-di-lavoro.md) | Classificazione delle riduzioni di lavoro in sette etichette | Accettata (dalla specifica; convenzioni in 0011) |
| [0004](0004-nessuna-dipendenza-esterna-e-harness-proprio.md) | Nessuna dipendenza esterna; harness di test proprio (sostituisce il piano iniziale con FiveAM) | Accettata (proposta del repository, confermata dall'autore il 2026-10-04) |
| [0005](0005-chiavi-zobrist-da-prng-deterministico.md) | Chiavi Zobrist da un generatore deterministico, mai `sxhash` | Accettata (proposta del repository, confermata dall'autore il 2026-10-04) |
| [0006](0006-gerarchia-delle-metriche.md) | Gerarchia delle metriche: Elo per CPU-secondo prima dell'NPS | Accettata (dalla specifica) |
| [0007](0007-licenza-bsd-2-clause-e-originalita.md) | Licenza BSD-2-Clause e originalità del codice | Accettata (originalità dalla specifica, licenza scelta dall'autore; interpretazione in 0013) |
| [0008](0008-perft-gate-obbligatorio.md) | Perft come gate obbligatorio | Accettata (dalla specifica; lettura in 0012) |
| [0009](0009-convenzione-linguistica.md) | Documentazione in italiano, codice in inglese | Accettata (proposta del repository, confermata dall'autore il 2026-10-04) |
| [0010](0010-regole-di-indipendenza-tra-i-livelli.md) | Regole di indipendenza tra i livelli (applica 0002) | Accettata (proposta del repository, confermata dall'autore il 2026-10-04) |
| [0011](0011-convenzioni-di-classificazione.md) | Convenzioni di classificazione: regole d'uso, marcatura, tabella delle tecniche (applica 0003) | Accettata (proposta del repository, confermata dall'autore il 2026-10-04). La tabella delle tecniche resta una proposta: una riga vincola quando un ADR la decide |
| [0012](0012-lettura-del-gate-di-perft.md) | Lettura del gate di perft, eccezione per il riferimento, provenienza dei valori attesi (applica 0008) | Accettata (proposta del repository, confermata dall'autore il 2026-10-04) |
| [0013](0013-interpretazione-operativa-dell-originalita.md) | Interpretazione operativa dell'originalità (applica 0007) | Accettata (proposta del repository, confermata dall'autore il 2026-10-04) |
| [0014](0014-policy-di-compilazione-del-livello-ottimizzato.md) | Policy di compilazione del livello ottimizzato: `speed 3`, `safety 1`, build controllata a `safety 3` | Accettata (proposta del repository, confermata dall'autore il 2026-10-04). Il testo rimanda a QA-17 per l'espansione delle funzioni di nodo (punto 6); QA-17 è risolta da 0017, e per il punto 6 le condizioni di 0017 non sono ancora soddisfatte (0017, Applicazione). Il punto 1 elenca i file del hot path della Fase 1; dalla Fase 2 `*hot-path-files*` comprende anche `evaluation` e `search` ([0019](0019-valutazione-e-ricerca-del-livello-ottimizzato.md), accettato il 2026-10-07), con la stessa policy, la build controllata e la scansione di `make hot-path`; le note di efficienza di quei file sono spiegate in 0019 (Conseguenze). Dalla Fase 3 comprende anche `transposition` e `ordering` ([0021](0021-transposition-table-del-livello-ottimizzato.md) e [0023](0023-ordinamento-delle-mosse-della-fase-3.md), in stato Proposta) |
| [0015](0015-generatore-di-mosse-del-livello-ottimizzato.md) | Generatore di mosse del livello ottimizzato: bitboard, filtro di legalità per maschere, buffer impilati | Accettata (proposta del repository, confermata dall'autore il 2026-10-04). Il testo rimanda a QA-17 per il filtro per maschere; QA-17 è risolta da 0017, e per il filtro le condizioni di misura di 0017 non sono ancora soddisfatte (0017, Applicazione) |
| [0016](0016-attacchi-dei-pezzi-a-lunga-gittata.md) | Attacchi dei pezzi a lunga gittata: magic bitboard con numeri cercati dal progetto da un seme, scelta dell'implementazione con `SCF_SLIDERS`, default `fixed-magic` dalla misura | Accettata (proposta del repository, confermata dall'autore il 2026-10-04). Il testo descrive [EXP-0001](../../research/exp-0001-attacchi-dei-pezzi-a-lunga-gittata.md) In corso e lo scostamento di [QA-17](../limiti-e-rischi.md#qa-17); dal 2026-10-04 QA-17 è risolta da 0017 e EXP-0001 è chiuso, Accettato: il default resta `fixed-magic` |
| [0017](0017-percorso-di-ricerca-per-le-alternative-exact.md) | Percorso di ricerca per le alternative `EXACT` con le stesse uscite: equivalenza, microbenchmark e `make bench` con il registro dell'ambiente e una regola di decisione, su una revisione committata e pulita; self-play e validazione statistica non si applicano. Chiude [QA-17](../limiti-e-rischi.md#qa-17) | Accettata (decisione dell'autore del 2026-10-04). Il testo dice che `make bench` non ha righe di una ricerca: oggi ha le righe della ricerca e della valutazione del livello ottimizzato ([misure](../misure.md#due-livelli-di-benchmark), [ADR-0019](0019-valutazione-e-ricerca-del-livello-ottimizzato.md)). Un terzo caso, venuto dopo, è lo stato incrementale della valutazione (0018 punto 6, 0019 punto 2, accettati il 2026-10-07): ne soddisfa le condizioni dal 2026-10-08 ([EXP-0002](../../research/exp-0002-stato-incrementale-della-valutazione.md), Accettato) |
| [0018](0018-definizione-della-valutazione-classica.md) | Definizione della valutazione classica della Fase 2 in [valutazione](../valutazione.md): nove termini interi in centipawn, fase dal materiale non di pedone (al più 62), miscela troncata verso zero, punteggio dal Bianco restituito da chi muove, simmetria dei colori per costruzione, materiale e piece-square tables incrementali nel livello ottimizzato, pesi con regole dichiarate, non tarati dal repository. Le coincidenze con engine pubblicati sono elencate in [valutazione](../valutazione.md#provenienza); i pesi della struttura pedonale sono fissati da una regola, per decisione dell'autore su [QA-18](../limiti-e-rischi.md#qa-18) | Accettata (proposta del repository, accettata dall'autore il 2026-10-07, dopo la risoluzione di QA-18) |
| [0019](0019-valutazione-e-ricerca-del-livello-ottimizzato.md) | Valutazione e ricerca del livello ottimizzato: copia propria dei parametri, stato incrementale riletto dallo stack di undo, negamax, alpha-beta e iterative deepening con un contesto preallocato e una tavola triangolare delle varianti; con il riferimento si confrontano il valore e i nodi di negamax, non la mossa migliore né i nodi di alpha-beta; la firma di ricerca in `tests/search-signature.sexp`, scritta solo da `make signatures`. Dichiara due scostamenti da invarianti Decisi: INV-X7 per i parametri ([QA-19](../limiti-e-rischi.md#qa-19), chiusa da 0020) e INV-X3 per lo stato incrementale ([EXP-0002](../../research/exp-0002-stato-incrementale-della-valutazione.md)) | Accettata (proposta del repository, accettata dall'autore il 2026-10-07). La variante senza lo stato incrementale che il testo dice mancante esiste dal 2026-10-08 (`SCF_EVAL_STATE=recompute`, [EXP-0002](../../research/exp-0002-stato-incrementale-della-valutazione.md)); con la misura confermativa sul commit dd5a2a5 il record è chiuso, Accettato, e lo scostamento da INV-X3 che il testo registra per lo stato incrementale è chiuso |
| [0020](0020-parametri-della-valutazione-dalla-fase-10.md) | INV-X7 si applica ai parametri della valutazione dalla [Fase 10](../roadmap.md#fase-10): fino ad allora restano costanti nel codice dei due livelli, e la forma con cui diventano dati si decide nel gate di quella fase. Chiude [QA-19](../limiti-e-rischi.md#qa-19) | Accettata (decisione dell'autore del 2026-10-04) |

## Proposte

Proposte del repository per la [Fase 3](../roadmap.md#fase-3), scritte il 2026-10-08 con il codice
che descrivono. Non vincolano finché l'autore non le accetta. Le tre tecniche cambiano i nodi di
una ricerca, e il loro percorso di ricerca è
[EXP-0003](../../research/exp-0003-ricerca-della-fase-3.md), Proposto.

| ADR | Decisione | Stato |
|---|---|---|
| [0021](0021-transposition-table-del-livello-ottimizzato.md) | Transposition table del livello ottimizzato: entry compatte di 16 byte in array tipizzati, chiave intera confrontata, dimensione, politica (`:always`, `:depth-preferred`, `:two-slot`) e modalità come argomenti; modalità di verifica che soddisfa TT-1…TT-4, con un controllo indipendente della posizione in ogni slot e i falsi riscontri scartati e contati; mossa TT usata solo se legale; default proposti per [QA-01](../limiti-e-rischi.md#qa-01) e [QA-02](../limiti-e-rischi.md#qa-02), che restano aperte | Proposta |
| [0022](0022-pvs-negascout-e-tipi-di-nodo.md) | PVS e NegaScout come schemi di finestra di un nodo della Fase 3, accanto alle baseline invariate; NegaScout con la ri-ricerca da `s − 1` e senza ri-ricerca dei risultati già esatti; tipi di nodo PV, Cut e All attesi e osservati, contati; ricerca di default della Fase 3 (iterative deepening di PVS con ordinamento e TT); firma di ricerca in formato 2, con alpha-beta e la ricerca di default con la TT in modalità di verifica | Proposta |
| [0023](0023-ordinamento-delle-mosse-della-fase-3.md) | Ordinamento delle mosse della Fase 3: mossa TT, mossa PV, catture MVV/LVA per tipo, promozioni, le altre; ordinamento stabile per inserimento senza allocazione; nessun killer, history né SEE (Fase 4) | Proposta |

Fino al 2026-10-04 erano in stato Proposta anche 0004, 0005, 0009 e da 0010 a 0016, che l'autore ha
accettato in quella data; 0018 e 0019, proposti il 2026-10-04, li ha accettati il 2026-10-07, dopo
la risoluzione di [QA-18](../limiti-e-rischi.md#qa-18), come aveva deciso.
