# ADR-0019 — Valutazione e ricerca del livello ottimizzato, firma di ricerca

- **Stato:** Accettata
- **Data:** 2026-10-04; accettata dall'autore il 2026-10-07, come aveva deciso il 2026-10-04: dopo la risoluzione di
  [QA-18](../limiti-e-rischi.md#qa-18)
- **Rapporto con la specifica:** proposta nuova (non nella specifica); applica «EVALUATION»
  (rappresentazioni incrementali dove conviene), «SEARCH FOUNDATION» (negamax, alpha-beta e
  iterative deepening come baseline), «REFERENCE ENGINE» (il riferimento è oracolo anche per i
  risultati di ricerca, dove applicabile), «COMMON LISP / SBCL» (allocazione quasi nulla nel hot
  path) e il gate della [Fase 2](../roadmap.md#fase-2); applica nel livello ottimizzato
  [ADR-0018](0018-definizione-della-valutazione-classica.md), accettato lo stesso giorno.
- **Riferimenti:** [valutazione](../valutazione.md),
  [verifica](../verifica.md#regressione-di-ricerca), [architettura](../architettura.md),
  [misure](../misure.md), INV-C1, INV-C2, INV-C3, INV-C7, INV-C8, INV-A5, INV-X3, INV-X7,
  [QA-19](../limiti-e-rischi.md#qa-19), [ADR-0020](0020-parametri-della-valutazione-dalla-fase-10.md),
  [EXP-0002](../../research/exp-0002-stato-incrementale-della-valutazione.md),
  [ADR-0010](0010-regole-di-indipendenza-tra-i-livelli.md),
  [ADR-0014](0014-policy-di-compilazione-del-livello-ottimizzato.md),
  [ADR-0015](0015-generatore-di-mosse-del-livello-ottimizzato.md),
  [ADR-0017](0017-percorso-di-ricerca-per-le-alternative-exact.md),
  [ADR-0018](0018-definizione-della-valutazione-classica.md)

## Contesto

Il gate della Fase 2 chiede che la ricerca del livello ottimizzato restituisca a profondità fissa
il valore della ricerca del riferimento, che alpha-beta e negamax diano lo stesso valore anche
permutando le mosse, che l'iterative deepening a profondità `d` dia il valore della ricerca
diretta, che lo stato incrementale della valutazione sia uguale al ricalcolo e che la valutazione
sia simmetrica per scambio dei colori, e che la prima firma di ricerca sia registrata.

[ADR-0018](0018-definizione-della-valutazione-classica.md) definisce la valutazione e dice quale
stato il livello ottimizzato tiene incrementale, ma lascia libere alcune scelte: come l'unmake
riporta quello stato («il modo è libero»), dove il livello ottimizzato tiene i parametri, come la
ricerca tiene la variante principale senza allocare. Restano da decidere anche che cosa della
ricerca si confronta con il riferimento, dato che i due generatori scrivono le mosse in ordini
diversi, e il formato e la regola di aggiornamento della firma di ricerca, che
[verifica](../verifica.md#regressione-di-ricerca) propone senza fissarli.

## Decisione

> **Deciso (autore → ADR-0019)** — Proposta del repository, accettata dall'autore il
> 2026-10-07.

1. **Parametri.** Il livello ottimizzato ha una copia propria dei parametri della valutazione, con
   i nomi del [riepilogo](../valutazione.md#riepilogo-dei-parametri), in
   [`src/optimized/evaluation-tables.lisp`](../../src/optimized/evaluation-tables.lisp), e genera
   da sé, dalle formule, tutte le tavole. Il riferimento ha la sua
   ([`src/reference/classical.lisp`](../../src/reference/classical.lisp)). Il test differenziale
   confronta i due livelli termine per termine e colore per colore, quindi un parametro che
   differisce fra le copie fa fallire `make test`.
2. **Stato incrementale.** La posizione bitboard tiene `psq-mg`, `psq-eg` e `phase-raw`. make li
   aggiorna con due tavole con segno, indicizzate dal codice del pezzo e dalla casa, che valgono
   `σ(c) · (V(t) + pst(t, s'))`, e con il peso di fase del pezzo; unmake li rilegge dallo stack di
   undo, in tre vettori tipizzati accanto agli altri. Il calcolo da zero somma le tavole senza
   segno, colore per colore, e i valori dei pezzi: non condivide una tavola con make. La
   conversione dal riferimento calcola lo stato da zero, il controllo di coerenza lo ricalcola e
   l'uguaglianza fra posizioni lo confronta.
3. **Valutazione.** `bitboard-evaluate` legge materiale, piece-square tables e fase dallo stato
   incrementale e calcola gli altri termini dalle bitboard a ogni chiamata;
   `bitboard-evaluate-from-scratch` ricalcola anche quei tre, e `bitboard-classical-breakdown`
   restituisce la scomposizione per termine e colore nella forma di quella del riferimento. Le tre
   espandono le stesse funzioni inline. Le due valutazioni sono nel hot path
   ([ADR-0014](0014-policy-di-compilazione-del-livello-ottimizzato.md)) e non allocano.
4. **Ricerca.** Negamax, alpha-beta fail-soft e iterative deepening a profondità fissa, con le
   [convenzioni della ricerca del riferimento](../valutazione.md#convenzioni-per-la-ricerca):
   finestra piena alla radice, punteggi di matto relativi al ply, la stessa definizione della
   variante principale (la prima mossa che raggiunge il punteggio migliore, seguita dalla sua
   variante). Nessun ordinamento delle mosse, nessuna TT, nessuna potatura oltre ad alpha-beta,
   nessuna quiescenza. Un contesto preallocato tiene il buffer delle mosse, condiviso fra i ply
   come nel perft, la tavola triangolare delle varianti principali e il contatore dei nodi; con un
   contesto, una ricerca non alloca per nodo. Le funzioni di nodo chiamano generazione, make,
   unmake e valutazione: l'espansione inline del punto 6 di ADR-0014 resta del solo perft. Per i
   test, un generatore con seme può permutare le mosse di ogni nodo.
5. **Che cosa si confronta con il riferimento.** Il valore a profondità fissa, di alpha-beta e di
   negamax (INV-C1, «dove applicabile»), e il numero di nodi di negamax, che è la dimensione
   dell'albero e non dipende dall'ordine. La mossa migliore, la variante principale e il numero di
   nodi di alpha-beta non si confrontano: fra mosse di valore uguale, e in quanto alpha-beta pota,
   decide l'ordine delle mosse, che nei due livelli è diverso. Le varianti principali del
   livello ottimizzato le controlla invece il riferimento: le rigioca sulla propria posizione,
   con la propria legalità, e ognuna deve portare al punteggio, cioè alla valutazione classica
   del riferimento nella sua ultima posizione vista dalla radice, a uno scacco matto al ply che
   un punteggio di matto dice, o a uno stallo con punteggio 0. In `make test` le rigioca sulle
   posizioni di ricerca (alpha-beta fino a profondità 4 e negamax fino a 3, in ordine di
   generazione e permutate), su quelle della firma (alpha-beta a profondità 4), nel confronto
   con il riferimento e su posizioni casuali; in `make differential-deep` anche a profondità
   maggiori e su più posizioni casuali. Quali ricerche, a quali profondità e con quale test è
   in [verifica](../verifica.md#valutazione-e-ricerca-del-livello-ottimizzato).
6. **Firma di ricerca.** La firma è nel file di dati
   [`tests/search-signature.sexp`](../../tests/search-signature.sexp): per ogni posizione (le
   posizioni di perft e cinque posizioni di mediogioco, due quiete e tre tattiche, con le mosse
   che le raggiungono dalla posizione iniziale scritte in
   [`tests/test-optimized-search.lisp`](../../tests/test-optimized-search.lisp)) il valore, la
   mossa migliore, il numero di nodi e la variante principale di alpha-beta del livello
   ottimizzato a profondità 4, un thread. L'intestazione registra la revisione da cui partiva
   l'albero di lavoro e se era pulito, la policy del hot path, l'implementazione degli attacchi
   dei pezzi a lunga gittata, il Lisp, il sistema e la data. Lo scrive solo `make signatures`
   ([`tools/signatures.lisp`](../../tools/signatures.lisp)), che nessun altro target esegue; il
   test `optimized-search/search-signature-is-reproduced` lo ricalcola in `make test` e lo
   confronta. Si legge come dati, senza valutazione. Come si aggiorna è in
   [verifica](../verifica.md#regressione-di-ricerca).

**Classificazione:** ogni termine della valutazione `[HEURISTIC]`, non tarato (ADR-0018); le
tavole precalcolate dalle formule `[EXACT]`; lo stato incrementale `[EXACT]`, uguale al ricalcolo
(INV-C8); alpha-beta `[BOUNDED]`, con il valore di negamax a finestra piena; l'arresto
dell'iterative deepening su un punteggio di matto `[EXACT]`; negamax non riduce lavoro. I docstring
delle funzioni portano le etichette.

**Invarianti:** INV-C1 (valutazione, valore della ricerca), INV-C2 e INV-C8 (make e unmake con lo
stato della valutazione), INV-C7 nel livello ottimizzato, INV-A5 (nessuna allocazione per nodo).
Due invarianti Decisi erano non soddisfatti quando questo ADR fu proposto, e un ADR in stato
Proposta non poteva esentare da nessuno dei due (come per [QA-17](../limiti-e-rischi.md#qa-17)):

- **INV-X7** (ogni parametro importante si modifica senza cambiare il codice). I parametri della
  valutazione sono costanti nel codice dei due livelli (punto 1): cambiare un peso vuol dire
  cambiare il codice. Lo scostamento era [QA-19](../limiti-e-rischi.md#qa-19); l'autore l'ha
  chiuso con [ADR-0020](0020-parametri-della-valutazione-dalla-fase-10.md): INV-X7 si applica
  alla valutazione dalla Fase 10.
- **INV-X3** per lo stato incrementale del punto 2, un'alternativa `[EXACT]` con le stesse uscite
  del calcolo da zero: ha l'equivalenza, non la misura con una regola di decisione che
  [ADR-0017](0017-percorso-di-ricerca-per-le-alternative-exact.md) chiede (Valutazione, sotto).

**Verifica:** le suite `optimized-evaluation`, `optimized-search` e `differential` di `make test`,
con profondità e numeri di posizioni maggiori in `make differential-deep`; `make test-checked`;
i test di allocazione della valutazione e della ricerca; il test della firma. L'elenco è in
[verifica](../verifica.md#valutazione-e-ricerca-del-livello-ottimizzato).

## Conseguenze

- make e unmake fanno più lavoro, anche nel perft, che li espande e non valuta mai: le righe di
  perft di `make bench` e i tempi di `make hot-path` lo includono, ma nessun comando del
  repository lo isola, perché nessuno esegue make e unmake senza lo stato della valutazione.
- Finché ci sono due copie dei parametri, cambiare un peso vuol dire cambiare il documento e i due
  file; il test differenziale e i valori attesi del documento lo controllano. ADR-0018 propone i
  parametri in un solo posto e permette di metterli nel `core` (punto 7): portarceli resta una
  decisione dell'autore.
- La firma è un valore di regressione di questo engine, non un oracolo esterno: dice che la
  ricerca è cambiata, non quale dei due risultati è giusto. La giudica il riferimento, nel test
  `differential/search-signature-is-judged-by-the-reference`: in `make test` rigioca le varianti
  principali registrate, che devono portare ai valori registrati; in `make differential-deep`
  confronta anche ogni valore registrato con il valore del proprio alpha-beta alla profondità
  della firma ([verifica](../verifica.md#regressione-di-ricerca)).
- La firma dipende dall'ordine in cui il generatore scrive le mosse. Una modifica del generatore
  che cambia quell'ordine senza cambiare l'insieme delle mosse è `[EXACT]` per il perft, ma per la
  ricerca è un cambio dell'ordinamento: cambia nodi e forse mossa migliore e variante principale,
  non il valore ([verifica](../verifica.md#regressione-di-ricerca)). Con quella modifica la firma
  si rigenera, e il confronto dei valori con il riferimento resta.
- La valutazione e la ricerca si aggiungono a `*hot-path-files*`: `make test-checked` le esegue a
  `safety 3`, `make hot-path` ne scansiona il disassemblato, `make bench` le ricompila con ogni
  implementazione degli attacchi.
- Le note di efficienza della parte 1 di `make hot-path` comprendono note di questi due file.
  Quelle di `pawn-attack-set`, `piece-activity` e `terminal-score` riguardano il valore
  restituito da funzioni dichiarate inline: vengono dalle loro copie fuori linea, come spiega
  [ADR-0014](0014-policy-di-compilazione-del-livello-ottimizzato.md) (Conseguenze). La nota di
  `shuffle-node-moves` («signed word to integer coercion», non verso il valore restituito)
  quella spiegazione non la copre: la funzione è l'aggancio dei test che permuta le mosse di un
  nodo, chiama il generatore pseudocasuale del `core`, che può allocare, e le funzioni di nodo
  la chiamano solo quando la ricerca riceve `:shuffle-rng`, che passano solo i test della
  permutazione, non `make bench`, la firma né i test di allocazione. La parte 2 la elenca fra le
  chiamate piene di `negamax-node` e `alpha-beta-node`.

## Alternative considerate

- *I parametri nel `core`, usati dai due livelli* (ADR-0018, punto 7): un solo posto. Scartata per
  ora: un errore in un parametro condiviso non lo vedrebbe il confronto fra i livelli, solo i
  valori attesi del documento, e la scelta cambia il codice del riferimento. Resta aperta.
- *Unmake con l'aggiornamento inverso:* le operazioni di make al contrario. Scartata: più codice e
  più occasioni di errore, contro tre scritture e tre letture per mossa sullo stack di undo.
- *Ordinare le mosse del livello ottimizzato come il riferimento,* per confrontare anche nodi,
  mossa migliore e variante principale. Scartata: legherebbe il livello ottimizzato a un dettaglio
  interno del riferimento (l'ordine in cui visita la scacchiera), e sarebbe un ordinamento delle
  mosse, lavoro della Fase 3.
- *La variante principale come lista costruita a ogni nodo,* come nel riferimento. Scartata: alloca
  a ogni nodo (INV-A5).
- *La firma come codice Lisp* (un `defparameter` in un file compilato). Scartata: un file di dati si
  legge senza valutare nulla, e lo strumento che lo scrive non scrive codice.
- *Una firma più profonda:* giudica più nodi e rende `make test` più lento. La profondità è un
  parametro del file dei test (`*search-signature-depth*`); cambiarla cambia la firma.

## Valutazione

- Rischi: RSK-05 (i due livelli leggono il documento nello stesso modo sbagliato; lo riducono gli
  esempi del documento, che ora giudicano entrambi i livelli), RSK-06 (etichette ottimistiche:
  ogni termine resta `[HEURISTIC]`), RSK-01 e RSK-02 (allocazione e GC nella ricerca: i test di
  allocazione).
- Si verifica con i test elencati sopra; la firma con il suo test, su ogni piattaforma su cui
  `make check` gira.
- **Stato incrementale e [ADR-0017](0017-percorso-di-ricerca-per-le-alternative-exact.md).** Lo
  stato del punto 2 è un terzo caso, accanto al filtro per maschere e all'espansione delle
  funzioni di nodo che ADR-0017 esamina (Applicazione), di alternativa `[EXACT]` in uso con
  l'equivalenza ma senza la misura:

  | Condizione di ADR-0017 | Evidenza |
  |---|---|
  | `[EXACT]` | docstring di `bitboard-make-move` ([`src/optimized/make.lisp`](../../src/optimized/make.lisp)); INV-C8 |
  | Uscite identiche | la valutazione con lo stato e quella calcolata da zero danno lo stesso punteggio; ne segue la stessa ricerca, con la stessa firma |
  | Equivalenza differenziale, in `make check` | `optimized-evaluation/make-and-unmake-keep-the-evaluation-state`, `optimized-evaluation/the-two-evaluations-and-the-breakdown-agree`, il controllo di coerenza nel test differenziale delle mosse e `differential/evaluation-in-lockstep-playouts` ([verifica](../verifica.md#valutazione-e-ricerca-del-livello-ottimizzato)) |
  | Perft | `optimized-perft` in `make check`, con make e unmake che aggiornano lo stato |
  | Microbenchmark e `make bench`, con il registro e una regola | **Mancano in parte.** Le righe della valutazione di `make bench` danno ciò che lo stato risparmia a ogni valutazione ([misure](../misure.md#due-livelli-di-benchmark)); ciò che costa in make e unmake non lo isola nessun comando, perché nessuna variante li esegue senza lo stato. La regola di decisione è scritta in [EXP-0002](../../research/exp-0002-stato-incrementale-della-valutazione.md), prima di una misura confermativa |
  | Revisione committata e pulita | nessuna misura registrata |

  Finché EXP-0002 non si chiude, lo stato incrementale è uno scostamento da INV-X3.
- Porterebbe a rivedere la decisione: la forma dei parametri della Fase 10 (punto 1, ADR-0020);
  l'esito di EXP-0002, se mostra che lo stato incrementale non conviene; una firma che
  differisce fra piattaforme (INV-H5), che direbbe che la ricerca dipende da qualcosa che non è
  la posizione.
