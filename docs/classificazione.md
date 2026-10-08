# Classificazione del lavoro

> **Fonte:** «PRINCIPIO FONDAMENTALE», «SEARCH REDUCTIONS AND PRUNING» e «TRANSPOSITION TABLE»
> della [specifica](specifica/specifica-originale.md). La tabella delle tecniche prende i nomi
> anche da «SEARCH FOUNDATION», «LMR», «NULL MOVE», «QUIESCENCE», «MOVE ORDERING»,
> «DEDUPLICATION», «EVALUATION», «NNUE», «MOVE GENERATION», «CPU OPTIMIZATION», «NATIVE
> MICROKERNELS», «MULTI-THREAD» e «PARAMETER OPTIMIZATION». Decisioni:
> [ADR-0003](adr/0003-classificazione-delle-riduzioni-di-lavoro.md),
> [ADR-0011](adr/0011-convenzioni-di-classificazione.md).

## Principio

Ogni riduzione del lavoro computazionale porta almeno una etichetta. Le etichette sono sette,
sono nella specifica e dicono che cosa si può affermare di una tecnica, non quanto funziona bene.

> **Deciso (specifica «PRINCIPIO FONDAMENTALE» →
> [ADR-0003](adr/0003-classificazione-delle-riduzioni-di-lavoro.md))** — Il principio e le sette
> etichette sono della specifica.

La specifica dice di non confondere mai un'euristica efficace con un teorema, e di marcare come
`HEURISTIC` ogni tecnica che non è matematicamente garantita. Tutto il resto di questo documento
serve a non farlo.

> **Deciso (autore → [ADR-0011](adr/0011-convenzioni-di-classificazione.md))** — Le regole
> d'uso, le convenzioni di marcatura, le ipotesi della transposition table e la tabella delle
> tecniche vengono da questo repository; l'autore le ha accettate il 2026-10-04. Le sette
> etichette e le loro definizioni no: sono della specifica. La tabella delle tecniche resta una
> proposta: una riga diventa vincolante solo quando un ADR la decide.

## Le sette etichette

Le definizioni sono quelle della specifica. La colonna «Che cosa serve» è una proposta.

| Etichetta | Definizione (specifica) | Che cosa serve per usarla |
|---|---|---|
| `[THEOREM]` | Correttezza dimostrabile. | Una dimostrazione o un riferimento a una dimostrazione, con le ipotesi scritte. |
| `[EXACT]` | Algoritmo esatto senza perdita di correttezza. | Un'argomentazione di equivalenza con il riferimento; un test esaustivo dove il dominio è finito, altrimenti un test differenziale come evidenza per campioni. |
| `[BOUNDED]` | Produce bound matematicamente interpretabili. | L'enunciato del bound: che cosa limita, da che parte, sotto quali ipotesi. |
| `[PROBABILISTIC]` | Correttezza pratica basata su proprietà probabilistiche esplicite. | Il modello: quale evento, con quale probabilità, sotto quali ipotesi di indipendenza. |
| `[HEURISTIC]` | Euristica senza garanzia generale. | Niente, ma va detto quale errore è possibile. È l'etichetta di partenza. |
| `[EMPIRICAL]` | Validata sperimentalmente. | Un [record di ricerca](../research/README.md) con ipotesi, misura, statistica ed esito. |
| `[LEARNED]` | Parametri o funzioni ottenuti tramite training. | Identità dei dati, procedura, seme, versione del risultato. |

## Regole d'uso

> **Deciso (autore → [ADR-0011](adr/0011-convenzioni-di-classificazione.md))** — Valgono per
> ogni modifica.

1. **Più etichette sono ammesse.** La specifica dice «almeno una». Una potatura è `[HEURISTIC]`;
   se il suo effetto è stato misurato è anche `[EMPIRICAL]`. I pesi di una rete sono `[LEARNED]`;
   la forza della rete è `[EMPIRICAL]`.
2. **`[EMPIRICAL]` e `[LEARNED]` non sostituiscono una garanzia.** Dicono da dove viene
   l'evidenza o il parametro. Una tecnica `[HEURISTIC]` validata resta `[HEURISTIC]`: può ancora
   sbagliare, e l'evidenza dice solo che nelle condizioni misurate conviene.
3. **Ordine di garanzia**, dalla più forte alla più debole: `THEOREM`, `EXACT`, `BOUNDED`,
   `PROBABILISTIC`, `HEURISTIC`.
4. **Nel dubbio, la più debole.** Un'etichetta troppo forte è l'errore che la specifica vieta;
   una troppo debole costa soltanto una correzione.
5. **Una combinazione ha la garanzia del suo componente più debole.** Alpha-beta con
   transposition table e riduzioni sul numero di mossa non è `THEOREM`.
6. **Si promuove con evidenza, si retrocede senza.** Passare a `THEOREM` richiede una
   dimostrazione. Passare a `EXACT` richiede un'argomentazione di equivalenza e un test:
   esaustivo dove il dominio è finito, altrimenti differenziale, che è evidenza per campioni
   ([verifica](verifica.md)). Retrocedere è sempre ammesso.
7. **Che cosa si classifica.** Ciò che cambia che cosa si calcola o riusa un risultato:
   potature, riduzioni, estensioni, cache, aggiornamenti incrementali, tabelle precalcolate,
   scelta di un backend. Un'ottimizzazione che calcola lo stesso valore con meno istruzioni (tipi
   dichiarati, inlining) è `EXACT` se le dichiarazioni sono vere: con `safety` bassa una
   dichiarazione falsa cambia il comportamento. Lo mostra lo stesso test della regola 6. Si
   dichiara in una riga.
8. **Algoritmo e implementazione si classificano a parte.** Un algoritmo può essere `THEOREM`
   (per esempio alpha-beta a finestra piena). Un'implementazione dice nel docstring su quale base
   e con quale evidenza ne eredita la garanzia.

## Come si marca

> **Deciso (autore → [ADR-0011](adr/0011-convenzioni-di-classificazione.md))**

**Codice.** Nel docstring, dopo la riga di sintesi, tre campi. Il testo del codice è in inglese.

```lisp
(defun null-move-applicable-p (position depth beta)
  "Decide whether the null-move test is tried at this node.

Classification: [HEURISTIC]
Basis: assumes that passing never helps the side to move; false in zugzwang.
Evidence: none yet."
  ...)
```

`Evidence:` indica il test o il record di ricerca (`EXP-nnnn`) che sostiene l'etichetta, oppure
`none yet`. Una funzione che non riduce lavoro non porta il campo.

**Documenti.** Una colonna «Classe» nelle tabelle, oppure l'etichetta tra apici inversi nel
testo. Le ipotesi della classificazione stanno accanto, non altrove.

**Commit.** Una riga finale `Classification: [TAG]`, oppure `Classification: none` se la
modifica non riduce lavoro. Il corpo del messaggio dice quale test sostiene l'etichetta.

**Pull request.** Lo stesso campo, nella descrizione. Una PR che promuove un'etichetta lo dice
nel titolo.

**Esperimenti.** Il [modello](../research/TEMPLATE.md) ha un campo per l'etichetta proposta e uno
per quella finale.

## Ipotesi della transposition table

> **Deciso (autore → [ADR-0011](adr/0011-convenzioni-di-classificazione.md))** — Le ipotesi
> TT-1…TT-4 sono del repository; la specifica dice solo «game tree → game graph». Più righe della
> tabella dipendono dalle stesse ipotesi: si nominano una volta.

| Ipotesi | Enunciato |
|---|---|
| TT-1 | Si usano solo entry con profondità uguale a quella richiesta. |
| TT-2 | Il valore di una posizione non dipende dal percorso che la raggiunge: nessuna ripetizione né regola delle cinquanta mosse nel valore (problema detto *graph history interaction*, GHI). Gli orologi stanno fuori dalla chiave Zobrist. |
| TT-3 | Nessuna collisione di chiave. |
| TT-4 | Il valore cercato dipende solo da (posizione, profondità, finestra): non dallo stato di ricerca, come tabelle di history, killer, la distanza dalla radice nei punteggi di matto, o l'avere appena fatto un null move. |

> **Aperto (QA-02)** — Come trattare le ripetizioni dentro la ricerca con la TT. La specifica
> dice «game tree → game graph» ma non dice come si gestisce la storia. Vedi
> [QA-02](limiti-e-rischi.md#qa-02).

> **Aperto (QA-01)** — La specifica vuole che «la collisione o perdita di una entry» non
> comprometta mai la correttezza. La perdita non cambia il valore sotto TT-1, TT-2 e TT-4. Una
> collisione sì, e con chiavi a 64 bit non si può escludere. Vedi
> [QA-01](limiti-e-rischi.md#qa-01).

## Tabella delle tecniche

> **Proposta** — Classificazione proposta per ogni tecnica nominata dalla specifica. Una riga è
> decisa solo quando un ADR accettato la decide, e allora la colonna «Classe» nomina l'ADR. Oggi
> sono decise le righe la cui classe sta nella sezione «Classificazione» di un ADR accettato: le
> due di Zobrist ([ADR-0005](adr/0005-chiavi-zobrist-da-prng-deterministico.md)); generazione
> legale e make/unmake del livello ottimizzato, le sue tavole precalcolate e il filtro di
> legalità per maschere ([ADR-0015](adr/0015-generatore-di-mosse-del-livello-ottimizzato.md));
> le magic bitboard del livello ottimizzato
> ([ADR-0016](adr/0016-attacchi-dei-pezzi-a-lunga-gittata.md)); i microkernel nativi
> ([ADR-0001](adr/0001-common-lisp-sbcl.md)). Le altre non sono decise. Dove la classe dipende
> da ipotesi, le ipotesi sono scritte. Una classe marcata «provvisoria» aspetta la chiusura della
> questione aperta indicata.

### Ricerca di base

| Tecnica | Classe | Motivo e ipotesi |
|---|---|---|
| Minimax, negamax | `THEOREM` per l'algoritmo | Negamax coincide con minimax se la valutazione è data dal punto di vista di chi muove. A profondità fissa il valore è il minimax dell'albero troncato con la valutazione alle foglie: approssima V(s), non è il valore teorico della partita. Sono la baseline: non riducono lavoro. |
| Alpha-beta | `THEOREM` per l'algoritmo a finestra piena (−∞, +∞); `BOUNDED` con una finestra (α, β) | Restituisce il valore minimax (Knuth e Moore, 1975). Con finestra (α, β) un risultato strettamente interno è esatto; uno sul bordo o fuori è un bound. Un'implementazione eredita la classe solo con un test contro negamax (regola 8). |
| Iterative deepening | `EXACT` | Senza TT né potature il valore dell'iterazione a profondità d non dipende dall'ordine delle mosse, quindi coincide con la ricerca diretta a profondità d. Con la TT valgono TT-1…TT-4. Quando fermarsi (tempo) è `HEURISTIC`. |
| Ricerca a finestra nulla | `BOUNDED` | Un singolo risultato dice solo se il valore sta sopra o sotto la soglia. È `EXACT` solo dentro uno schema con ri-ricerca. |
| PVS, NegaScout | `EXACT` | Quando la ricerca a finestra nulla restituisce α < v < β si ricerca con la finestra (α, β) del nodo; così si ottiene il valore di alpha-beta. Richiede punteggi interi; per il resto valgono le ipotesi di alpha-beta. |
| Finestre di aspirazione | `EXACT` con ri-ricerca | Se il risultato è ≤ α o ≥ β, cioè fuori dalla finestra o sul suo bordo, si ricerca con una finestra più larga; il valore finale è quello della ricerca a finestra piena (−∞, +∞). La larghezza è solo una questione di efficienza. |
| MTD(f) | `EXACT` sotto TT-1…TT-4 | Sequenza di ricerche a finestra nulla che converge al valore minimax (Plaat e altri, 1996). Usa la TT per rimemorizzare i bound: eredita le sue ipotesi. |
| SSS*, DUAL* | `THEOREM` per l'algoritmo originale; `EXACT` per l'implementazione sotto TT-1…TT-4 | La letteratura (Plaat e altri, 1996) li riformula come sequenze di ricerche a finestra nulla con TT. |
| Transposition-driven search | `HEURISTIC` (provvisoria) | Aperto (QA-13): la specifica non definisce l'algoritmo. In letteratura il nome indica uno schema di ricerca distribuita guidato dalla TT (Romein e altri, 2002): è la lettura candidata. [QA-13](limiti-e-rischi.md#qa-13) |

### Transposition table e hashing

| Tecnica | Classe | Motivo e ipotesi |
|---|---|---|
| Zobrist: aggiornamento incrementale | `EXACT` (decisa: [ADR-0005](adr/0005-chiavi-zobrist-da-prng-deterministico.md)) | La chiave aggiornata deve essere uguale a quella ricalcolata (INV-C3). |
| Zobrist: identificare una posizione dalla chiave | `PROBABILISTIC` (decisa: [ADR-0005](adr/0005-chiavi-zobrist-da-prng-deterministico.md)) | Per due posizioni che differiscono in almeno una caratteristica della chiave (pezzi, lato al tratto, diritti di arrocco, casa en passant disponibile secondo la politica della chiave), con chiavi indipendenti e uniformi su 64 bit, la probabilità che le chiavi coincidano è 2^-64. Le chiavi vengono da un generatore deterministico, quindi l'indipendenza è un modello. Due posizioni che differiscono solo negli orologi hanno la stessa chiave: è parte di TT-2. |
| TT con bound `EXACT`, `LOWERBOUND`, `UPPERBOUND` | `BOUNDED`; `EXACT` sotto TT-1…TT-4 | La entry è un bound sul valore a quella profondità. Riusare entry più profonde o ignorare la storia esce da queste ipotesi. |
| TT con riuso di entry più profonde | `HEURISTIC` sul valore a profondità fissa | Il valore restituito è quello di una ricerca più profonda, e dipende dal contenuto della tabella. È l'uso normale; la forza è `EMPIRICAL`. |
| Politiche di sostituzione | `EXACT` sotto TT-1…TT-4; efficacia `EMPIRICAL` | Sotto queste ipotesi perdere una entry costa lavoro, non correttezza. Con la storia nel valore o con il riuso di entry più profonde, tenere o perdere una entry cambia anche il valore. |
| Chiave parziale nella entry (compressione) | `PROBABILISTIC` | Meno bit confrontati, più falsi riscontri. Il rischio si calcola dal numero di bit confrontati. |

### Ordinamento delle mosse

| Tecnica | Classe | Motivo e ipotesi |
|---|---|---|
| Mossa TT, mossa PV, killer, history, countermove, continuation history, ordinamento per SEE | `EXACT` sul valore di alpha-beta puro; efficacia `EMPIRICAL` | L'ordine non cambia il valore di alpha-beta senza potature. Cambia il valore se una riduzione o una potatura dipende dall'indice di mossa (LMR): da lì l'ordine fa parte del modello e la classe è quella della riduzione. |

La mossa presa da una tabella (TT, killer, countermove) va controllata come legale nella posizione
corrente prima dell'uso (INV-C6).

### Potature, riduzioni, estensioni

| Tecnica | Classe | Motivo e ipotesi |
|---|---|---|
| Null move (base) | `HEURISTIC` | Assume che passare non giovi a chi muove. Falso in zugzwang. |
| Null move con verification search, rilevamento di zugzwang, riduzione adattiva | `HEURISTIC` | Riducono il rischio, non lo eliminano. |
| Futility, reverse futility, razoring | `HEURISTIC` | Si basano su margini sulla valutazione statica. Un margine è un bound solo se si dimostra che limita la variazione della valutazione, e in generale non vale. |
| Late move reductions | `HEURISTIC`; parametri `EMPIRICAL` | La specifica chiede R = f(depth, indice di mossa, tipo di nodo, history, TT, volatilità tattica, valutazione, ricerche precedenti). Se f è appresa, è anche `LEARNED`. |
| ProbCut | `HEURISTIC`; parametri della regressione `LEARNED`; soglie ed efficacia `EMPIRICAL`; `PROBABILISTIC` solo per il tasso d'errore sotto il modello dichiarato | Modello statistico: una ricerca poco profonda predice quella profonda con una dispersione stimata su dati (Buro, 1995). La soglia viene dalla dispersione. Il tasso d'errore vale sotto il modello di regressione stimato; non è una proprietà della posizione, e gli errori reali non sono indipendenti né gaussiani nelle code. La specifica elenca ProbCut in «SEARCH REDUCTIONS AND PRUNING», dove ogni tecnica non garantita matematicamente è `HEURISTIC`. |
| Singular extensions | `HEURISTIC` | Estende se la mossa TT è molto migliore delle alternative in una ricerca ridotta con la mossa esclusa. È un test di ricerca, non una garanzia. |
| Check extensions | `HEURISTIC` | Cambiano la funzione cercata. |

### Quiescenza

| Tecnica | Classe | Motivo e ipotesi |
|---|---|---|
| Quiescence search | `HEURISTIC` | Definisce il valore della foglia. L'ipotesi di stand-pat (chi muove può fare almeno quanto la valutazione statica) non è un teorema. |
| SEE | `HEURISTIC` come stima; `EXACT` l'algoritmo rispetto al proprio modello | Calcola l'esito dello scambio su una casa in un modello semplificato: ogni parte cattura con il pezzo meno prezioso e può fermarsi; i pezzi a lunga gittata che si scoprono dietro chi cattura, sulla stessa linea, entrano nello scambio (raggi X). Il modello ignora inchiodature, scacchi e minacce altrove. Si dichiara con l'implementazione. |
| Delta pruning | `HEURISTIC`; `EMPIRICAL` quando validato | La specifica dice «quando validato». |
| Scacchi in quiescenza | `HEURISTIC` | La specifica dice «quando giustificato». |

### Valutazione e NNUE

| Tecnica | Classe | Motivo e ipotesi |
|---|---|---|
| Termini della valutazione classica | `HEURISTIC`; pesi `LEARNED` se stimati su dati (per esempio con il tuning alla Texel), `EMPIRICAL` se scelti confrontando misure | È un'approssimazione di V(s). |
| Aggiornamento incrementale (materiale, pawn state, tabelle) | `EXACT` | Deve essere uguale al ricalcolo (INV-C3). |
| NNUE: pesi | `LEARNED` | Il risultato dipende da dati, procedura e seme. |
| NNUE: aggiornamento incrementale dell'accumulatore | `EXACT` | Deve essere uguale al ricalcolo completo. Richiede aritmetica intera; vedi [QA-15](limiti-e-rischi.md#qa-15). |
| NNUE: inferenza quantizzata | `EXACT` rispetto alla definizione intera; forza `EMPIRICAL` | Il riferimento scalare definisce l'aritmetica, saturazioni comprese. |
| Backend SIMD | `EXACT` se bit-identici al riferimento scalare | INV-H3. |

### Generazione, tabelle, hardware

| Tecnica | Classe | Motivo e ipotesi |
|---|---|---|
| Generazione legale, make/unmake | `EXACT` (decisa per il livello ottimizzato: [ADR-0015](adr/0015-generatore-di-mosse-del-livello-ottimizzato.md)) | Confronto con il riferimento e perft. |
| Filtro di legalità per maschere di scacco e inchiodatura (livello ottimizzato, [ADR-0015](adr/0015-generatore-di-mosse-del-livello-ottimizzato.md)) | `EXACT` (decisa: ADR-0015) | Una mossa pseudo-legale che non è del re né en passant lascia il re attaccato solo se non risponde allo scacco o se porta un pezzo inchiodato fuori dalla linea dell'inchiodatura; le mosse di re e l'en passant si provano per intero. La base è nel docstring di `filter-legal`; evidenza per campioni: test differenziale e perft. |
| Tabelle di attacco, magic bitboards, PEXT | `EXACT` (tavole precalcolate del livello ottimizzato decise: [ADR-0015](adr/0015-generatore-di-mosse-del-livello-ottimizzato.md); PEXT non decisa) | Le occupazioni rilevanti per ogni casa sono enumerabili: la verifica può essere esaustiva. La ricerca dei numeri magici è empirica; la verifica del risultato no. |
| Magic bitboard del livello ottimizzato, a spostamento fisso e per casa ([ADR-0016](adr/0016-attacchi-dei-pezzi-a-lunga-gittata.md)) | `EXACT`; lo scarto rapido della ricerca dei numeri `HEURISTIC` (decisa: ADR-0016) | Costruendo le tavole si enumera ogni occupazione rilevante di ogni casa e vi si scrive l'attacco per raggi; un numero sotto cui due occupazioni con attacchi diversi hanno lo stesso indice ferma il caricamento. Le case fuori dalla maschera non cambiano gli attacchi. Evidenza esaustiva: ogni sottoinsieme delle case rilevanti di ogni casa confrontato con un cammino casa per casa, per ogni implementazione. I numeri vengono da una ricerca con seme dichiarato; lo scarto rapido dei candidati cambia quale numero si trova, non se è magico. La base è nei docstring di `initialise-magic-tables` e `find-magic-number`. |
| POPCNT, bit tricks | `EXACT` | Identità di bit, verificabili. |
| Dispatch CPU | `EXACT` | Sceglie tra implementazioni equivalenti (INV-H1, INV-H3). |
| Microkernel nativi (FFI) | `EXACT` (decisa: [ADR-0001](adr/0001-common-lisp-sbcl.md)) | Solo con test di equivalenza e fallback (INV-H2, [ADR-0001](adr/0001-common-lisp-sbcl.md)). |

### Parallelismo

| Tecnica | Classe | Motivo e ipotesi |
|---|---|---|
| Lazy SMP | `HEURISTIC` | Il risultato dipende dai tempi dei thread: la ricerca non è riproducibile. La forza è `EMPIRICAL`. |
| Entry della TT condivise tra thread | `HEURISTIC` (provvisoria) | Aperto (QA-07): l'integrità di una entry scritta in concorrenza. Una entry letta a metà può dare un valore sbagliato. [QA-07](limiti-e-rischi.md#qa-07) |

### Ottimizzazione dei parametri

| Tecnica | Classe | Motivo e ipotesi |
|---|---|---|
| Grid search, coordinate descent, SPSA, ottimizzazione bayesiana, self-play | `EMPIRICAL` (il risultato) | Un algoritmo di ottimizzazione può avere proprietà di convergenza dimostrate; il risultato su una funzione rumorosa come la forza di gioco no. Rischio di sovradattamento al corpus. |
| Tuning alla Texel e altri parametri stimati su dati etichettati | `LEARNED`; forza `EMPIRICAL` | È una taratura su posizioni etichettate: per la specifica, parametri ottenuti tramite training. Rischio di sovradattamento al corpus. |
| Riduzioni ed estensioni apprese | `HEURISTIC`; `LEARNED`; efficacia `EMPIRICAL` | Fase 12. Nessuna garanzia: una politica appresa può ridurre o estendere la mossa sbagliata. Deve poter essere spenta e tornare alla politica fissa. |
| Ordinamento appreso | `EXACT` sul valore di alpha-beta puro; `HEURISTIC` da quando una riduzione dipende dall'ordine (LMR); modello `LEARNED`; efficacia `EMPIRICAL` | Fase 12. Come l'ordinamento fisso. |

## Riferimenti

Ogni voce ha autori, titolo, sede, volume, pagine e, dove c'è, il DOI, così che il lettore possa
controllarla.

- Knuth, D. E.; Moore, R. W. (1975). «An analysis of alpha-beta pruning». *Artificial
  Intelligence* 6(4): 293–326. doi:10.1016/0004-3702(75)90019-3.
- Plaat, A.; Schaeffer, J.; Pijls, W.; de Bruin, A. (1996). «Best-first fixed-depth minimax
  algorithms». *Artificial Intelligence* 87(1–2): 255–293. doi:10.1016/0004-3702(95)00126-3.
- Buro, M. (1995). «ProbCut: An effective selective extension of the α-β algorithm». *ICCA
  Journal* 18(2): 71–76. doi:10.3233/ICG-1995-18202.
- Zobrist, A. L. (1970). «A new hashing method with application for game playing». Rapporto
  tecnico 88, Computer Sciences Department, University of Wisconsin. Ristampa in *ICCA Journal*
  13(2): 69–73, 1990. doi:10.3233/ICG-1990-13203.
- Wald, A. (1945). «Sequential tests of statistical hypotheses». *The Annals of Mathematical
  Statistics* 16(2): 117–186. doi:10.1214/aoms/1177731118. Usato in [misure](misure.md).
- Spall, J. C. (1992). «Multivariate stochastic approximation using a simultaneous perturbation
  gradient approximation». *IEEE Transactions on Automatic Control* 37(3): 332–341.
  doi:10.1109/9.119632.
- Romein, J. W.; Bal, H. E.; Schaeffer, J.; Plaat, A. (2002). «A performance analysis of
  transposition-table-driven work scheduling in distributed search». *IEEE Transactions on
  Parallel and Distributed Systems* 13(5): 447–459. doi:10.1109/TPDS.2002.1003855.
