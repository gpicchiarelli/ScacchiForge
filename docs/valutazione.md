# Valutazione classica

> **Fonte:** «EVALUATION», «REFERENCE ENGINE», «SEARCH FOUNDATION», «DEDUPLICATION» e «SEARCH +
> EVALUATION» della [specifica](specifica/specifica-originale.md). Decisione:
> [ADR-0018](adr/0018-definizione-della-valutazione-classica.md), accettato.

La specifica chiede di creare inizialmente una valutazione classica con nove termini: materiale,
piece-square tables, mobilità, sicurezza del re, struttura pedonale, pedoni passati, spazio,
iniziativa, minacce. Chiede rappresentazioni incrementali dove conviene, e vuole che il
riferimento faccia da oracolo anche per la valutazione («REFERENCE ENGINE»). Non dà formule né
pesi.

> **Deciso (autore → ADR-0018)** — Tutto ciò che segue in questo documento era una proposta
> del repository, registrata in [ADR-0018](adr/0018-definizione-della-valutazione-classica.md), che l'autore ha accettato
> il 2026-10-07. Gli invarianti che introduce (INV-C7, INV-C8, INV-C9, INV-C10) sono in
> [invarianti](invarianti.md#correttezza), decisi con esso.

## Scopo

Questo documento è la definizione unica della valutazione classica della Fase 2. Il riferimento
e il livello ottimizzato la implementano ciascuno per conto proprio
([ADR-0010](adr/0010-regole-di-indipendenza-tra-i-livelli.md)) e devono dare, per ogni
posizione, lo stesso punteggio intero (INV-C1). Per questo ogni termine è scritto come formula
intera esatta: quali pezzi e quali case contano, come si definisce un attacco, come si
arrotonda.

- Le formule sono normative. Le tabelle di questo documento sono generate dalle formule e
  servono a controllarle: non sono una seconda definizione.
- I valori non sono tarati dal repository: nessun peso vi è stimato su dati, scelto con una
  misura registrata o validato da un esperimento. La taratura è della
  [Fase 10](roadmap.md#fase-10). Ognuno ha accanto una regola semplice. Dove la regola fissa il
  numero, il numero si ricalcola dalla regola; dove ne fissa solo l'ordine di grandezza e il
  verso, il numero è una scelta dentro la regola, dichiarata come tale. I sei pesi della
  struttura pedonale li fissa la regola della [sezione](#struttura-pedonale), scritta per
  decisione dell'autore su [QA-18](limiti-e-rischi.md#qa-18): sostituiscono i sei pesi della
  prima stesura, che la regola di allora non fissava e cinque dei quali erano costanti di
  Fruit 2.1 ([ADR-0013](adr/0013-interpretazione-operativa-dell-originalita.md), punto 5).
  Alcuni numeri e alcune definizioni coincidono con quelli di engine pubblicati: sono elencati
  in [Provenienza](#provenienza).
- Nulla di questo documento dice che la valutazione giochi bene: non è stata giocata nessuna
  partita.

## Notazione

**Case.** Una casa è `s = 8·r + f`, con colonna `f` (0 = a, …, 7 = h) e traversa `r`
(0 = prima, …, 7 = ottava), come nel `core` (a1 = 0, h8 = 63).

**Colori.** `W` (Bianco) e `B` (Nero); `¬c` è l'altro colore. Il segno di un colore è
`σ(W) = +1`, `σ(B) = −1`.

**Traversa relativa.** `rr(c, s) = r` per il Bianco e `7 − r` per il Nero: la traversa vista
da chi possiede il pezzo (0 = la propria prima traversa). La **casa relativa** è `s` per il
Bianco e `s XOR 56` per il Nero (la stessa colonna, traversa riflessa).

**Distanza dal centro.** Per una coordinata `x` da 0 a 7, `dc(x) = max(3 − x, x − 4)`: vale
3, 2, 1, 0, 0, 1, 2, 3 per x = 0…7. La **centralità** di una casa è

```
cent(s) = 3 − dc(f) − dc(r)
```

con valori da −3 (gli angoli) a +3 (d4, e4, d5, e5). La sua somma sulle 64 case è 0, e non
cambia riflettendo la scacchiera in verticale o in orizzontale.

**Numeri triangolari.** `T(n) = n·(n + 1)/2`.

**Valori dei pezzi.** `V(pedone) = 100`, `V(cavallo) = 300`, `V(alfiere) = 300`,
`V(torre) = 500`, `V(donna) = 900`, `V(re) = 0`, in centipawn: i valori convenzionali che il
riferimento usa già (`material-value`, `src/reference/eval.lisp`). Si tengono: sono i valori
didattici comuni della letteratura scacchistica, non il prodotto della taratura di un engine.

**Insiemi.** `|X|` è il numero di elementi di `X`. `Occ(c)` sono le case occupate dai pezzi di
`c` (re compreso), `Occ` l'unione dei due colori.

### Attacchi

L'**insieme d'attacco** `A(p)` di un pezzo `p` di colore `c` sulla casa `s` è:

| Pezzo | `A(p)` |
|---|---|
| pedone | le case in colonna `f − 1` e `f + 1` sulla traversa `r + 1` (Bianco) o `r − 1` (Nero), se stanno sulla scacchiera, qualunque cosa le occupi. Le spinte non sono attacchi; l'en passant non entra. |
| cavallo | le case raggiunte dai salti del cavallo che stanno sulla scacchiera |
| re | le case adiacenti che stanno sulla scacchiera |
| alfiere | sulle quattro diagonali, le case fino alla prima occupata compresa, di qualunque colore |
| torre | sulle quattro direzioni ortogonali, le case fino alla prima occupata compresa |
| donna | l'unione degli insiemi di alfiere e torre dalla stessa casa |

L'occupazione è quella di tutti i pezzi dei due colori, re compresi. Le inchiodature, lo scacco,
il lato al tratto e la legalità non contano: un attacco è un attacco, come in
`square-attacked-p` del riferimento. Nessun attacco ai raggi X: un pezzo dietro un altro sulla
stessa linea è fermato. Da questi insiemi:

- `Att(c)`: l'unione degli `A(p)` dei pezzi di `c`, re e pedoni compresi;
- `PAtt(c)`: l'unione degli `A(p)` dei soli pedoni di `c`.

Una casa è **difesa** da `c` se sta in `Att(c)`.

### Divisioni

Nelle formule che si calcolano su una posizione ogni divisione è esatta (il dividendo è
multiplo del divisore), tranne una: la miscela fra mediogioco e finale. Lì si usa `tr(x / d)`,
il quoziente **troncato verso zero** (`truncate` di Common Lisp), per la ragione detta in
[Miscela e arrotondamento](#miscela-e-arrotondamento). Né `floor` né uno spostamento aritmetico
(`ash`) danno lo stesso risultato sui negativi. I `floor` e i `round` della tabella della
mobilità derivano costanti, una volta, in questo documento: non si calcolano su una posizione.

## Struttura del punteggio

Ogni termine `X` dà, per ciascun colore `c`, due interi: `X_mg(c)` per il mediogioco e
`X_eg(c)` per il finale. Il contributo dal punto di vista del Bianco è

```
X_mg = X_mg(W) − X_mg(B)        X_eg = X_eg(W) − X_eg(B)
```

e i due punteggi parziali sono le somme sui nove termini:

```
MG = Σ X_mg        EG = Σ X_eg
```

### Fase della partita

La fase misura quanto materiale non di pedone resta sulla scacchiera, in unità di pedone:

```
fase_grezza = Σ sui cavalli, alfieri, torri e donne dei due colori di w(t)
w(cavallo) = 3   w(alfiere) = 3   w(torre) = 5   w(donna) = 9
fase = min(fase_grezza, 62)
```

I pesi sono i valori dei pezzi divisi per 100; pedoni e re pesano 0. Nella posizione iniziale
`fase_grezza = 2·(3 + 3 + 3 + 3 + 5 + 5 + 9) = 62`: fase 62 è il pieno mediogioco, fase 0 un
finale di soli re e pedoni. Con le promozioni `fase_grezza` può superare 62, e la fase si ferma
lì. La fase conta i pezzi dei due colori allo stesso modo, quindi non cambia scambiando i colori.

### Miscela e arrotondamento

```
E_W = tr((MG · fase + EG · (62 − fase)) / 62)
E_W = max(−20000, min(20000, E_W))
```

`E_W` è il punteggio dal punto di vista del Bianco. La seconda riga è il limite di
[INV-C9](#limite-del-punteggio).

**Perché il troncamento verso zero.** Lo scambio dei colori deve negare `E_W` (INV-C7). I
termini lo fanno per costruzione, quindi il numeratore `x = MG · fase + EG · (62 − fase)` della
posizione riflessa è `−x`. Il troncamento è una funzione dispari, `tr(−x / d) = −tr(x / d)`, e
conserva la negazione. Il quoziente per difetto (`floor`) no: `floor(−x / d) = −floor(x / d) − 1`
ogni volta che `d` non divide `x`. Esempio, il pedone e4 contro il cavallo d5,
`4k3/8/8/3n4/4P3/8/8/4K3 w - - 0 1`, uno dei casi calcolati a mano in `tests/test-evaluation.lisp`
(fase 3): `x = −11741`, `tr(−11741 / 62) = −189` e `tr(11741 / 62) = 189`, mentre
`floor(−11741 / 62) = −190` e `floor(11741 / 62) = 189`: con `floor`, dal punto di vista del
Bianco, la posizione varrebbe −190 e la sua riflessa +189, invece di −189 e +189. Anche il limite è dispari:
è simmetrico intorno a 0.

### Punto di vista

La funzione di valutazione restituisce il punteggio dal punto di vista di chi muove, come
`evaluate-material` del riferimento e come negamax richiede:

```
E = E_W   se muove il Bianco
E = −E_W  se muove il Nero
```

Ordine dei passi, uguale nei due livelli: i termini per colore, poi `MG` ed `EG`, la fase, la
miscela con il troncamento, il limite, il punto di vista.

## Termini

Nell'ordine della specifica. Ogni termine è `[HEURISTIC]`, non tarato dal repository
([classificazione](#classificazione)). Per ognuno: che cosa conta, la formula per un colore `c`,
e la regola dei suoi numeri.

### Materiale

```
Mat_mg(c) = Mat_eg(c) = Σ sui pezzi di c di V(t)
```

Il re vale 0. Uguale nelle due fasi: la miscela lo lascia intatto, perché
`(M · fase + M · (62 − fase)) / 62 = M`.

### Piece-square tables

```
PST_mg(c) = Σ sui pezzi p di c di pst_mg(t, s')      PST_eg(c) = Σ … di pst_eg(t, s')
```

dove `s'` è la casa relativa del pezzo, con colonna `f` e traversa relativa `rr`, e `pst` è
data da queste formule:

| Pezzo | `pst_mg` | `pst_eg` | Regola |
|---|---|---|---|
| pedone | `3 · (rr − 1) · (3 − dc(f))` | `6 · (rr − 1)` | avanzare vale; in mediogioco vale di più sulle colonne centrali, che prendono spazio, e niente sulle colonne a e h, i cui pedoni riparano il re; in finale ogni traversa vale lo stesso su ogni colonna |
| cavallo | `8 · cent(s')` | `8 · cent(s')` | il pezzo a corto raggio dipende più di tutti dalla sua casa |
| alfiere | `4 · cent(s')` | `4 · cent(s')` | a lungo raggio, dipende meno dal centro |
| torre | `20` se `rr = 6`, altrimenti `0` | come in mediogioco | agisce su linee intere, quindi nessuna preferenza per il centro; sulla settima traversa relativa attacca i pedoni avversari dalla loro casa di partenza |
| donna | `2 · cent(s')` | `4 · cent(s')` | poca preferenza per il centro in mediogioco, di più in finale |
| re | `6 · (min(dc(f), 2) − 1) − 10 · rr` | `8 · cent(s')` | in mediogioco il re sta sulla propria prima traversa e sulle colonne laterali (a, b, g, h); in finale è un pezzo attivo e va al centro |

Le formule del pedone valgono per `rr` da 1 a 6; sulle traverse relative 0 e 7 la tavola vale
0, e nessun pedone vi sta in una posizione che il riferimento accetta (il lettore FEN rifiuta un
pedone sulla prima o sull'ultima traversa). `cent(s')` vale quanto `cent(s)`, perché la
centralità non cambia riflettendo la scacchiera.

Le tavole generate, dal punto di vista del Bianco (l'ottava traversa in alto). Per il Nero si
legge la casa relativa: un pedone nero in e7 vale quanto uno bianco in e2.

`cent(s)`, da cui vengono cavallo (×8), alfiere (×4), donna (×2 in mediogioco, ×4 in finale) e
re in finale (×8):

| | a | b | c | d | e | f | g | h |
|---|---:|---:|---:|---:|---:|---:|---:|---:|
| **8** | −3 | −2 | −1 | 0 | 0 | −1 | −2 | −3 |
| **7** | −2 | −1 | 0 | 1 | 1 | 0 | −1 | −2 |
| **6** | −1 | 0 | 1 | 2 | 2 | 1 | 0 | −1 |
| **5** | 0 | 1 | 2 | 3 | 3 | 2 | 1 | 0 |
| **4** | 0 | 1 | 2 | 3 | 3 | 2 | 1 | 0 |
| **3** | −1 | 0 | 1 | 2 | 2 | 1 | 0 | −1 |
| **2** | −2 | −1 | 0 | 1 | 1 | 0 | −1 | −2 |
| **1** | −3 | −2 | −1 | 0 | 0 | −1 | −2 | −3 |

Pedone, mediogioco:

| | a | b | c | d | e | f | g | h |
|---|---:|---:|---:|---:|---:|---:|---:|---:|
| **8** | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 |
| **7** | 0 | 15 | 30 | 45 | 45 | 30 | 15 | 0 |
| **6** | 0 | 12 | 24 | 36 | 36 | 24 | 12 | 0 |
| **5** | 0 | 9 | 18 | 27 | 27 | 18 | 9 | 0 |
| **4** | 0 | 6 | 12 | 18 | 18 | 12 | 6 | 0 |
| **3** | 0 | 3 | 6 | 9 | 9 | 6 | 3 | 0 |
| **2** | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 |
| **1** | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 |

Pedone, finale: 0, 6, 12, 18, 24, 30 sulle traverse dalla 2 alla 7, su ogni colonna; 0 sulle
traverse 1 e 8.

Re, mediogioco:

| | a | b | c | d | e | f | g | h |
|---|---:|---:|---:|---:|---:|---:|---:|---:|
| **8** | −64 | −64 | −70 | −76 | −76 | −70 | −64 | −64 |
| **7** | −54 | −54 | −60 | −66 | −66 | −60 | −54 | −54 |
| **6** | −44 | −44 | −50 | −56 | −56 | −50 | −44 | −44 |
| **5** | −34 | −34 | −40 | −46 | −46 | −40 | −34 | −34 |
| **4** | −24 | −24 | −30 | −36 | −36 | −30 | −24 | −24 |
| **3** | −14 | −14 | −20 | −26 | −26 | −20 | −14 | −14 |
| **2** | −4 | −4 | −10 | −16 | −16 | −10 | −4 | −4 |
| **1** | 6 | 6 | 0 | −6 | −6 | 0 | 6 | 6 |

Torre: 20 su tutta la settima traversa, 0 altrove, nelle due fasi.

Materiale e piece-square tables sono i due termini che il livello ottimizzato tiene
incrementali ([Stato incrementale](#stato-incrementale)).

### Mobilità

Per ogni cavallo, alfiere, torre e donna `p` di `c`:

```
area(c) = tutte le case − Occ(c) − PAtt(¬c)
m(p)    = |A(p) ∩ area(c)|
Mob_mg(c) = Σ_p wm_mg(t) · (m(p) − base(t))      Mob_eg(c) = Σ_p wm_eg(t) · (m(p) − base(t))
```

Le case dell'area sono quelle non occupate da un pezzo proprio e non attaccate da un pedone
avversario; una casa con un pezzo avversario conta. Pedoni e re non hanno mobilità.

| Pezzo | massimo su scacchiera vuota `M` | `base = floor(M / 2)` | `wm_mg = round(30 / M)` | `wm_eg = round(40 / M)` |
|---|---:|---:|---:|---:|
| cavallo | 8 | 4 | 4 | 5 |
| alfiere | 13 | 6 | 2 | 3 |
| torre | 14 | 7 | 2 | 3 |
| donna | 27 | 13 | 1 | 1 |

Regola: un pezzo con metà della sua mobilità massima vale 0, e il peso di una casa è inverso al
numero di case che il pezzo può raggiungere: `round(30 / M)` in mediogioco e `round(40 / M)` in
finale, così che passare da nessuna casa al massimo valga circa 30 e 40 centipawn. Poiché il peso
è un intero, l'escursione intera `wm · M` vale da 26 (alfiere) a 32 (cavallo) in mediogioco e da
27 (donna) a 42 (torre) in finale: la donna, con 27 case e peso 1, resta a 27 anche in finale,
un terzo sotto i 40 della regola. `round` arrotonda al più vicino; nessuno dei quattro quozienti
cade a metà fra due interi.

### Sicurezza del re

Due parti, solo nel mediogioco: `KS_mg(c) = −(attacco(c) + riparo(c))`, `KS_eg(c) = 0`. La
miscela le spegne man mano che i pezzi lasciano la scacchiera.

**Attacco.** Sia `K` la casa del re di `c` e `Z(c) = {K} ∪ A(re di c)` la sua zona (da 4 a 9
case). Per ogni cavallo, alfiere, torre e donna `q` di `¬c`, sia `k(q) = |A(q) ∩ Z(c)|`.

```
n = numero dei pezzi q con k(q) > 0
U = Σ_q u(t) · k(q)          u(cavallo) = 2, u(alfiere) = 2, u(torre) = 3, u(donna) = 5
attacco(c) = min(4 · U · max(n − 1, 0), 400)
```

Regola: le unità sono il valore del pezzo diviso per 200 e arrotondato per eccesso; un pezzo da
solo non è un attacco (`n − 1`); il pericolo cresce con il peso dell'attacco e con il numero di
pezzi che vi prendono parte, fino a un tetto di quattro pedoni. Pedoni e re avversari non
contano come attaccanti.

**Riparo.** Sia `fK` la colonna del re e `rK` la sua traversa relativa. Per ogni colonna `x` fra
`fK − 1`, `fK` e `fK + 1` che sta sulla scacchiera, si considerano i pedoni di `c` sulla colonna
`x` con traversa relativa maggiore di `rK`:

```
d(x) = 3                                         se non ce n'è nessuno
d(x) = min(3, min_{pedoni} (rr(pedone) − rK − 1))  altrimenti
riparo(c) = 10 · Σ_x d(x)
```

Regola: il pedone più vicino davanti al re, sulla sua colonna e su quelle accanto, ripara il re;
ogni traversa di distanza costa 10, fino a 30 per una colonna senza riparo. La definizione ha due
proprietà che la regola non dice da sola, e che restano finché l'autore non decide altrimenti
([ADR-0018](adr/0018-definizione-della-valutazione-classica.md), Alternative considerate):

- *Un pedone sulla traversa del re non ripara.* Contano solo i pedoni davanti al re. Con i
  pedoni in f2, g3 e h2, il re in g1 ha `Σ d(x) = 0 + 1 + 0`, riparo 10; il re in g2 ha
  `3 + 0 + 3`, riparo 60, perché f2 e h2 gli stanno accanto e non davanti. Un passo del re di
  fianco ai propri pedoni costa quindi fino a mezzo pedone.
- *Un re sulla colonna a o h ha due colonne, non tre.* Il riparo massimo è 60 invece di 90: senza
  pedoni davanti, il re in h1 paga 30 meno del re in g1.

### Struttura pedonale

Tre debolezze, ciascuna contata per pedone di `c` (con colonna `f` e traversa relativa `rr`) e
sottratta:

| Debolezza | Definizione esatta | mg | eg |
|---|---|---:|---:|
| pedone doppiato | per ogni colonna con `k ≥ 2` pedoni di `c`: `k − 1` volte | 6 | 9 |
| pedone isolato | nessun pedone di `c` sulle colonne `f − 1` e `f + 1` | 12 | 18 |
| pedone arretrato | non isolato; ogni pedone di `c` sulle colonne `f − 1` e `f + 1` ha traversa relativa maggiore di `rr`; la casa davanti al pedone (colonna `f`, traversa relativa `rr + 1`) sta in `PAtt(¬c)` | 6 | 9 |

```
PS_mg(c) = −(6 · doppiati + 12 · isolati + 6 · arretrati)
PS_eg(c) = −(9 · doppiati + 18 · isolati + 9 · arretrati)
```

Un pedone isolato non è arretrato (la definizione lo esclude); un pedone doppiato può essere
anche isolato o arretrato, e paga entrambe le penalità.

**Regola dei pesi.** Una debolezza costa un'unità per ogni sostegno che manca al pedone. Il
doppiato ne perde uno (il pedone dietro non può avanzare né sostenere il compagno della stessa
colonna), l'arretrato uno (i pedoni vicini, tutti davanti, non possono più sostenerlo
avanzando), l'isolato due (nessun pedone sulle due colonne vicine). L'unità è un sedicesimo di
pedone in mediogioco, `floor(100 / 16) = 6`, e una volta e mezza tanto in finale, dove un pedone
debole diventa un bersaglio: `floor(3 · 100 / 32) = 9`. Da qui i sei pesi: doppiato e arretrato
6 / 9, isolato 12 / 18. La regola li fissa tutti, e si ricalcolano da essa.

> **Deciso (QA-18 → ADR-0018)** — Questa regola sostituisce i pesi della prima stesura
> (doppiato 10 / 20, isolato 10 / 15, arretrato 8 / 10), che la regola di allora («circa un
> decimo di pedone, di più in finale») non fissava e cinque dei quali erano costanti di Fruit 2.1
> negli stessi ruoli. Nessuno dei sei pesi nuovi è uguale a quello di Fruit 2.1 nello stesso
> ruolo, come la [Provenienza](#provenienza) li riporta. Il confronto con altri engine non è
> stato rifatto per i valori nuovi: sono piccoli interi, e una coincidenza con un engine non
> confrontato resta possibile. La definizione di pedone arretrato non cambia: è un'idea, che
> [ADR-0013](adr/0013-interpretazione-operativa-dell-originalita.md) (punto 1) ammette.

La definizione di pedone arretrato è questa e nessun'altra: un pedone che i pedoni vicini non
possono più sostenere avanzando (sono tutti davanti a lui) e la cui casa d'avanzata è controllata
da un pedone avversario. Che la casa davanti sia libera non conta.

### Pedoni passati

Un pedone di `c` sulla colonna `f` con traversa relativa `rr` è **passato** se:

- nessun pedone di `¬c` sta sulle colonne `f − 1`, `f`, `f + 1` con traversa relativa (vista da
  `c`) maggiore di `rr`;
- nessun pedone di `c` sta sulla colonna `f` con traversa relativa maggiore di `rr`.

La seconda condizione conta un solo pedone passato per colonna, quello più avanzato.

```
Pass_mg(c) = Σ sui pedoni passati di c di 5 · T(rr − 1)
Pass_eg(c) = Σ … di 10 · T(rr − 1)
```

| Traversa relativa `rr` (traversa del Bianco) | 1 (2ª) | 2 (3ª) | 3 (4ª) | 4 (5ª) | 5 (6ª) | 6 (7ª) |
|---|---:|---:|---:|---:|---:|---:|
| mg | 0 | 5 | 15 | 30 | 50 | 75 |
| eg | 0 | 10 | 30 | 60 | 100 | 150 |

Regola: ogni passo verso la promozione vale più del precedente (il numero triangolare dei passi
fatti dalla casa di partenza), e in finale il doppio che in mediogioco. Non si guardano né i re
né i pezzi davanti al pedone.

### Spazio

```
S(c) = case con colonna 2 ≤ f ≤ 5 (dalla c alla f) e traversa relativa 1 ≤ rr ≤ 3 (12 case)
Spazio_mg(c) = 2 · |S(c) − pedoni di c − PAtt(¬c)|
Spazio_eg(c) = 0
```

Regola: lo spazio è il numero delle case centrali della propria metà (dalla seconda alla
quarta traversa relativa) che non sono occupate da un pedone proprio e che il nemico non
controlla con un pedone; conta solo in mediogioco. Una casa con un pezzo proprio che non è un
pedone conta; dove stanno gli altri pedoni non conta. L'insieme di case è quello del termine di
spazio della valutazione classica di Stockfish; qui senza le sue aggiunte, e con un peso proprio
([Provenienza](#provenienza)).

### Iniziativa

```
Ini_mg(c) = Ini_eg(c) = 10   se c è il lato al tratto, altrimenti 0
```

La specifica nomina l'iniziativa senza definirla. Qui è il valore del tratto: chi muove vale un
decimo di pedone in più. È una lettura, non l'unica: nella programmazione degli scacchi la parola
indica anche altro, per esempio il termine «initiative» della valutazione classica di Stockfish,
una correzione del punteggio che dipende dalla struttura della posizione (pedoni passati, pedoni
sulle due ali, posizione dei re). Le letture considerate sono in
[ADR-0018](adr/0018-definizione-della-valutazione-classica.md) (Alternative considerate), e la
scelta è dell'autore, con l'accettazione di quell'ADR. È l'unico termine che dipende dal lato al
tratto; scambiando i colori, il tratto passa all'altro lato e il termine si nega con gli altri.

### Minacce

Per ogni pezzo `q` di `¬c` che non è il re, sulla casa `s`, con valore `v = V(q)`:

- sia `a` il valore minimo fra i pezzi di `c` che non sono il re e che hanno `s` nel proprio
  insieme d'attacco (indefinito se non ce n'è);
- `r1 = (v − a) / 10` se `a` è definito e `a < v`, altrimenti 0;
- `r2 = v / 20` se `s ∈ Att(c)` e `s ∉ Att(¬c)` (attaccato e non difeso), altrimenti 0.

```
Min_mg(c) = Min_eg(c) = Σ_q max(r1, r2)
```

| Minaccia | `r1` | Pezzo indifeso | `r2` |
|---|---:|---|---:|
| pedone su cavallo o alfiere | 20 | pedone | 5 |
| pedone su torre | 40 | cavallo o alfiere | 15 |
| pedone su donna | 80 | torre | 25 |
| cavallo o alfiere su torre | 20 | donna | 45 |
| cavallo o alfiere su donna | 60 | | |
| torre su donna | 40 | | |

Regola: un attacco di un pezzo di valore minore vale un decimo del materiale che la cattura
guadagnerebbe anche se il pezzo che cattura fosse ripreso; un pezzo attaccato e non difeso vale
un ventesimo del suo valore; dei due si prende il maggiore. Le divisioni sono esatte, perché i
valori sono multipli di 100. Il re conta come difensore e come attaccante per `r2`, non per `r1`;
il re come bersaglio non conta (lo scacco non è una minaccia di questo termine). Cavallo e
alfiere valgono lo stesso: l'uno non minaccia l'altro secondo `r1`.

## Riepilogo dei parametri

> **Deciso (autore → ADR-0018)** — I nomi in inglese sono quelli del codice; i valori sono questi.

| Parametro | Nome | Valore |
|---|---|---|
| valori dei pezzi P, N, B, R, Q, K | `piece-value` | 100, 300, 300, 500, 900, 0 |
| pesi di fase N, B, R, Q | `phase-weight` | 3, 3, 5, 9 |
| fase massima | `phase-max` | 62 |
| PST pedone, mg, per traversa e per colonna centrale | `pawn-advance-mg` | 3 |
| PST pedone, eg, per traversa | `pawn-advance-eg` | 6 |
| PST centralità mg / eg: cavallo, alfiere, donna | `centre-weight` | 8 / 8, 4 / 4, 2 / 4 |
| PST torre sulla settima, mg / eg | `rook-seventh` | 20 / 20 |
| PST re mg: colonna laterale, per traversa | `king-flank`, `king-rank` | 6, 10 |
| PST re eg: centralità | `king-centre-eg` | 8 |
| mobilità: base N, B, R, Q | `mobility-base` | 4, 6, 7, 13 |
| mobilità: peso mg N, B, R, Q | `mobility-mg` | 4, 2, 2, 1 |
| mobilità: peso eg N, B, R, Q | `mobility-eg` | 5, 3, 3, 1 |
| unità d'attacco al re N, B, R, Q | `king-attack-unit` | 2, 2, 3, 5 |
| scala e tetto dell'attacco al re | `king-attack-scale`, `king-attack-cap` | 4, 400 |
| riparo: costo per traversa, distanza massima | `shelter-step`, `shelter-max` | 10, 3 |
| doppiato mg / eg | `doubled-pawn` | 6 / 9 |
| isolato mg / eg | `isolated-pawn` | 12 / 18 |
| arretrato mg / eg | `backward-pawn` | 6 / 9 |
| passato mg / eg, per numero triangolare | `passed-pawn` | 5 / 10 |
| spazio mg, per casa | `space-square` | 2 |
| iniziativa mg / eg | `tempo` | 10 / 10 |
| minacce: divisore di `r1`, divisore di `r2` | `threat-gain-divisor`, `threat-hanging-divisor` | 10, 20 |
| limite del punteggio | `evaluation-limit` | 20000 |

## Provenienza

> **Deciso (autore → ADR-0018)** — Le coincidenze note fra questa definizione e engine pubblicati, perché
> [ADR-0013](adr/0013-interpretazione-operativa-dell-originalita.md) ammette le idee (punto 1),
> non le tabelle di costanti di altri engine (punto 2), e chiede di portare all'autore un caso
> dubbio (punto 5).

Le definizioni e i numeri di questo documento sono stati confrontati, in revisione, con il
sorgente pubblicato di due engine: Fruit 2.1, di Fabien Letouzey, distribuito con la GPL (file
`src/pawn.cpp`, `src/eval.cpp` e `src/pst.cpp`, letti da una copia pubblica, il repository
GitHub `Warpten/Fruit-2.1`), e la valutazione classica di Stockfish 11, distribuito con la GPL
versione 3 (file `src/evaluate.cpp` del tag `sf_11` di `official-stockfish/Stockfish`). Nessun
codice è stato preso da quei file. Il confronto non copre altri engine: l'elenco dice ciò che si
sa, non che il resto sia senza precedenti.

| Termine | Che cosa coincide | Che cosa differisce |
|---|---|---|
| struttura pedonale | il nucleo della definizione di pedone arretrato (nessun pedone proprio sulle colonne vicine alla stessa traversa o dietro) è il test di Fruit 2.1. Nella prima stesura cinque pesi su sei erano uguali ai suoi negli stessi ruoli (doppiato 10 / 20, isolato 10 in mediogioco, arretrato 8 / 10; l'isolato in finale vi vale 20): li ha sostituiti la regola della [sezione](#struttura-pedonale), per decisione dell'autore ([QA-18](limiti-e-rischi.md#qa-18)) | i pesi attuali (6 / 9, 12 / 18, 6 / 9), fissati da quella regola; Fruit ha anche pesi maggiori per i pedoni deboli su colonna aperta e altre condizioni per l'arretrato, che qui non ci sono |
| mobilità | sottrarre una base dal numero di case prima di moltiplicare per il peso è il modo di Fruit 2.1; `floor(M / 2)` dà esattamente le sue basi 4, 6, 7 e 13; tre degli otto pesi (mediogioco: cavallo 4, torre 2, donna 1) sono uguali ai suoi | gli altri cinque pesi. Le basi e i pesi seguono dalla regola scritta qui |
| torre sulla settima | 20 in mediogioco, come in Fruit 2.1 | qui è una voce delle piece-square tables, senza condizioni e uguale nelle due fasi; in Fruit vale 40 in finale e dipende dai pedoni e dal re avversari |
| piece-square tables | generare le tavole da formule per colonna, traversa e centro, moltiplicate per un peso, è anche il modo di Fruit 2.1; due coefficienti sono uguali ai suoi: 4 per unità di centralità della donna in finale e 10 per traversa del re in mediogioco | le forme (`cent` e `dc` qui, tavole per colonna e per traversa di sette valori in Fruit) e gli altri coefficienti |
| sicurezza del re | l'idea che un pezzo da solo non sia un attacco: in Fruit 2.1 il peso dell'attacco vale 0 con un attaccante | le unità dei pezzi, la scala, il tetto, il riparo |
| spazio | l'insieme di case (colonne dalla c alla f, traverse relative dalla seconda alla quarta) e le case tolte (pedoni propri, case attaccate da pedoni avversari) sono quelli del termine di spazio di Stockfish 11 | Stockfish conta di più le case dietro i propri pedoni e pesa il termine con il numero dei pezzi; qui c'è solo il peso 2 per casa, del progetto |

Le idee (una base per la mobilità, le tavole da formule, l'attacco che richiede due pezzi,
l'insieme di case dello spazio) sono conoscenza pubblica, ammessa da ADR-0013 (punto 1). Per i
numeri il caso cambia da termine a termine. Le basi e i pesi della mobilità seguono dalla regola
scritta qui, che li ricalcola. I due coefficienti uguali delle piece-square tables sono numeri
singoli in tavole di forma diversa da quelle di Fruit, e la torre sulla settima è una voce
sola. I pesi della struttura pedonale erano il caso dubbio: sei numeri che la regola non
fissava, cinque dei quali uguali a una tabella di Fruit negli stessi ruoli. L'autore ha deciso di
sostituirli ([QA-18](limiti-e-rischi.md#qa-18)), e ora li fissa una regola. Le altre coincidenze
di questo elenco restano come sono: l'autore non ha chiesto di rivederle.

## Simmetria dei colori

**Lo scambio dei colori** `m(p)` di una posizione `p` mette ogni pezzo di colore `c` e tipo `t`
dalla casa `s` alla casa `s XOR 56` con colore `¬c` e lo stesso tipo; scambia il lato al tratto;
scambia i diritti di arrocco (K con k, Q con q); riflette la casa en passant (`s XOR 56`); lascia
gli orologi. È la trasformazione di `mirror-fen` nei test (`tests/test-perft.lisp`).

**INV-C7.** Per ogni posizione `p`: `E_W(m(p)) = −E_W(p)`, e quindi `E(m(p)) = E(p)`: la
valutazione vista da chi muove non cambia scambiando i colori.

La simmetria vale per costruzione, se ogni termine rispetta queste regole:

1. Il termine è `X(W) − X(B)`, dove `X(c)` è calcolato con la stessa formula per i due colori,
   in coordinate relative a `c`: traverse relative, case relative, direzione dei pedoni di `c`.
2. La geometria degli attacchi di cavallo, re, alfiere, torre e donna non cambia riflettendo la
   scacchiera in verticale; quella del pedone è relativa al suo colore.
3. Ogni termine è una somma, un conteggio, un minimo o un massimo su insiemi: nessun risultato
   dipende dall'ordine in cui si visitano le case (per esempio «il primo pedone trovato da a1»).
4. La fase conta i due colori allo stesso modo.
5. La miscela è lineare in `MG` ed `EG` e poi troncata verso zero, e il limite è simmetrico:
   entrambi sono funzioni dispari.
6. L'iniziativa dipende dal lato al tratto, che lo scambio inverte.

Allora `X(c)` calcolato su `m(p)` vale quanto `X(¬c)` su `p`, ogni termine si nega, `MG` ed `EG`
si negano, la fase resta, e `E_W` si nega. Un termine nuovo che non rispetta le sei regole va
scritto finché non le rispetta: la simmetria non si ripara dopo.

La definizione attuale è anche simmetrica fra le colonne: riflettendo la scacchiera in
orizzontale (a con h), senza cambiare colori né tratto, `E_W` non cambia, perché le formule usano
le colonne solo attraverso `dc(f)` e le colonne vicine. È una proprietà della definizione di oggi,
non un invariante: un termine futuro, per esempio legato all'arrocco, può non averla. Finché
vale, è un controllo in più che costa poco ([Verifica](#verifica)).

## Stato incrementale

**Livello ottimizzato.** Tiene tre interi aggiornati da make e unmake:

```
psq_mg     = Σ sui pezzi di σ(c) · (V(t) + pst_mg(t, s'))
psq_eg     = Σ sui pezzi di σ(c) · (V(t) + pst_eg(t, s'))
fase_grezza (senza il minimo con 62)
```

cioè la somma `Mat + PST` dal punto di vista del Bianco, nelle due fasi, e la fase prima del
tetto. make sottrae il contributo di ogni pezzo che lascia una casa e aggiunge quello di ogni
pezzo che vi arriva: il pezzo che si muove, il pezzo catturato (per l'en passant sulla sua casa,
non sulla casa d'arrivo), il pedone che promuove e il pezzo che nasce, la torre dell'arrocco;
`fase_grezza` cambia solo con una cattura di un pezzo che non è pedone e con una promozione.
unmake riporta i tre valori a quelli di prima, dallo stack di undo o con l'aggiornamento
inverso: il modo è libero, il risultato no.

**INV-C8.** Dopo ogni make e ogni unmake, `psq_mg`, `psq_eg` e `fase_grezza` sono uguali a quelli
calcolati da zero sulla stessa posizione (è un caso di INV-C3); dopo l'unmake sono quelli di
prima della mossa (INV-C2). La conversione dal riferimento li calcola da zero nel livello
ottimizzato, non li copia ([ADR-0010](adr/0010-regole-di-indipendenza-tra-i-livelli.md),
punto 4), e il controllo di coerenza della posizione li ricalcola.

Lo stato incrementale è un calcolo incrementale `[EXACT]`: dà le stesse uscite del calcolo da
zero, e lo si tiene per risparmiare tempo. Per
[ADR-0017](adr/0017-percorso-di-ricerca-per-le-alternative-exact.md) serve quindi, oltre
all'equivalenza, una misura con una regola di decisione, e
[architettura](architettura.md#deduplicazione) chiede il costo dell'aggiornamento contro il
ricalcolo. L'equivalenza c'è (INV-C8, [Verifica](#verifica)), e c'è la misura: `make bench` confronta la
ricerca e il perft con e senza lo stato (`SCF_EVAL_STATE`), e con la regola di decisione di
[EXP-0002](../research/exp-0002-stato-incrementale-della-valutazione.md) la variante con lo stato è più rapida
nella ricerca, su una macchina; il record è chiuso, Accettato.

Gli altri termini (mobilità, sicurezza del re, struttura pedonale, pedoni passati, spazio,
iniziativa, minacce) si calcolano a ogni valutazione. Una cache della struttura pedonale,
indicizzata dalla disposizione dei pedoni, sarebbe deduplicazione: entra solo con la misura che
la regola della specifica chiede ([architettura](architettura.md#deduplicazione)).

**Riferimento.** Calcola tutto da zero, a ogni chiamata, camminando sulla scacchiera con le
proprie tavole. Non ha stato incrementale della valutazione.

## Limite del punteggio

**INV-C9.** Per ogni posizione `|E_W| ≤ 20000`. Le soglie della ricerca del riferimento sono
`+mate-bound+ = 29000` e `+mate-score+ = 30000`: nessuna valutazione statica è letta come
punteggio di matto.

Il limite serve per le posizioni che una partita non può produrre: il lettore FEN non limita il
numero dei pezzi, e 60 donne superano da sole il punteggio di matto. Per il materiale che può
nascere in una partita (per lato un re, al più 15 altri pezzi, e non più donne, torri, alfieri e
cavalli di quelli iniziali più i pedoni promossi, come in
[ADR-0015](adr/0015-generatore-di-mosse-del-livello-ottimizzato.md), punto 6) il limite non
agisce. Il materiale di un lato con `p` pedoni è al più `100·p + 3100 + 900·(8 − p) ≤ 10300`.
Ogni termine per un lato sta in un intervallo `[min, max]`, e la differenza fra i due lati sta
fra `−(max − min)` e `max − min`. Un limite largo, non stretto:

| Termine | ampiezza mg | ampiezza eg | da dove |
|---|---:|---:|---|
| materiale | 10300 | 10300 | nove donne, due torri, due alfieri, due cavalli contro nulla |
| PST | 1117 | 858 | ogni pezzo in [−24, 45] mg e [−24, 30] eg, 15 pezzi; il re in [−76, 6] mg e [−24, 24] eg |
| mobilità | 480 | 630 | ogni pezzo in [−16, 16] mg e [−21, 21] eg, 15 pezzi |
| sicurezza del re | 490 | 0 | attacco fino a 400, riparo fino a 90 |
| struttura pedonale | 214 | 340 | 7 doppiati, 8 isolati, 8 arretrati |
| pedoni passati | 600 | 1200 | un passato per colonna sulla settima |
| spazio | 24 | 0 | 12 case |
| iniziativa | 10 | 10 | esattamente ±10 |
| minacce | 1200 | 1200 | 15 pezzi, ciascuno al più 80 |
| **totale** | **14435** | **14538** | |

`E_W` è il troncamento di una media pesata di `MG` ed `EG`, quindi `|E_W| ≤ max(|MG|, |EG|) ≤
14538 < 20000`.

## Convenzioni per la ricerca

Sono quelle della ricerca del riferimento (`src/reference/search.lisp`), che la ricerca del
livello ottimizzato ripete perché i valori a profondità fissa siano uguali (gate della
[Fase 2](roadmap.md#fase-2)).

- **Punto di vista.** Ogni punteggio è dal punto di vista di chi muove; negamax nega a ogni ply.
- **Foglia.** A profondità 0 si restituisce `E` della posizione, senza controllare se è matto o
  stallo. Non c'è quiescenza (Fase 4): un matto si vede solo dove si generano le mosse del lato
  che lo subisce.
- **Matto.** Un nodo a profondità maggiore di 0 senza mosse legali, con il lato al tratto sotto
  scacco, vale `P − 30000`, dove `P` è la distanza in ply dalla radice: la radice vede
  `30000 − N` per un matto in `N` ply. Un punteggio con valore assoluto almeno 29000 è un
  punteggio di matto.
- **Stallo.** Un nodo a profondità maggiore di 0 senza mosse legali e senza scacco vale 0.
- **Patte per regola.** Né la ricerca né la valutazione riconoscono la ripetizione, la regola
  delle cinquanta mosse o il materiale insufficiente: il contatore delle semimosse esiste, ma
  nessuna regola lo usa. Re contro re non vale 0, e non vale sempre lo stesso. La fase è 0 e in
  finale restano solo l'iniziativa e la tabella del re: con il Bianco al tratto
  `E_W = 10 + 8 · (cent(s_W) − cent(s_B))`, con il Nero
  `E_W = −10 + 8 · (cent(s_W) − cent(s_B))`, dove `s_W` e `s_B` sono le case dei due re. Per chi
  muove vale 10 solo quando i due re sono ugualmente centrali (per esempio in e1 ed e8); con il
  re bianco in e1, quello nero in e5 e il Bianco al tratto `E = −14`. Il test
  `bare-kings-score-the-initiative-and-the-endgame-king-table` (`tests/test-evaluation.lisp`) lo
  controlla in ogni disposizione legale dei due re, con ciascun lato al tratto, in entrambi i
  livelli.
- **Solo la posizione (INV-C10).** La valutazione è funzione della sola disposizione dei pezzi e
  del lato al tratto: non dipende dagli orologi, dai diritti di arrocco, dalla casa en passant né
  dalla storia della partita. Due posizioni che differiscono solo in questi campi hanno la stessa
  valutazione, e l'ipotesi TT-2
  ([classificazione](classificazione.md#ipotesi-della-transposition-table)) vale per la
  valutazione statica.
- **Firma di ricerca.** La prima firma
  ([verifica](verifica.md#regressione-di-ricerca)) si registra con questa valutazione. Cambiare un
  peso cambia la funzione cercata: la firma cambia, e la modifica segue la riga «nuova potatura,
  riduzione o estensione» di quella tabella.

## Esempi calcolati

I primi tre sono calcolati a mano da questo testo, termine per termine; gli ultimi due da un
prototipo scritto da questo testo fuori dal repository, che sugli altri dà gli stessi numeri
(della posizione 4 è ricontrollato a mano l'attacco al re).
Servono come valori attesi dei test: se un livello ne dà un altro, la scomposizione per termine
dice dove sta la differenza, nel codice o in questo documento. Le colonne danno `X_mg` e `X_eg`
dal punto di vista del Bianco; i termini nulli non sono elencati.

**Posizione iniziale**, `rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1`. Ogni termine
tranne l'iniziativa è uguale per i due colori (per esempio la mobilità vale −81 in mediogioco per
ciascuno: due cavalli da −8, due alfieri da −12, due torri da −14, la donna −13). `MG = EG = 10`,
fase 62, `E_W = 10`, `E = 10`.

**Re e pedone contro re**, `4k3/8/8/8/8/8/4P3/4K3 w - - 0 1`. Fase 0.

| Termine | mg | eg | come |
|---|---:|---:|---|
| materiale | 100 | 100 | il pedone |
| sicurezza del re | 30 | 0 | riparo, `Σ d(x)`: Bianco 6 (colonne d e f senza pedoni, e2 subito davanti al re), Nero 9 (nessun pedone): −60 contro −90 |
| struttura pedonale | −12 | −18 | e2 isolato |
| spazio | −2 | 0 | Bianco 11 case (e2 è occupata), Nero 12 |
| iniziativa | 10 | 10 | muove il Bianco |
| **totale** | **126** | **92** | |

Il pedone in e2 è passato, ma sulla seconda traversa vale `T(0) = 0`; le PST dei due re (−6 in
mediogioco ciascuno) si annullano. `E_W = tr(92 · 62 / 62) = 92`, `E = 92`. Con il Nero al tratto
(`… b - - 0 1`) l'iniziativa passa al Nero: `EG = 72`, `E_W = 72`, `E = −72`.

**Posizione 3 della tabella di perft**, `8/2p5/3p4/KP5r/1R3p1k/8/4P1P1/8 w - - 0 1`. Fase 10 (due
torri).

| Termine | mg | eg | come |
|---|---:|---:|---|
| PST | −18 | −6 | Bianco: Ka5 −34 / 0, b5 9 / 18; Nero: d6 9 / 6, f4 18 / 18, Kh4 −34 / 0 |
| mobilità | −2 | −3 | Rb4 8 case (2 / 3), Rh5 9 case (4 / 6) |
| struttura pedonale | −18 | −27 | Bianco: b5, e2, g2 isolati; Nero: f4 isolato, c7 arretrato (c6 attaccata da b5) |
| spazio | 2 | 0 | Bianco 10 case (senza e2 ed e3, attaccata da f4), Nero 9 (senza c7, d6 e c6) |
| minacce | 5 | 5 | f4 attaccato da Rb4 e non difeso |
| iniziativa | 10 | 10 | |
| **totale** | **−21** | **−21** | |

Il riparo vale 60 per ciascun re e si annulla; nessun pedone è passato. `x = −21 · 10 − 21 · 52
= −1302`, `E_W = tr(−1302 / 62) = −21`, `E = −21`: il quoziente è esatto.

**Kiwipete**, `r3k2r/p1ppqpb1/bn2pnp1/3PN3/1p2P3/2N2Q1p/PPPBBPPP/R3K2R w KQkq - 0 1`. Fase 62.
PST 64 / 16, mobilità 7 / 8, sicurezza del re −40 / 0, spazio 6 / 0, minacce −5 / −5, iniziativa
10 / 10: `MG = 42`, `EG = 29`, `E_W = 42`, `E = 42`.

**Posizione 4 della tabella di perft**,
`r3k2r/Pppp1ppp/1b3nbN/nP6/BBP1P3/q4N2/Pp1P2PP/R2Q1RK1 w kq - 0 1`. Fase 62. Materiale 100 / 100,
PST 34 / 26, mobilità 15 / 18, sicurezza del re 24 / 0 (attacco al re nero: Bb4 su e7 e f8, Nh6
su f7, `U = 6`, `n = 2`), spazio 6 / 0, minacce −30 / −30, iniziativa 10 / 10; doppiati e passati
si annullano: `MG = 159`, `EG = 124`, `E_W = 159`, `E = 159`.

## Classificazione

| Elemento | Classe | Base |
|---|---|---|
| Ogni termine della valutazione | `[HEURISTIC]` | Approssima il valore della posizione; può ordinare due posizioni nel modo sbagliato. Nessun peso è stimato su dati, scelto con una misura registrata o validato da un esperimento del repository: per il repository nessuno è `[LEARNED]` né `[EMPIRICAL]`. Ognuno ha una regola dichiarata; come siano stati scelti i sei pesi della struttura pedonale non è registrato ([QA-18](limiti-e-rischi.md#qa-18)). |
| Tavole PST precalcolate dalle formule | `[EXACT]` | Precalcolo: ogni voce è uguale alla formula; il dominio è finito (64 case per 6 tipi per 2 fasi) e si controlla per intero. |
| Stato incrementale (`psq_mg`, `psq_eg`, `fase_grezza`) | `[EXACT]` | Uguale al ricalcolo da zero dopo ogni make e unmake (INV-C8); evidenza per campioni dal test differenziale. La misura che [ADR-0017](adr/0017-percorso-di-ricerca-per-le-alternative-exact.md) chiede è in [EXP-0002](../research/exp-0002-stato-incrementale-della-valutazione.md), Accettato. |
| Fase, miscela, limite, punto di vista | nessuna | Fanno parte della definizione: non riducono lavoro. |

## Verifica

> **Deciso (autore → ADR-0018)** — Come si controlla la definizione. Oggi la implementano il riferimento e il
> livello ottimizzato, e i test elencati qui esistono per entrambi
> ([verifica](verifica.md#valutazione-e-ricerca-del-riferimento),
> [verifica](verifica.md#valutazione-e-ricerca-del-livello-ottimizzato)).

- **Uguaglianza fra i livelli (INV-C1).** La valutazione dell'ottimizzato, con lo stato
  incrementale e calcolata da zero, è uguale a quella del riferimento, e la scomposizione per
  termine (`X_mg(c)`, `X_eg(c)` per ogni termine e colore) è uguale termine per termine, così che
  una differenza dica quale termine differisce, come `divide` per il perft. Le posizioni: quelle
  delle tabelle di perft, dei casi speciali, dei test di FEN e di partenza del fuzzer, con i loro
  figli (fino a un ply in `make test`, due in `make differential-deep`); posizioni legali casuali
  raggiunte da un seme dichiarato con il generatore del fuzzer; ogni posizione di partite casuali
  con seme dichiarato giocate sui due livelli. Le posizioni della suite del fuzzer e quelle del
  test differenziale delle mosse non si valutano. Quante sono lo stampano i test
  ([verifica](verifica.md#valutazione-e-ricerca-del-livello-ottimizzato)).
- **Simmetria (INV-C7).** Sulle posizioni dei test di simmetria (le tabelle di perft, i casi
  speciali, le posizioni di partenza del fuzzer e 300 posizioni legali casuali estratte con un
  seme dichiarato, senza duplicati: `symmetry-fens` in `tests/test-mirror.lisp`), in entrambi i
  livelli,
  `E(m(p)) = E(p)` e `E_W(m(p)) = −E_W(p)`; anche per termine. Finché la definizione la ha, sulle
  stesse posizioni anche la simmetria fra le colonne: la riflessione a con h della sola
  disposizione dei pezzi lascia `E_W` invariato.
- **Stato incrementale (INV-C8).** Dopo ogni make, `psq_mg`, `psq_eg` e `fase_grezza` contro il
  ricalcolo da zero dell'ottimizzato: nel test differenziale delle mosse, il cui controllo di
  coerenza ricalcola lo stato dopo ogni mossa legale di ogni posizione visitata; nelle partite
  casuali della valutazione, per ogni mossa legale di ogni posizione; a due ply dalle posizioni
  di partenza del fuzzer.
  Dopo ogni unmake, lo stato è quello di prima della mossa (INV-C2). Contro la somma di materiale
  e PST del riferimento, una volta per posizione delle partite casuali.
- **Limite (INV-C9) e sola posizione (INV-C10).** `|E_W| ≤ 20000` sulle posizioni dei test di
  simmetria e su una posizione con 47 donne, che arriva al limite; due gruppi di posizioni che
  differiscono solo in orologi, diritti di arrocco o casa en passant hanno la stessa
  valutazione.
- **Valori attesi dall'esterno.** Gli [esempi](#esempi-calcolati) e le tavole PST di questo
  documento entrano nei test come valori attesi, in entrambi i livelli. Giudicano il riferimento
  da fuori, come i valori pubblicati di perft, con una differenza: non sono pubblicati, sono
  calcolati da questa definizione. Un test che fallisce dice che codice e documento non
  concordano, non quale dei due sbaglia.
- **La baseline di materiale resta.** `evaluate-material` del riferimento e i suoi test non
  cambiano. La valutazione classica è una funzione nuova, `evaluate-classical`. Le ricerche del
  riferimento valutano le foglie con quella classica, salvo che ricevano un'altra valutazione
  (`:evaluator`); i test scritti per la valutazione di materiale la passano esplicitamente, e
  passano come prima.

## Che cosa questa definizione non è

- Non è tarata dal repository: ogni numero ha accanto una regola scritta qui, scelta per essere
  semplice e verificabile, non per giocare bene. Dove la regola non fissa il numero, il numero è
  una scelta dentro la regola; per i sei pesi della struttura pedonale come sia stata fatta non è
  registrato ([Struttura pedonale](#struttura-pedonale), [Provenienza](#provenienza)). La
  taratura è della Fase 10.
- Non ha conoscenza dei finali: nessuna patta per materiale insufficiente, nessun pedone
  imprendibile, nessuna regola del quadrato.
- Non guarda la tattica oltre gli attacchi diretti: niente raggi X, niente inchiodature, niente
  SEE.
- Non ha cache né valutazione pigra: ogni termine non incrementale si calcola per intero a ogni
  chiamata.
- I parametri hanno un nome e una regola ciascuno, nel [riepilogo](#riepilogo-dei-parametri).
  Oggi ogni livello ne tiene una copia in cima al proprio codice, e il test differenziale le
  confronta; tenerli in un solo posto, nel `core` come
  [ADR-0018](adr/0018-definizione-della-valutazione-classica.md) permette, è una scelta aperta
  ([ADR-0019](adr/0019-valutazione-e-ricerca-del-livello-ottimizzato.md)). INV-X7, Deciso, chiede
  di poterli cambiare senza cambiare il codice: per la valutazione si applica dalla
  [Fase 10](roadmap.md#fase-10), quando la taratura ne ha bisogno
  ([ADR-0020](adr/0020-parametri-della-valutazione-dalla-fase-10.md), che chiude
  [QA-19](limiti-e-rischi.md#qa-19)). Fino ad allora i parametri sono costanti nel codice dei
  due livelli.
