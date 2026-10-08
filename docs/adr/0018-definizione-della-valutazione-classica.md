# ADR-0018 — Definizione della valutazione classica

- **Stato:** Accettata
- **Data:** 2026-10-04; accettata dall'autore il 2026-10-07, come aveva deciso il 2026-10-04: dopo la risoluzione di
  [QA-18](../limiti-e-rischi.md#qa-18)
- **Rapporto con la specifica:** proposta nuova (non nella specifica); applica «EVALUATION»
  (i nove termini della valutazione classica, le rappresentazioni incrementali dove conviene),
  «REFERENCE ENGINE» (il riferimento è oracolo anche per la valutazione) e il gate della
  [Fase 2](../roadmap.md#fase-2). La specifica nomina i termini e non dà formule né pesi.
- **Riferimenti:** [valutazione](../valutazione.md), [invarianti](../invarianti.md#correttezza)
  (INV-C1, INV-C2, INV-C3, INV-C7, INV-C8, INV-C9, INV-C10, INV-X7),
  [classificazione](../classificazione.md#valutazione-e-nnue),
  [ADR-0007](0007-licenza-bsd-2-clause-e-originalita.md),
  [ADR-0010](0010-regole-di-indipendenza-tra-i-livelli.md),
  [ADR-0013](0013-interpretazione-operativa-dell-originalita.md),
  [ADR-0015](0015-generatore-di-mosse-del-livello-ottimizzato.md),
  [ADR-0017](0017-percorso-di-ricerca-per-le-alternative-exact.md),
  [QA-18](../limiti-e-rischi.md#qa-18), [QA-19](../limiti-e-rischi.md#qa-19),
  [EXP-0002](../../research/exp-0002-stato-incrementale-della-valutazione.md)

## Contesto

Il gate della Fase 2 chiede che la ricerca dell'engine ottimizzato restituisca a profondità
fissa lo stesso valore della ricerca del riferimento, che ogni termine incrementale della
valutazione sia uguale al ricalcolo (INV-C3) e che la valutazione sia invariante per scambio dei
colori, vista da chi muove. Quando questo ADR è stato scritto, il riferimento aveva solo una
valutazione di materiale (`evaluate-material`), e il livello ottimizzato nessuna.

Perché due implementazioni indipendenti diano lo stesso intero su ogni posizione, la
valutazione deve essere definita una volta, per iscritto, fino all'arrotondamento: quali pezzi e
quali case contano, che cosa è un attacco, in che ordine si combinano i termini, come si divide.
Una definizione lasciata al codice di uno dei due livelli farebbe di quel codice l'oracolo
dell'altro, e il confronto non giudicherebbe più nulla
([ADR-0010](0010-regole-di-indipendenza-tra-i-livelli.md)). Per l'originalità
([ADR-0007](0007-licenza-bsd-2-clause-e-originalita.md),
[ADR-0013](0013-interpretazione-operativa-dell-originalita.md)) i pesi e le tavole non si
prendono da altri engine né da tabelle pubblicate; le idee pubbliche sì (ADR-0013, punto 1), e
dove un numero o una definizione coincide con quelli di un engine pubblicato il documento lo
dice ([valutazione](../valutazione.md#provenienza)).

## Decisione

> **Deciso (autore → ADR-0018)** — Proposta del repository, accettata dall'autore il
> 2026-10-07, con i pesi della struttura pedonale fissati dalla regola che ha chiesto (QA-18).

1. **Una definizione normativa.** La valutazione classica è quella di
   [valutazione](../valutazione.md): le sue formule sono la definizione; le tavole che vi sono
   stampate sono generate dalle formule e servono a controllarle. Una modifica della valutazione
   cambia prima quel documento.
2. **Aritmetica.** Interi in centipawn. Ogni termine dà, per ciascun colore, un valore di
   mediogioco e uno di finale; i contributi sono `X(W) − X(B)`. La fase è il materiale non di
   pedone rimasto in unità di pedone (cavallo e alfiere 3, torre 5, donna 9), al più 62. La
   miscela è `tr((MG · fase + EG · (62 − fase)) / 62)` con il quoziente troncato verso zero,
   perché il troncamento è una funzione dispari e conserva la simmetria dei colori, mentre il
   quoziente per difetto no. Il risultato si limita a ±20000.
3. **Punto di vista.** Il punteggio si calcola dal punto di vista del Bianco e si restituisce da
   quello di chi muove.
4. **Termini.** I nove della specifica, nel suo ordine: materiale (100, 300, 300, 500, 900, i
   valori che il riferimento già usa), piece-square tables generate da regole di centralità, di
   avanzamento del pedone e di riparo del re, mobilità sulle case non occupate da pezzi propri e
   non attaccate da pedoni avversari, sicurezza del re (attacco alla zona del re e riparo dei
   pedoni, solo in mediogioco), struttura pedonale (doppiati, isolati, arretrati con una
   definizione esatta), pedoni passati, spazio, iniziativa (letta come il valore del tratto: la
   specifica non la definisce, e le altre letture sono in Alternative considerate), minacce.
   Gli attacchi sono quelli pseudo-legali dei pezzi sull'occupazione completa, senza
   inchiodature né raggi X. Formule e regole da cui vengono i numeri sono nel documento.
5. **Simmetria per costruzione.** Ogni termine si calcola con la stessa formula per i due
   colori, in coordinate relative al colore, ed è una somma, un conteggio, un minimo o un massimo
   su insiemi; nessun risultato dipende dall'ordine di visita delle case.
6. **Stato incrementale.** Il livello ottimizzato tiene incrementali, in make e unmake, la somma
   di materiale e piece-square tables in mediogioco e in finale e la fase prima del tetto; gli
   altri termini si calcolano a ogni valutazione. La conversione dal riferimento li calcola da
   zero nel livello ottimizzato. Il riferimento calcola tutto da zero.
7. **Indipendenza.** Ciascun livello implementa le formule per conto proprio, con le proprie
   tavole d'attacco ([ADR-0010](0010-regole-di-indipendenza-tra-i-livelli.md), punti 3 e 4). Il
   `core` può contenere i parametri, che sono interi con nome (INV-A3), non le formule né le
   tavole generate.
8. **Convenzioni per la ricerca.** Quelle della ricerca del riferimento: a profondità 0 la
   valutazione statica senza controllo di matto o stallo; matto `P − 30000` alla distanza `P`
   dalla radice; stallo 0; nessuna patta per ripetizione, per la regola delle cinquanta mosse o
   per materiale insufficiente. La valutazione dipende solo dalla disposizione dei pezzi e dal
   lato al tratto.
9. **Nessuna taratura.** Il repository non tara alcun peso: nessuno vi è stimato su dati,
   scelto con una misura registrata o validato da un esperimento. Ogni peso ha accanto una
   regola semplice dichiarata nel documento. Dove la regola non fissa il numero, il numero è una
   scelta dentro la regola. I sei pesi della struttura pedonale li fissa una regola
   ([valutazione](../valutazione.md#struttura-pedonale)), scritta per decisione dell'autore su
   [QA-18](../limiti-e-rischi.md#qa-18): sostituisce i pesi della prima stesura, che la regola
   di allora non fissava e cinque dei quali erano costanti di Fruit 2.1 negli stessi ruoli, il
   caso dubbio di [ADR-0013](0013-interpretazione-operativa-dell-originalita.md) (punto 5). Le
   coincidenze note con engine pubblicati sono elencate in
   [valutazione](../valutazione.md#provenienza). La taratura è della [Fase 10](../roadmap.md#fase-10).

**Classificazione:** ogni termine `[HEURISTIC]`, non tarato dal repository (per il repository
nessun peso è `[LEARNED]` né `[EMPIRICAL]`; per i sei pesi della struttura pedonale vale il
punto 9); le tavole precalcolate dalle formule `[EXACT]` (dominio finito, si controllano
per intero); lo stato incrementale `[EXACT]` (uguale al ricalcolo, INV-C8). Fase, miscela,
limite e punto di vista fanno parte della definizione e non riducono lavoro.

**Invarianti:** introduce, in stato Proposta, INV-C7 (simmetria dei colori), INV-C8 (stato
incrementale della valutazione uguale al ricalcolo, un caso di INV-C3), INV-C9 (`|E_W| ≤ 20000`,
sotto la soglia dei punteggi di matto), INV-C10 (la valutazione dipende solo dalla disposizione
dei pezzi e dal lato al tratto). Tocca INV-C1 (valutazione uguale fra i livelli) e INV-C2
(l'unmake riporta anche lo stato incrementale).

**Verifica:** test differenziale della valutazione fra i livelli, con la scomposizione per
termine; simmetria dei colori sulle tabelle di perft, sui casi speciali, sulle posizioni di
partenza del fuzzer e su posizioni casuali con seme dichiarato, in entrambi i livelli; stato
incrementale contro il ricalcolo dopo ogni make e uguale a quello di prima dopo ogni unmake;
il limite sulle stesse posizioni della simmetria, e la dipendenza dalla sola posizione su
posizioni scelte; gli esempi e le tavole del documento come valori attesi, calcolati dalla
definizione e non pubblicati. Le posizioni di ciascun controllo sono in
[valutazione](../valutazione.md#verifica).

## Conseguenze

- Il riferimento avrà una seconda funzione di valutazione accanto a `evaluate-material`, che
  resta con i suoi test; le ricerche del riferimento continuano a passare i test esistenti, che
  assumono la valutazione di materiale. Come la ricerca riceve la valutazione da usare è una
  scelta dell'implementazione.
- La prima firma di ricerca della Fase 2 dipende da questa definizione. Cambiare un peso cambia
  la funzione cercata e quindi la firma: è una modifica che cambia un'uscita, e per
  [ADR-0017](0017-percorso-di-ricerca-per-le-alternative-exact.md) segue il percorso intero.
- Le piece-square tables sono generate da poche costanti. Una taratura che volesse una voce per
  casa (Fase 10) cambierebbe la parametrizzazione: si decide con un ADR nuovo.
- I parametri stanno in un solo posto per livello: oggi il riferimento e il livello ottimizzato
  ne tengono ciascuno una copia, che il test differenziale confronta; portarli nel `core` (punto
  7) è una scelta aperta ([ADR-0019](0019-valutazione-e-ricerca-del-livello-ottimizzato.md)).
  INV-X7 chiede di poterli cambiare senza cambiare il codice; la forma (per esempio un file di
  dati letto al caricamento) si decide con l'implementazione. Per decisione dell'autore INV-X7
  si applica alla valutazione dalla [Fase 10](../roadmap.md#fase-10)
  ([ADR-0020](0020-parametri-della-valutazione-dalla-fase-10.md), che chiude
  [QA-19](../limiti-e-rischi.md#qa-19)): fino ad allora i parametri sono costanti nel codice.
- Ogni termine non incrementale si calcola per intero a ogni valutazione. Una cache, per esempio
  della struttura pedonale, è deduplicazione: entra solo con la misura che la specifica chiede.
- La valutazione non conosce le patte per materiale insufficiente: re contro re non vale 0, ma
  l'iniziativa più la differenza fra le tabelle dei due re in finale, e quindi dipende da dove
  stanno i re; per chi muove vale 10 solo con i re ugualmente centrali
  ([Convenzioni per la ricerca](../valutazione.md#convenzioni-per-la-ricerca), «Patte per
  regola»).

## Alternative considerate

- *Quoziente per difetto (`floor`) nella miscela:* scartato. Non è una funzione dispari: una
  posizione e la sua riflessa possono differire di 1 dopo la negazione, e INV-C7 non vale per
  costruzione.
- *Miscela senza divisione (fase come potenza di due, spostamento aritmetico):* scartata. Lo
  spostamento aritmetico arrotonda per difetto e ha lo stesso difetto di `floor`, e la fase
  massima non sarebbe più il materiale della posizione iniziale.
- *Pesi di fase 1, 1, 2, 4 (somma 24):* scartati. Sono una convenzione diffusa fra gli engine;
  i valori dei pezzi divisi per 100 danno una misura con un significato diretto (il materiale non
  di pedone rimasto), che segue da una regola del documento.
- *Piece-square tables scritte casa per casa:* scartate. Sessantaquattro numeri per tavola senza
  una regola sono difficili da giustificare e da controllare, e rischiano di somigliare a tavole
  di altri engine; le formule sono poche e controllabili. Generare le tavole da formule è
  un'idea che usano anche altri engine (Fruit 2.1, per esempio); forme e coefficienti sono del
  documento, salvo le coincidenze elencate in [valutazione](../valutazione.md#provenienza).
- *Iniziativa, altre letture.* La specifica nomina «initiative» senza definirla. Letture
  considerate: il valore del tratto (la proposta); una correzione del punteggio secondo la
  struttura della posizione, come il termine «initiative» della valutazione classica di
  Stockfish (pedoni passati, pedoni sulle due ali, posizione dei re), che chiederebbe di
  definire la struttura e di tenerla simmetrica; una misura dell'attività, per esempio gli
  attacchi nella metà avversaria, che si sovrapporrebbe a mobilità, spazio e minacce; nessun
  termine, che lascerebbe i termini a otto contro i nove della specifica. Il valore del tratto è
  il più semplice da scrivere e da verificare e non duplica gli altri termini; la scelta della
  lettura è dell'autore, con l'accettazione di questo ADR, come per
  [QA-13](../limiti-e-rischi.md#qa-13) è dell'autore la lettura di un altro nome che la
  specifica non definisce.
- *Riparo con i pedoni sulla traversa del re e tre colonne per il re sul bordo.* La definizione
  proposta conta solo i pedoni davanti al re e, per un re sulla colonna a o h, due colonne. Ne
  seguono due effetti, scritti in [valutazione](../valutazione.md#sicurezza-del-re): un re in g2
  con i pedoni in f2, g3, h2 paga nel riparo 50 più del re in g1, e un re in un angolo senza
  pedoni paga 30 meno di uno sulla colonna accanto. Un'alternativa: contare anche i pedoni sulla
  traversa del re, con `d = max(0, rr − rK − 1)`, e per un re sul bordo le tre colonne più
  vicine (a-c o f-h). Non scelta finora; è una modifica della definizione, che ora chiede un
  ADR che sostituisca questo, e cambierebbe gli esempi calcolati, i valori attesi dei
  test e la firma di ricerca.
- *Tenere i pesi della struttura pedonale della prima stesura,* registrando la coincidenza con
  Fruit 2.1: scartato dall'autore ([QA-18](../limiti-e-rischi.md#qa-18)), che ha scelto pesi
  fissati da una regola scritta ([valutazione](../valutazione.md#struttura-pedonale)).
- *Tutti i termini incrementali:* scartato per ora. Mobilità, minacce e sicurezza del re
  dipendono dagli attacchi, che una mossa cambia lontano dalle sue case; l'aggiornamento
  incrementale sarebbe complesso e il suo vantaggio non è misurato. Non è misurato neppure il
  vantaggio dello stato incrementale scelto al punto 6: ha l'equivalenza con il ricalcolo, non
  la misura che [ADR-0017](0017-percorso-di-ricerca-per-le-alternative-exact.md) chiede
  ([EXP-0002](../../research/exp-0002-stato-incrementale-della-valutazione.md)).
- *Nessuno stato incrementale:* make e unmake non toccano la valutazione, che calcola da zero
  anche materiale, piece-square tables e fase. Più semplice, e senza costo nel perft. Non scelto:
  la specifica chiede rappresentazioni incrementali «dove conveniente» e nomina il materiale fra
  i calcoli incrementali («DEDUPLICATION»); dove convenga lo dice la misura di EXP-0002, che
  confronta proprio le due scelte.
- *Lasciare la definizione al codice del riferimento:* scartato. Il riferimento diventerebbe la
  definizione, e un suo errore non avrebbe un giudice esterno; con un documento, gli esempi
  calcolati a mano giudicano il riferimento da fuori.
- *Limite della valutazione non dichiarato:* scartato. Il lettore FEN non limita il numero dei
  pezzi, e una posizione con molte donne avrebbe una valutazione statica letta come matto.

## Valutazione

- Rischi: RSK-05 (i due livelli sbagliano nello stesso modo perché leggono male lo stesso
  documento; lo riducono gli esempi calcolati a mano e la scomposizione per termine), RSK-06
  (etichette ottimistiche: ogni termine resta `[HEURISTIC]`).
- Si verifica con i test della sezione Verifica di [valutazione](../valutazione.md#verifica).
  Oggi esistono per i due livelli, che implementano entrambi la definizione
  ([verifica](../verifica.md#valutazione-e-ricerca-del-riferimento),
  [verifica](../verifica.md#valutazione-e-ricerca-del-livello-ottimizzato)).
- Originalità: alcuni numeri e alcune definizioni coincidono con quelli di Fruit 2.1 e di
  Stockfish 11 ([valutazione](../valutazione.md#provenienza)). Le idee sono ammesse da
  [ADR-0013](0013-interpretazione-operativa-dell-originalita.md) (punto 1); i pesi della
  struttura pedonale, il caso dubbio che il punto 5 porta all'autore, l'autore li ha fatti
  sostituire con pesi fissati da una regola ([QA-18](../limiti-e-rischi.md#qa-18)). Il
  documento non afferma che nessun valore somigli a quelli di un altro engine: il confronto ne
  copre due.
- Porterebbe a rivedere la decisione: una decisione dell'autore sul riparo
  (Alternative considerate); un termine che non si riesce a scrivere in modo simmetrico per
  costruzione; una formula che i due livelli leggono in due modi diversi (si corregge il
  documento); un costo della valutazione, misurato, che renda necessaria un'altra
  rappresentazione incrementale, o l'esito di
  [EXP-0002](../../research/exp-0002-stato-incrementale-della-valutazione.md) sullo stato
  incrementale del punto 6.
