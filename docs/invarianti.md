# Invarianti

Regole che nessuna implementazione, ottimizzazione o decisione successiva può violare senza un
cambio esplicito di specifica (ADR). Derivano dalle sezioni della
[specifica](specifica/specifica-originale.md); dove la formulazione è del repository e non della
specifica, e nessun ADR accettato la decide, la colonna *Stato* dice «Proposta».

Ogni invariante ha un identificativo stabile: non si rinumera, si ritira.

**Stato.** *Deciso*: la specifica lo prescrive (la sezione è citata) o lo chiude un ADR
accettato. *Proposta*: formulazione o conseguenza scritta in questo repository; non vincola
finché un ADR non la decide.

**Verifica.** Indica il metodo di controllo ([verifica](verifica.md)). Che il controllo esista
già lo dice `make check` sulla revisione in esame, non questo documento.

## Correttezza

| ID | Invariante | Fonte | Stato | Verifica |
|---|---|---|---|---|
| INV-C1 | `optimized(posizione) == reference(posizione)` per ogni funzione che il riferimento giudica: mosse legali, make/unmake, transizioni di stato, stato Zobrist, valutazione, aggiornamenti delle feature NNUE, risultati di ricerca dove applicabile. Il significato di «uguale» è in [architettura](architettura.md#che-cosa-significa-uguale). | «REFERENCE ENGINE» | Deciso | test differenziale, fuzzer |
| INV-C2 | `unmake(make(p, m)) == p` per ogni mossa legale `m`, su tutti i campi dello stato, compreso lo stato incrementale. | «REFERENCE ENGINE», «BOARD REPRESENTATION» | Proposta | fuzzer |
| INV-C3 | Ogni dato incrementale (chiave Zobrist, materiale, pawn state, accumulatore NNUE, altri) è uguale al valore ricalcolato da zero sulla stessa posizione, dopo ogni make e ogni unmake. | «DEDUPLICATION», «REFERENCE ENGINE» | Proposta | fuzzer, controllo in modalità di verifica |
| INV-C4 | Tutte le posizioni di perft passano, per il riferimento e per l'ottimizzato: arrocco, en passant, promozioni, inchiodature, scacchi, scacchi scoperti e casi limite. Il riferimento si giudica dall'esterno solo sui valori pubblicati, con la fonte citata; gli altri valori attesi sono di regressione e non sono un oracolo esterno ([ADR-0012](adr/0012-lettura-del-gate-di-perft.md)). | «PERFT», [ADR-0012](adr/0012-lettura-del-gate-di-perft.md) | Deciso (sezione; valori pubblicati e di regressione: ADR-0012) | perft, `divide` per la diagnosi |
| INV-C5 | La collisione o la perdita di una entry della TT non compromette la correttezza. Sotto TT-1, TT-2 e TT-4 ([classificazione](classificazione.md#ipotesi-della-transposition-table)) la perdita costa solo lavoro: un valore esatto non cambia, un bound resta un bound corretto. Con la storia nel valore ([QA-02](limiti-e-rischi.md#qa-02)) può cambiarlo. Per la collisione la lettura operativa è aperta: [QA-01](limiti-e-rischi.md#qa-01). | «TRANSPOSITION TABLE» | Deciso (testo); lettura operativa aperta | ricerca con e senza TT in [modalità di verifica](verifica.md#modalità-di-verifica-della-tt), conteggio dei falsi riscontri |
| INV-C6 | Una mossa non viene eseguita se non è legale nella posizione corrente, qualunque sia la sua origine: TT, killer, countermove, history, input esterno. | conseguenza di INV-C5 | Proposta | prova con entry alterate e collisioni forzate |
| INV-C7 | La valutazione è simmetrica per scambio dei colori: per ogni posizione `p`, `E_W(m(p)) = −E_W(p)` e quindi `E(m(p)) = E(p)`, dove `m` riflette la scacchiera in verticale, scambia i colori dei pezzi, il lato al tratto e i diritti di arrocco e riflette la casa en passant; `E_W` è il punteggio dal punto di vista del Bianco, `E` quello di chi muove ([valutazione](valutazione.md#simmetria-dei-colori)). | «EVALUATION», gate della [Fase 2](roadmap.md#fase-2), [ADR-0018](adr/0018-definizione-della-valutazione-classica.md) | Deciso (ADR-0018) | test su tabelle di perft, casi speciali e fuzzer, in entrambi i livelli, anche per termine |
| INV-C8 | Lo stato incrementale della valutazione nel livello ottimizzato (somma di materiale e piece-square tables in mediogioco e in finale, fase prima del tetto) è uguale a quello calcolato da zero sulla stessa posizione, dopo ogni make e ogni unmake. È un caso di INV-C3 ([valutazione](valutazione.md#stato-incrementale)). | «EVALUATION», «DEDUPLICATION», [ADR-0018](adr/0018-definizione-della-valutazione-classica.md) | Deciso (ADR-0018) | test differenziale, controllo di coerenza della posizione |
| INV-C9 | Per ogni posizione il valore assoluto di `E_W` è al più 20000, sotto la soglia dei punteggi di matto (`+mate-bound+` = 29000): nessuna valutazione statica è letta come matto ([valutazione](valutazione.md#limite-del-punteggio)). | [ADR-0018](adr/0018-definizione-della-valutazione-classica.md) | Deciso (ADR-0018) | limite nella definizione; test sul fuzzer |
| INV-C10 | La valutazione è funzione della sola disposizione dei pezzi e del lato al tratto: non dipende da orologi, diritti di arrocco, casa en passant né dalla storia della partita ([valutazione](valutazione.md#convenzioni-per-la-ricerca)). | [ADR-0018](adr/0018-definizione-della-valutazione-classica.md) | Deciso (ADR-0018) | test su posizioni che differiscono solo in quei campi |

## Hardware e piattaforme

| ID | Invariante | Fonte | Stato | Verifica |
|---|---|---|---|---|
| INV-H1 | Esiste sempre un fallback generico. | «CPU OPTIMIZATION» | Deciso | revisione, esecuzione senza backend |
| INV-H2 | Ogni kernel nativo ha un fallback portabile e un test di equivalenza. | «NATIVE MICROKERNELS» | Deciso | test di equivalenza |
| INV-H3 | Ogni backend SIMD è bit-identico al riferimento scalare sugli ingressi interi, saturazioni comprese. | «CPU OPTIMIZATION», «NNUE» | Proposta | test di equivalenza su ingressi casuali e su posizioni del fuzzer |
| INV-H4 | Il dispatch CPU è isolato dal resto dell'engine. | «CPU OPTIMIZATION» | Deciso | revisione |
| INV-H5 | Il comportamento logico è identico su tutte le piattaforme target; le differenze hardware riguardano solo i backend ottimizzati. | «CROSS-PLATFORM» | Deciso | regressione cross-platform (perft, firma di ricerca, chiavi), dove l'esecuzione è possibile: [QA-12](limiti-e-rischi.md#qa-12) |

## Architettura

| ID | Invariante | Fonte | Stato | Verifica |
|---|---|---|---|---|
| INV-A1 | Il livello di riferimento non ha dipendenze esterne: usa solo SBCL e ASDF. | [ADR-0010](adr/0010-regole-di-indipendenza-tra-i-livelli.md), [ADR-0004](adr/0004-nessuna-dipendenza-esterna-e-harness-proprio.md) | Deciso | revisione dei sistemi ASDF |
| INV-A2 | Il riferimento non dipende dal livello ottimizzato. L'ottimizzato può dipendere dal riferimento solo per convertire le posizioni. | [ADR-0010](adr/0010-regole-di-indipendenza-tra-i-livelli.md) | Deciso | ordine di caricamento; test `optimized-level-names-only-the-reference-position-interface` (`tests/test-bitboard.lisp`); revisione |
| INV-A3 | Il modulo condiviso `core` contiene solo definizioni (costanti, codifica della mossa, tavole di chiavi, generatore pseudocasuale), nessun algoritmo che il confronto differenziale debba giudicare. | [ADR-0010](adr/0010-regole-di-indipendenza-tra-i-livelli.md) | Deciso | revisione |
| INV-A4 | L'ottimizzazione non rende mai impossibile la verifica della correttezza: ogni componente ottimizzato conserva un percorso di confronto con il riferimento. | «REFERENCE ENGINE» | Deciso | revisione, test differenziale |
| INV-A5 | Nel hot path di ricerca l'allocazione è quasi nulla: stack e buffer di mosse preallocati, `Move` come valore packed, nessuna chiusura allocata. | «COMMON LISP / SBCL», «MOVE REPRESENTATION» | Deciso | misura dei byte allocati per ricerca, disassembly dove lo si afferma |
| INV-A6 | Si evitano lock globali nel percorso critico; stato di ricerca e stack sono locali al thread. | «MULTI-THREAD» | Deciso | revisione, misure di scalabilità |
| INV-A7 | Il server è separato logicamente dall'engine; il Game Actor non si blocca durante la ricerca del bot. | «SERVER ARCHITECTURE» | Deciso | revisione |
| INV-A8 | Il nucleo dell'engine resta Common Lisp; codice nativo solo alle cinque condizioni di [ADR-0001](adr/0001-common-lisp-sbcl.md). | «NATIVE MICROKERNELS» | Deciso | revisione |

## Metodo

| ID | Invariante | Fonte | Stato | Verifica |
|---|---|---|---|---|
| INV-X1 | Ogni riduzione del lavoro computazionale porta almeno una etichetta di [classificazione](classificazione.md). | «PRINCIPIO FONDAMENTALE» | Deciso | revisione |
| INV-X2 | Nessuna cifra di prestazione compare nel repository se non è prodotta da un comando nel repository, eseguito, con l'ambiente registrato. Altrimenti è dichiarata target o stima. | «RESEARCH METHODOLOGY», «PERFORMANCE GATES» | Proposta (formulazione) | revisione |
| INV-X3 | Una tecnica si accetta solo dopo ipotesi, razionale matematico, implementazione, microbenchmark, benchmark di engine, self-play e validazione statistica; mai perché «sembra più veloce». Per un'alternativa `[EXACT]` le cui uscite sono identiche a quelle dell'implementazione esistente o del riferimento, provate da un'equivalenza esaustiva o differenziale e dal perft, il percorso è soddisfatto dall'equivalenza, dal microbenchmark e da `make bench` con il registro dell'ambiente e una regola di decisione, eseguito su una revisione committata e pulita; self-play e validazione statistica non si applicano. Non vale per ciò che cambia un'uscita (valore, mossa scelta, nodi di una ricerca) ([ADR-0017](adr/0017-percorso-di-ricerca-per-le-alternative-exact.md)). | «RESEARCH METHODOLOGY», [ADR-0017](adr/0017-percorso-di-ricerca-per-le-alternative-exact.md) | Deciso | record di ricerca; per le alternative di ADR-0017, il test di equivalenza in `make check` o in un target profondo documentato e l'output di `make bench` |
| INV-X4 | Un miglioramento non si dichiara sulla base di una sola partita o di un solo benchmark. | «SELF-PLAY», «PHILOSOPHY» | Deciso | revisione, [misure](misure.md) |
| INV-X5 | Ogni esperimento è riproducibile, configurabile, confrontabile con la baseline, misurabile e reversibile. | «EXPERIMENTAL SEARCH» | Deciso | record di ricerca |
| INV-X6 | Ogni sorgente di casualità è deterministica e dichiara il seme: la stessa sequenza su ogni piattaforma e in ogni esecuzione. | «SELF-PLAY», [ADR-0005](adr/0005-chiavi-zobrist-da-prng-deterministico.md) | Deciso | test con valori attesi fissati |
| INV-X7 | Ogni parametro importante si modifica senza cambiare il codice. | «PARAMETER OPTIMIZATION» | Deciso | revisione. Per i parametri della valutazione classica si applica dalla Fase 10: fino ad allora sono costanti nel codice ([ADR-0020](adr/0020-parametri-della-valutazione-dalla-fase-10.md), che chiude [QA-19](limiti-e-rischi.md#qa-19)) |
| INV-X8 | Nessuna ricerca aggressiva entra prima che il gate di perft passi. | «PERFT» | Deciso | [roadmap](roadmap.md) |
| INV-X9 | Il codice è originale: nessun codice di Stockfish o derivato, nessuna implementazione proprietaria di altri engine. | introduzione della specifica, [ADR-0007](adr/0007-licenza-bsd-2-clause-e-originalita.md) | Deciso | revisione |
| INV-X10 | Una modifica si valuta almeno su correttezza, velocità, memoria, allocazione e forza; regressioni e miglioramenti si registrano. | «PERFORMANCE GATES» | Deciso | [verifica](verifica.md#gate-di-modifica) |
| INV-X11 | Nessuna decisione si prende sul solo NPS: vale la [gerarchia delle metriche](misure.md#gerarchia-delle-metriche). | «METRICHE PRINCIPALI», [ADR-0006](adr/0006-gerarchia-delle-metriche.md) | Deciso | revisione |
| INV-X12 | La documentazione si aggiorna nello stesso commit della modifica che la rende falsa. | convenzione di ArcDocDB | Proposta | revisione |

## Corrispondenza con la specifica

Non ogni frase della specifica è un invariante. Sono invarianti i vincoli verificabili. Sono
indirizzi di progetto, descritti in [architettura](architettura.md), [misure](misure.md) e
[roadmap](roadmap.md), l'elenco di tecniche da implementare, le ottimizzazioni da provare, la
struttura del server e il tipo di strumenti di tuning.
