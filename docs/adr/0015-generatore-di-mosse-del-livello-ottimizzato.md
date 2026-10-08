# ADR-0015 — Generatore di mosse del livello ottimizzato

- **Stato:** Accettata
- **Data:** 2026-10-04; accettata dall'autore il 2026-10-04, per sua decisione in sessione
- **Rapporto con la specifica:** proposta nuova (non nella specifica); applica «BOARD
  REPRESENTATION», «MOVE REPRESENTATION», «MOVE GENERATION», «PERFT» e «REFERENCE ENGINE».
  Confermata dall'autore il 2026-10-04.
- **Riferimenti:** [architettura](../architettura.md#rappresentazione-e-generazione-delle-mosse),
  [verifica](../verifica.md#test-differenziale), [classificazione](../classificazione.md),
  INV-C1, INV-C2, INV-C3, INV-C4, INV-A3, INV-A5,
  [ADR-0010](0010-regole-di-indipendenza-tra-i-livelli.md),
  [ADR-0014](0014-policy-di-compilazione-del-livello-ottimizzato.md),
  [QA-17](../limiti-e-rischi.md#qa-17)

## Contesto

La specifica chiede per il livello ottimizzato bitboard a 64 bit, make/unmake con stack
preallocati e senza copie della posizione, `Move` packed, buffer di mosse preallocati, e quattro
fasi separate: generazione pseudo-legale, filtro di legalità, ordinamento, esecuzione. Chiede di
gestire inchiodature, scacchi scoperti, doppi scacchi, en passant inchiodato, vincoli di attacco
sull'arrocco e legalità della promozione, e di ottimizzare in seguito con tabelle di attacco,
magic bitboard, PEXT e simili, ciascuna misurata.

[ADR-0010](0010-regole-di-indipendenza-tra-i-livelli.md) vuole che l'ottimizzato implementi da
sé tutto ciò che il confronto giudica (mosse, attacchi, make/unmake, chiavi) e usi il riferimento
solo per convertire una posizione. Il riferimento genera le mosse pseudo-legali e decide la
legalità facendo ogni mossa e controllando il re.

## Decisione

> **Deciso (autore → ADR-0015)** — Proposta del repository, confermata dall'autore il
> 2026-10-04.

1. **Posizione.** Dodici bitboard di pezzi, l'occupazione di ogni colore, l'occupazione totale,
   una tavola di 64 codici di pezzo (per sapere senza scansioni che cosa sta su una casa), gli
   stessi campi di stato del riferimento e la chiave. make/unmake cambiano la posizione sul posto.
   Lo stack di undo è fatto di vettori tipizzati preallocati (256 voci) e raddoppia solo quando una
   partita giocata su una posizione lo riempie; una ricerca o un perft non ci arrivano.
2. **Chiave incrementale.** make aggiorna la chiave con lo XOR delle sole parti che la mossa
   cambia. La politica dell'en passant scritta nel `core`
   ([`src/core/zobrist.lisp`](../../src/core/zobrist.lisp)) è implementata due volte in questo
   livello: con la tavola degli attacchi di pedone in make, con l'aritmetica delle colonne nella
   chiave calcolata da zero (`bitboard-compute-key`). I test confrontano le due fra loro e con la
   chiave del riferimento.
3. **Attacchi.** Tavole precalcolate, vettori di `(unsigned-byte 64)`: cavallo, re, pedone per
   colore, i raggi delle otto direzioni, le case tra due case allineate e la linea che le unisce.
   I pezzi a lunga gittata stanno dietro un'interfaccia sola, `bishop-attacks` e `rook-attacks`
   di una casa e di un'occupazione (`queen-attacks` è la loro unione). Questo ADR è nato con
   l'implementazione classica per raggi con ricerca del primo bloccante; dietro la stessa
   interfaccia, senza toccare i chiamanti, che sono tre file, ora ci sono anche due disposizioni
   di magic bitboard, e quale si usa lo decide
   [ADR-0016](0016-attacchi-dei-pezzi-a-lunga-gittata.md). Lo stesso test esaustivo le giudica
   tutte.
4. **Tre funzioni separate.** `bitboard-generate-pseudo-legal` (generazione pseudo-legale),
   `bitboard-generate-legal` (la generazione pseudo-legale seguita dal filtro di legalità, sul
   posto) e `bitboard-make-move` / `bitboard-unmake-move` (esecuzione). L'ordinamento non esiste
   ancora. L'arrocco segue la regola del riferimento (generato solo con il diritto, re e torre a
   casa, case libere, nessuna delle tre case del re attaccata): i due livelli definiscono così lo
   stesso insieme pseudo-legale, e il test differenziale confronta anche quello.
5. **Filtro di legalità per maschere.** Per ogni posizione si calcolano i pezzi che danno scacco,
   i pezzi inchiodati al proprio re e le case che una mossa non di re può raggiungere per
   rispondere a uno scacco. Una mossa che non è del re né en passant è legale se rispetta la
   maschera di scacco e, se il pezzo è inchiodato, resta sulla linea fra il re e la sua casa. Una
   mossa di re è legale se la destinazione non è attaccata con il re tolto dall'occupazione.
   Una cattura en passant si prova per intero sulla posizione che ne risulta. La base della
   classificazione è nel docstring di `filter-legal`
   ([`src/optimized/legal.lisp`](../../src/optimized/legal.lisp)).
6. **Buffer di mosse impilati.** Un buffer serve un albero intero, con `+bitboard-ply-moves+` =
   512 posti per ply più uno. Le mosse di un nodo cominciano dove finiscono le mosse legali del
   padre, quindi un ply non scrive mai su una lista ancora in uso. Quando il materiale di ogni
   lato può nascere in una partita (un re, al più 15 altri pezzi, e non più donne, torri, alfieri
   e cavalli di quelli iniziali più i pedoni promossi), una posizione ha al più 323 mosse
   pseudo-legali: la somma delle mosse massime di ogni pezzo, nove donne da 27, due torri da 14,
   due alfieri da 13, due cavalli da 8, un re da 8 più due arrocchi. Un albero di `n` ply sta
   allora in 323 · n posti, meno di quelli del buffer. Oltre quel limite il controllo dei limiti
   segnala un errore ([ADR-0014](0014-policy-di-compilazione-del-livello-ottimizzato.md)), mai un
   conteggio sbagliato.
7. **Perft e divide** con la definizione del riferimento, compreso il conteggio alla foglia.
   `bitboard-perft-with-buffer` riceve il buffer invece di crearlo; quanto alloca il perft lo
   controlla il test di allocazione
   ([ADR-0014](0014-policy-di-compilazione-del-livello-ottimizzato.md), punto 5).
8. **Nomi.** Dove il riferimento esporta lo stesso nome (`make-move`, `perft`, …) l'ottimizzato
   usa il prefisso `bitboard-`: i due livelli non esportano nomi uguali.

**Classificazione:** tavole precalcolate `EXACT`; attacchi classici per raggi `EXACT` (magic
bitboard: [ADR-0016](0016-attacchi-dei-pezzi-a-lunga-gittata.md));
aggiornamenti incrementali di make e record di undo `EXACT`; filtro di legalità per maschere
`EXACT`; conteggio alla foglia `EXACT`. Base ed evidenza sono nei docstring delle funzioni.

**Invarianti:** INV-C1 (insiemi di mosse uguali), INV-C2 (make e unmake restituiscono lo stato
esatto), INV-C3 (chiave incrementale uguale a quella calcolata da zero), INV-C4 (perft dei due
livelli), INV-A3 (nessun algoritmo nel `core`: la politica dell'en passant è implementata qui per
conto proprio), INV-A5 (`Move` packed, buffer e stack preallocati).

**Verifica:** suite `optimized` (tavole, interfaccia dei pezzi a lunga gittata, casi limite di
make/unmake, allocazione), `optimized-movegen` (la suite dei casi speciali eseguita su questo
livello), `optimized-perft` (gli stessi valori attesi del riferimento, letti dalle stesse
tabelle), `differential` (insiemi di mosse, stato e chiave dopo ogni make e ogni unmake);
`make differential-deep` su milioni di posizioni, `make perft-deep` alle profondità profonde.

## Conseguenze

- Il riferimento e l'ottimizzato decidono la legalità con due algoritmi diversi (fare la mossa e
  guardare il re; maschere di scacco e inchiodatura). Un errore comune ai due livelli è meno
  probabile che con lo stesso algoritmo scritto due volte (RSK-05).
- Un'implementazione nuova degli attacchi dei pezzi a lunga gittata entra dietro l'interfaccia
  di `src/optimized/sliders.lisp` e deve passare i test esaustivi sulle occupazioni dei raggi di
  ogni casa (`slider-attacks-match-a-naive-walk` e quelli di
  [ADR-0016](0016-attacchi-dei-pezzi-a-lunga-gittata.md)). Le magic bitboard sono entrate così.
- L'ordinamento delle mosse, la quarta fase della specifica, resta da fare: arriverà con la
  ricerca (Fase 3).
- Una posizione con materiale fuori dal limite del punto 6 può fermare perft con un errore.

## Alternative considerate

- *Fare ogni mossa e controllare il re, come il riferimento:* scartata per l'ottimizzato.
  Costa make e unmake per ogni mossa pseudo-legale, e ripeterebbe nell'ottimizzato l'algoritmo
  dell'oracolo.
- *Generare direttamente le mosse legali (maschere applicate durante la generazione):* scartata,
  perché fonde generazione e filtro, che la specifica chiede separati. Si presume che faccia meno
  lavoro per nodo; non è stato misurato, perché nel repository non esiste un generatore del
  genere.
- *Regioni a passo fisso per ply, come il riferimento:* scartata. Un nodo con più mosse del passo
  scriverebbe nella regione del figlio senza errore; con l'impilamento non succede.
- *Magic bitboard subito:* rimandate a un passo successivo, dietro la stessa interfaccia, con la
  propria misura; quel passo è [ADR-0016](0016-attacchi-dei-pezzi-a-lunga-gittata.md).

## Valutazione

- Rischi: RSK-05 (errore comune ai due livelli), ridotto da algoritmi diversi e dai valori
  pubblicati di perft.
- Il filtro per maschere è scelto anche per il costo per mossa, senza un record di ricerca e
  senza una misura contro l'alternativa del riferimento nel livello ottimizzato; come gli si
  applica INV-X3 è [QA-17](../limiti-e-rischi.md#qa-17).
- Porterebbe a rivedere la decisione: una differenza trovata dal test differenziale che il filtro
  per maschere non possa evitare senza casi speciali; oppure misure (`make bench`,
  `make hot-path`) che mostrino il filtro come costo dominante rispetto a una generazione
  direttamente legale.
