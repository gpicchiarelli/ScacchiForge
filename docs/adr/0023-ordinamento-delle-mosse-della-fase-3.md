# ADR-0023 — Ordinamento delle mosse della Fase 3

- **Stato:** Proposta
- **Data:** 2026-10-08
- **Rapporto con la specifica:** proposta nuova (non nella specifica); applica «MOVE ORDERING»
  (l'efficienza dell'ordinamento si misura a parte) e «MOVE GENERATION» (generazione, filtro di
  legalità, ordinamento ed esecuzione come fasi separate) nel livello ottimizzato, per la
  [Fase 3](../roadmap.md#fase-3). Killer, history, countermove e SEE sono della
  [Fase 4](../roadmap.md#fase-4), e qui non entrano.
- **Riferimenti:** [classificazione](../classificazione.md#ordinamento-delle-mosse),
  [misure](../misure.md#metriche-da-definire-una-volta), [verifica](../verifica.md#ricerca-della-fase-3),
  INV-C6, INV-A5, INV-X3,
  [ADR-0021](0021-transposition-table-del-livello-ottimizzato.md),
  [ADR-0022](0022-pvs-negascout-e-tipi-di-nodo.md),
  [EXP-0003](../../research/exp-0003-ricerca-della-fase-3.md)

## Contesto

Nella Fase 2 le ricerche del livello ottimizzato cercano le mosse nell'ordine del generatore. La
Fase 3 nomina l'ordinamento delle mosse insieme a TT e PVS, e il gate chiede di misurarne
l'efficienza a parte. La specifica elenca anche killer, history, countermove e SEE, che la roadmap
mette nella Fase 4. Serve una regola semplice, dichiarata, che usi solo ciò che la Fase 3 ha: la
mossa della TT, la variante dell'iterazione precedente e la posizione.

## Decisione

> **Proposta** — Proposta del repository, in attesa della decisione dell'autore.

1. **La regola.** Le mosse legali di un nodo si cercano in quest'ordine:
   1. la mossa TT, se è fra le mosse legali del nodo;
   2. la mossa PV, la mossa che l'iterazione precedente ha giocato in questo nodo, se il nodo sta
      sulla variante principale precedente;
   3. le catture, en passant compreso, dalla vittima di valore più alto e, a vittima uguale,
      dall'attaccante di valore più basso (MVV/LVA): le vittime per tipo, prima la donna, poi
      torre, alfiere, cavallo, pedone; gli attaccanti per tipo, prima il pedone, il re per
      ultimo. Una promozione che cattura è una cattura;
   4. le promozioni senza cattura: donna, torre, alfiere, cavallo;
   5. le altre mosse.

   A parità di posto le mosse tengono l'ordine del generatore.
2. **L'algoritmo.** Una chiave intera per mossa (`move-order-key`) e un ordinamento per
   inserimento stabile, sul posto, nel buffer delle mosse e in un vettore di chiavi parallelo,
   preallocato nel contesto della ricerca (`order-node-moves`,
   [`src/optimized/ordering.lisp`](../../src/optimized/ordering.lisp), un file del hot path).
   Non alloca. È una funzione separata dalla generazione, dal filtro di legalità e
   dall'esecuzione, come la specifica chiede.
3. **La mossa letta da una tabella** si usa solo se è fra le mosse che il generatore ha scritto
   per il nodo: l'ordinamento permuta il buffer, non vi aggiunge mosse. Una mossa TT che non c'è
   non prende posto, e la ricerca la conta come scartata (INV-C6).
4. **Interruttore.** L'ordinamento è un argomento della ricerca (`:ordering`); spento, le mosse
   restano nell'ordine del generatore, e alpha-beta senza TT è la baseline della Fase 2.
5. **Misura.** `make bench` stampa per ogni configurazione la quota dei tagli beta fatti dalla
   prima mossa, i tagli beta sui nodi che potevano tagliare e i nodi a profondità fissa, con e
   senza ordinamento ([misure](../misure.md#metriche-da-definire-una-volta)).

**Classificazione:** `[EXACT]` sul valore di alpha-beta puro, e di PVS e NegaScout che lo
restituiscono: l'ordine cambia i nodi e, fra mosse di valore uguale, la mossa migliore e la
variante, non il valore (Knuth e Moore, 1975). Efficacia `[EMPIRICAL]`, da misurare
([EXP-0003](../../research/exp-0003-ricerca-della-fase-3.md)). Se una riduzione dipenderà
dall'indice di mossa (LMR, Fase 5), da lì l'ordine farà parte del modello e la classe sarà quella
della riduzione ([classificazione](../classificazione.md#ordinamento-delle-mosse)).

**Invarianti:** INV-C6 (punto 3), INV-A5 (nessuna allocazione). **INV-X3** non è soddisfatto:
l'ordinamento cambia i nodi, un'uscita della ricerca; il record è
[EXP-0003](../../research/exp-0003-ricerca-della-fase-3.md), Proposto.

**Verifica:** nella suite `optimized-pvs` di `make test`: l'ordine che la regola dà, calcolato di
nuovo dal test con la scacchiera del riferimento, su posizioni di ricerca, della firma e casuali,
con e senza mossa TT e mossa PV e con una mossa TT illegale; la mossa TT prima e la mossa PV
seconda quando sono legali; nell'iterative deepening, la mossa PV cercata per prima a ogni nodo
della variante precedente (tante volte quante mosse ha quella variante); il valore di alpha-beta
ordinato, di PVS e di NegaScout uguale a quello della baseline, senza TT e con la TT in modalità
di verifica, anche con le mosse permutate dai semi; le varianti rigiocate dal riferimento.

## Conseguenze

- I nodi della ricerca di default, registrati nella firma
  ([ADR-0022](0022-pvs-negascout-e-tipi-di-nodo.md)), dipendono da questa regola e dall'ordine del
  generatore fra mosse dello stesso posto: un cambio di uno dei due cambia la firma, non il
  valore.
- L'ordinamento per inserimento costa al più quadratico nel numero delle mosse di un nodo; le
  mosse tranquille, chiave 0, non si spostano.

## Alternative considerate

- *Selezione pigra* (cercare la mossa migliore rimasta a ogni passo): meno lavoro quando un taglio
  arriva presto, ma l'ordine fra mosse di posto uguale dipende dagli scambi. Scartata per ora;
  si può misurare contro questa.
- *Valori dei pezzi invece dei tipi per MVV/LVA*: cambierebbe solo l'ordine fra alfiere e
  cavallo, oggi per tipo. Scartata: la regola per tipo non dipende dai pesi della valutazione.
- *Promozioni prima delle catture*: una scelta possibile; la regola le mette dopo, tranne quelle
  che catturano.
- *Killer, history, SEE*: Fase 4.
- *Ordinare nel generatore*: mescolerebbe due fasi che la specifica vuole separate, e cambierebbe
  il perft della Fase 1.

## Valutazione

- Si verifica con la suite `optimized-pvs` e con le righe di `make bench`.
- Porterebbero a rivedere la decisione: l'esito di
  [EXP-0003](../../research/exp-0003-ricerca-della-fase-3.md); le misure dell'efficienza
  dell'ordinamento contro un'altra regola.
