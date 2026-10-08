# Linguaggio visivo

Tutto ciò che nel repository si vede — marchio, immagini, badge, pagina iniziale — segue
queste regole. Sono poche perché devono essere rispettate sempre.

Il linguaggio è quello di ArcDocDB, dello stesso autore: stessi quattro colori, stessa
tipografia, stessa forma. Cambia soltanto ciò che l'ambra indica.

## Principi

1. **Un solo colore, un solo significato.** L'identità è monocroma. L'unico colore è l'ambra,
   e indica sempre e solo *ciò che può ancora cambiare*: la variante principale, la migliore
   linea trovata finora; il motore ottimizzato sotto prova; la fase del progetto tra i badge.
   Tutto ciò che è già cercato o già fissato è inchiostro. La nebbia è ciò che resta indietro,
   e ha due soli usi: i contorni dei nodi, che dicono solo dove un nodo finisce, e le mosse mai
   cercate. Un contorno non è mai d'inchiostro: l'unico contorno che si distingue è quello
   ambra.
2. **Niente che non serva.** Ogni elemento deve dire qualcosa del sistema. Nessuna decorazione,
   nessuna ombra, nessun gradiente, nessuna cornice.
3. **Il materiale è la pagina.** Le immagini hanno sfondo trasparente e si posano sulla pagina
   di GitHub, chiara o scura. Ogni immagine esiste nelle due varianti, e si legge alla
   larghezza a cui GitHub la mostra, dal telefono allo schermo largo.
4. **Una sola forma.** La capsula: una linea con le estremità tonde. È una mossa. Marchio,
   illustrazione e diagramma sono fatti solo di capsule e linee sottili.
5. **I numeri sono testo.** Un numero si scrive nel testo, dove può essere letto e corretto.
   Non diventa un badge, e un'immagine non contiene misure di prestazioni.
6. **Un disegno è esatto o non c'è.** L'albero della pagina iniziale è un albero vero, non
   un'illustrazione: lo si può contare. Un disegno descrive una struttura o un processo; non
   dice che qualcosa passi o sia veloce.

## Colori

| Nome | Chiaro | Scuro | Uso |
|---|---|---|---|
| Inchiostro | `#1d1d1f` | `#f5f5f7` | marchio, mosse cercate, ogni testo che si deve leggere |
| Grafite | `#6e6e73` | `#a1a1a6` | descrizioni, etichette dei ruoli, fili del diagramma |
| Nebbia | `#d2d2d7` | `#48484a` | i contorni dei nodi; le mosse mai cercate |
| **Ambra** | `#c9892f` | `#e9a84c` | ciò che può ancora cambiare: la variante principale, il contorno di `optimized`, la fase corrente |

Nelle immagini, nient'altro. I badge sono l'unica eccezione e restano quelli di ArcDocDB:
due grigi neutri, `#3a3a3c` e `#8e8e93`, e l'ambra per la fase. Verde e rosso compaiono solo
dove li impone GitHub (l'esito della CI).

L'ambra non colora mai un testo: sul bianco ha un contrasto di 2,96 : 1. Il testo è
inchiostro (16,8 : 1 sul bianco, 17,4 : 1 sul fondo scuro di GitHub) o grafite (5,1 : 1 e
7,4 : 1). La nebbia (1,5 : 1 e 2,1 : 1) è per ciò che deve restare indietro, e non porta mai
un significato da sola: accanto a ogni elemento di nebbia c'è un testo che lo dice. Lo stesso
vale per l'ambra, che sul bianco resta sotto i 3 : 1: il contorno di `optimized` ha sopra di sé
`UNDER TEST`, la variante principale ha sotto di sé il suo nome. Il colore lo fa vedere prima;
il testo lo dice a chi non lo vede.

L'anteprima per i social è l'unica immagine con uno sfondo: l'inchiostro del tema chiaro,
`#1d1d1f`, con i valori del tema scuro in primo piano. ArcDocDB usa il nero `#000`; qui non si
introduce un quinto colore.

## Tipografia

Carattere di sistema, in quest'ordine: `-apple-system`, `BlinkMacSystemFont`, `SF Pro Text`,
`Helvetica Neue`, `Helvetica`, `Arial`, `sans-serif`. Nessun carattere esterno.

Le misure sono in unità del disegno: la hero è larga 1200 unità, il diagramma 630.

| Ruolo | Corpo | Peso | Spaziatura |
|---|---|---|---|
| Nodo del diagramma, in minuscolo | 14 | 500 | normale |
| Stato o ruolo, diagramma (`UNDER TEST`, `ORACLE`) | 10,5 | 600 | +1,5 |
| Nome di stato, hero (`PRUNED`, `PRINCIPAL VARIATION`) | 14 | 600 | +2,1 |
| Descrizione, hero | 18 | 400 | normale |
| Nome, anteprima social | 76 | 500 | −2 |
| Frase, anteprima social | 27 | 300 | normale |

Le maiuscole spaziate sono riservate ai nomi di stato e di ruolo. I nomi di processi e
componenti — i motori, i gate — sono in minuscolo, come i nodi di ArcDocDB; `perft` si scrive
così anche nella letteratura. Nessuna abbreviazione nelle immagini: si scrive
`PRINCIPAL VARIATION`, non `PV`.

La hero e il diagramma scelgono la propria tipografia in base alla larghezza a cui sono
mostrati, con regole `@media` scritte nell'SVG, che valgono anche dentro un `<img>`. La hero si
mostra a tutta larghezza; il diagramma alla sua larghezza, 630 px, e su un telefono si riduce
di 358/630, non di 358/830.

| Hero, larghezza mostrata | Nomi / descrizioni | Tratti |
|---|---|---|
| oltre 800 px | 14 / 18 | come disegnati |
| da 561 a 800 px | 19 / 22 | come disegnati |
| fino a 560 px | 32 / nascoste | × 1,6 |

| Diagramma, larghezza mostrata | Nodi / stati | Tratti |
|---|---|---|
| oltre 560 px | 14 / 10,5 | come disegnati |
| fino a 560 px | 17,5 / 14 | × 2 |

Così il testo resta leggibile da 358 px in su, la larghezza di un README su un telefono
comune. I nomi di stato della hero misurano circa 10 px a 830, 9 a 561 e 9,5 a 358; i nodi del
diagramma 14 px a 630, 12,5 a 561 e 10 a 358. Il testo più piccolo, gli stati del diagramma su
un telefono, misura circa 8 px.

Due correzioni ottiche valgono per tutte le etichette. Un'etichetta si allinea
sull'inchiostro della prima o dell'ultima lettera, non sulla sua scatola: `PRUNED` comincia
esattamente dove comincia l'estremità tonda della foglia più a sinistra, e
`PRINCIPAL VARIATION` finisce dove finisce quella della variante principale. E l'ultima
lettera di un'etichetta spaziata non porta spaziatura (un `<tspan>` con `letter-spacing="0"`):
i browser non concordano sullo spazio dopo l'ultima lettera, e così un'etichetta allineata a
destra o al centro cade nello stesso punto in tutti.

Il nome del progetto è testo vero nel README, non un'immagine.

## Marchio

Un tronco che si biforca in due mosse: la decisione. Il ramo ambra è la variante principale,
la migliore linea trovata finora. Il nodo, la posizione presente, è d'inchiostro: è raggiunto
dal tronco, e una posizione prende il colore della mossa che la raggiunge.

| Costruzione | Valore |
|---|---|
| Griglia | 64 × 64 |
| Tratto | 5, estremità e giunzioni tonde |
| Tronco | da (32, 7) al nodo (32, 27) |
| Rami | dal nodo a (11, 55) e a (53, 55): ipotenuse di un triangolo 3-4-5, 21 in orizzontale, 28 in verticale, lunghe 35 |
| Dove comincia l'ambra | sulla prima sezione del ramo destro che appartiene solo a lui: la perpendicolare al ramo che passa per l'incavo, da (32, 31 ⅙) a (36, 28 ⅙) |
| Come è disegnato | l'inchiostro (tronco, ramo sinistro e il primo tratto del destro, fino a (34, 29 ⅔)) e sopra l'ambra, una capsula piena che comincia su quella sezione |
| Ingombro dei tratti | 42 × 48, come il marchio di ArcDocDB: x da 11 a 53, y da 7 a 55 |
| Posizione | in verticale, centrata otticamente: una Y rovesciata pesa in basso, e il marchio sta due unità più in alto di quello di ArcDocDB (4,5 sopra, 6,5 sotto). In orizzontale, il tronco sta sulla linea di centro: è un asse che si vede, e nella pagina cade sul centro del nome |
| Spazio di rispetto | nell'impaginazione, almeno un tratto e mezzo libero (7,5 unità) intorno ai tratti; il margine del file non è lo spazio di rispetto |
| Dimensione minima | 16 px, con il file a 16 px |

Il contorno del marchio è quello di una biforcazione semplice, e il colore cambia lungo un
segmento dritto che comincia esattamente nell'incavo. Il confine incontra i bordi del ramo ad
angolo retto: nessuno spigolo sottile, nessuna capsula posata su un'altra.

**A 16 px** si usa `mark-16-*.svg`: lo stesso disegno adattato ai pixel di un'icona 16 × 16,
con le stesse estremità tonde. Il tronco è largo un pixel, sulla colonna 8, e la sua estremità
tonda finisce sul bordo superiore del pixel 1. I rami sono larghi 1,4: una diagonale fatta di
pixel parziali si legge più leggera di una colonna di pixel pieni, e a 1,4 pesa quanto il
tronco. Un tronco di un pixel non può stare sulla linea di centro di un'icona di 16 (cadrebbe a
cavallo di due colonne e diventerebbe grigio), quindi il disegno si sposta di mezzo pixel; si
sposta a destra, verso il lato ambra, che è il più leggero. Lo spostamento è imposto dai pixel,
non è una correzione del marchio: dai 24 px in su si usa il marchio, con il tronco al centro.

Non si ruota, non si deforma, non si ricolora, non si affianca al nome in un'unica immagine.

## L'albero

La hero è l'albero che alpha-beta esplora quando prova sempre per prima la mossa migliore:
due mosse per posizione, cinque semimosse di profondità. È l'albero minimo di Knuth e Moore
(1975), disegnato nodo per nodo. In ogni posizione la mossa provata per prima è quella a
destra, come nel marchio. Chi legge da sinistra incontra prima ciò che è stato tagliato:
l'albero minimo è sbilanciato per natura, e il disegno non lo raddrizza.

| Costruzione | Valore |
|---|---|
| Radice | in (600, 28), al centro, sotto il marchio della pagina |
| Passo | foglie a 35 unità; livelli a 64 unità; foglie su y = 348 |
| Tratti | nebbia e inchiostro 4,5, ambra 6: 3 : 3 : 4. Una mossa è sempre la stessa linea, e solo il colore dice se è stata cercata. La variante principale è più larga di un terzo: alla stessa larghezza, l'ambra sul bianco (2,96 : 1) affonda sotto l'inchiostro che le sta intorno |
| Variante principale | un solo tracciato ambra dalla radice all'ultima foglia, in basso a destra, disegnato per ultimo |
| Taglio | il primo ramo potato comincia a 18 unità dal nodo che lo taglia, lungo il ramo stesso: il taglio è un'interruzione, non un segno in più |
| Foglie | ogni estremità tonda tocca la stessa riga, a ogni larghezza |
| Etichette | 30 unità d'aria tra le foglie e le maiuscole; allineate sull'inchiostro delle estremità più esterne |

Ogni posizione prende il colore della mossa che la raggiunge. Le posizioni della variante
principale sono raggiunte da mosse ambra: la variante si disegna per ultima, con giunzioni
tonde, e i rami d'inchiostro escono da sotto di lei. La radice non è raggiunta da nessuna
mossa: appartiene alla variante che parte da lì, e la sua estremità tonda è l'inizio della
linea ambra. Nel marchio, invece, il nodo è raggiunto dal tronco, ed è d'inchiostro.

Il marchio e la radice si somigliano, ma non coincidono: nella hero i rami della radice
scendono di 64 unità su 280, non di 4 su 3, e i tratti hanno pesi diversi.

Sotto i 560 px i tratti diventano 1,6 volte più spessi, le descrizioni spariscono e i nomi di
stato passano a corpo 32. L'albero scende di 10 unità, così lo spazio sopra la radice è uguale
a quello sotto i nomi (31,4 unità); ogni classe di tratti risale del suo raggio in più (1,35
unità la nebbia e l'inchiostro, 1,8 l'ambra), così le foglie toccano ancora la stessa riga; e i
nomi seguono le estremità, più larghe.

Il conto si scrive nel testo: 11 foglie cercate su 32, cioè 2³ + 2² − 1, il minimo con cui
si può dimostrare il valore. Otto tagli. È un `THEOREM`, non una misura. Delle 62 mosse
dell'albero, 34 non sono mai cercate, e così 21 foglie su 32: sono più della metà del disegno
per numero e il 44 % della sua superficie, ma anche la parte più quieta. Ciò che non si è mai
cercato resta indietro; il conto dice quanto è.

## I gate

Il percorso che ogni modifica deve fare: sei capsule su tre colonne e due righe, unite a U.
`optimized`, il candidato sotto prova, sta in alto a sinistra, dove si comincia a leggere, ed
è l'unico contorno ambra. Scende nel primo gate, `perft`, attraversa `differential` e
`benchmark` e risale nell'ultimo, `self-play`, in alto a destra. `reference`, semplice e
leggibile, sta al centro della riga superiore: è l'oracolo, e alimenta solo il gate sotto di
sé, `differential`, dove si verifica `optimized(position) == reference(position)` su milioni
di posizioni. Gli altri gate hanno il proprio termine di confronto, scritto nel testo e non nel
disegno: `perft` i conteggi pubblicati, `benchmark` una baseline, `self-play` la versione
precedente.

Tutti gli altri contorni sono nebbia, come i nodi di ArcDocDB: anche quello di `reference`.
L'oracolo è fissato quanto i gate, e un contorno d'inchiostro, il più forte dell'immagine,
porterebbe l'occhio sull'oracolo prima che sul candidato. Ciò che distingue `reference` è il
suo posto, al centro, e il suo nome, `ORACLE`.

| Costruzione | Valore |
|---|---|
| Nodi | capsule tutte uguali, 170 × 38, raggio 19, contorno 1,25 |
| Griglia | tre colonne a passo 214, da x = 16 a x = 614; righe al centro di y = 57 e di y = 139; 16 unità di margine ai lati |
| Fili | grafite, spessore 1; ogni filo, orizzontale o verticale, in discesa o in salita, è lungo 30 e lascia 7 unità d'aria a ciascuna estremità; punte di freccia lunghe 5,5 e larghe 8 |
| Stati | 11 unità d'aria tra le maiuscole e la capsula; le maiuscole cominciano a 20 unità dal bordo, come i nodi finiscono a 20 unità dal fondo |
| Larghezza | 630 unità, mostrate a 630 px: un'unità è un pixel |

Su un telefono gli stati crescono verso l'alto e i contorni verso l'esterno; il disegno scende di
0,81 unità, così lo spazio sopra le maiuscole resta uguale a quello sotto i contorni.

Il disegno descrive il processo richiesto a ogni modifica. Non dice che un gate passi.

## File

| File | Contenuto |
|---|---|
| [`img/mark-light.svg`](img/mark-light.svg) · [`img/mark-dark.svg`](img/mark-dark.svg) | il marchio |
| [`img/mark-16-light.svg`](img/mark-16-light.svg) · [`img/mark-16-dark.svg`](img/mark-16-dark.svg) | il marchio a 16 px |
| [`img/hero-light.svg`](img/hero-light.svg) · [`img/hero-dark.svg`](img/hero-dark.svg) | l'albero minimo: ciò che si cerca e ciò che si toglie |
| [`img/flow-light.svg`](img/flow-light.svg) · [`img/flow-dark.svg`](img/flow-dark.svg) | i gate di ogni modifica |
| [`img/social.svg`](img/social.svg) · [`img/social.png`](img/social.png) | anteprima per i social, 1280 × 640 |

La variante scura di un'immagine è la variante chiara con i quattro colori sostituiti secondo
la tabella sopra; la geometria è identica. Ogni immagine ha `title` e `desc` per chi non la
vede, e nessuno dei due nomina un colore che cambi con il tema.

```sh
sed -e 's/#1d1d1f/#f5f5f7/g' -e 's/#6e6e73/#a1a1a6/g' \
    -e 's/#d2d2d7/#48484a/g' -e 's/#c9892f/#e9a84c/g' \
    img/hero-light.svg > img/hero-dark.svg
xmllint --noout img/*.svg
```

`social.png` è `social.svg` reso a 1280 × 640, in RGB, senza canale alfa. Si rigenera solo
quando cambia `social.svg`, con qualunque strumento che usi il carattere di sistema, e si
controlla così:

```sh
sips -g pixelWidth -g pixelHeight -g hasAlpha img/social.png
```

Il comando deve stampare 1280, 640 e `no`. L'anteprima per i social non si imposta da riga di
comando: si carica `img/social.png` in *Settings → General → Social preview*.

## Badge

Una sola riga, cinque al massimo, tutti dello stesso stile:
`style=flat-square`, etichetta `#3a3a3c`, valore `#8e8e93`. Solo il badge della fase usa l'ambra
`#c9892f`. Dicono che cosa è il progetto (licenza, linguaggio, runtime, dipendenze, fase); non
contano cose. Il badge della CI, che ha i colori di GitHub, sta nella sezione *Status*.

```
https://img.shields.io/badge/<etichetta>-<valore>-8e8e93?style=flat-square&labelColor=3a3a3c
https://img.shields.io/badge/phase-<n>-c9892f?style=flat-square&labelColor=3a3a3c
```

## La pagina iniziale

Nell'ordine: marchio, nome, una frase, i badge, la navigazione, l'illustrazione. Poi le
sezioni, ciascuna con un'idea sola. Frasi brevi. Tabelle senza intestazione quando le colonne
si spiegano da sole. Nessuna emoji.

Ogni immagine si inserisce centrata, con le due varianti scelte dal tema della pagina, e
ciascuna alla sua misura: il marchio a 72 px, la hero a tutta larghezza, il diagramma a 630 px,
la sua larghezza in unità. Su un telefono GitHub riduce ogni immagine alla larghezza della
colonna. Il testo alternativo dice che cosa si vede, alla lettera, e non nomina un colore che
cambi con il tema (l'ambra resta ambra in entrambi).

Il marchio ha testo alternativo vuoto, perché il nome segue subito sotto, come testo:

```html
<p align="center">
  <picture>
    <source media="(prefers-color-scheme: dark)" srcset="assets/img/mark-dark.svg">
    <img src="assets/img/mark-light.svg" alt="" width="72" height="72">
  </picture>
</p>

<h1 align="center">ScacchiForge</h1>

<p align="center">
  A chess engine that decides by removing work,<br>
  and never mistakes a heuristic for a theorem.
</p>
```

La frase è quella dell'anteprima per i social. Dopo i badge e la navigazione, la hero:

```html
<p align="center">
  <picture>
    <source media="(prefers-color-scheme: dark)" srcset="assets/img/hero-dark.svg">
    <img src="assets/img/hero-light.svg" alt="A search tree with two moves per position, five deep; at every position the first move tried is drawn on the right. The principal variation runs in amber from the root to the bottom right. The other searched moves are strong lines. Where a cutoff stops the search the line breaks, and the faint subtrees beyond the breaks were never searched: 34 of the 62 moves. Eleven of the 32 leaves are searched." width="100%">
  </picture>
</p>
```

E, nella sezione sulla verifica, il diagramma:

```html
<p align="center">
  <picture>
    <source media="(prefers-color-scheme: dark)" srcset="assets/img/flow-dark.svg">
    <img src="assets/img/flow-light.svg" alt="Two engines and four gates, joined in a U. Top left, the optimized engine, outlined in amber, is under test: it goes down into perft, across through differential and benchmark, and up into self-play. In the middle of the top row the reference engine, the oracle, feeds only the differential gate below it." width="630">
  </picture>
</p>
```

## Che cosa non si fa

- Aggiungere un colore.
- Usare l'ambra per qualcosa che non cambia, o per un testo.
- Dare a un contorno un colore che non sia la nebbia, salvo l'ambra del candidato.
- Nominare in un testo alternativo un colore che cambia con il tema.
- Mettere testo dentro un'immagine quando può stare nella pagina.
- Scrivere in maiuscolo il nome di un processo o di un componente.
- Aggiungere un badge per un numero.
- Usare un'immagine con lo sfondo, salvo l'anteprima per i social.
- Disegnare pezzi, scacchiere o caselle.
- Disegnare un albero che non si possa contare.
- Segnare un taglio con un oggetto: il taglio è un'interruzione.
- Presentare uno schema come il risultato di una misura.

## Alternativa fotografica

Alcuni progetti dello stesso autore, come [GPForum](https://github.com/gpicchiarelli/GPForum)
e [AutomaGP](https://github.com/gpicchiarelli/AutomaGP), aprono il README con un render
fotorealistico di una stanza. Per ScacchiForge l'illustrazione è vettoriale, per scelta, per i
principi 2, 3 e 6: il README usa la hero vettoriale, e il repository non contiene fotografie.
Se si volesse comunque un'immagine di quella serie, va prodotta con un generatore di immagini
a partire da questa descrizione. L'unica luce calda è il ramo ambra.

<details>
<summary>Descrizione per il generatore</summary>

```
Photorealistic cinematic interior photograph, 16:9, calm low-key lighting, warm soft light.
A quiet study in a country villa. No people.

The central wall is textured warm grey plaster. Mounted on it, a large brass wall relief,
centred and generously spaced: a single vertical brass bar that forks into two diagonal
brass bars, like an upside-down letter Y, every bar slim with softly rounded ends. The
trunk, the left branch and the fork itself are matte dark bronze, softly rim-lit from behind.
The right branch, from the fork to its end, is the only element that glows: a warm amber
light from within, steady and quiet. Nothing else on the wall.

Below it, a long low sideboard in dark walnut with a brass desk lamp, switched off, and two
closed leather-bound notebooks. On the left, dark vertical slatted wood panelling. On the
right, a tall black-framed window onto green trees in the late afternoon.

Foreground, slightly out of focus: a dark walnut desk with a closed notebook, a fountain pen
and a ceramic cup.

Calm, exact, serious mood, generous empty space. Deep brown and olive shadows, warm amber
highlights, shallow depth of field, subtle film grain. The amber branch is the only coloured
light source. No people, no chess pieces, no chessboard, no readable text, no numbers, no
logos, no watermark.
```

</details>
