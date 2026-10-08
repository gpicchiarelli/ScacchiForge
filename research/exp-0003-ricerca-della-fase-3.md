# EXP-0003 — Ricerca della Fase 3: transposition table, PVS e NegaScout, ordinamento delle mosse

- **Stato:** Proposto
- **Data di apertura:** 2026-10-08
- **Autore:** proposta del repository
- **Revisione di base:** da fissare con l'esecuzione delle sezioni 6–8; la baseline è alpha-beta
  della Fase 2 senza ordinamento né TT, nella stessa revisione (la configurazione 1 delle righe di
  `make bench`)
- **Etichetta proposta:** `[EXACT]` sul valore a profondità fissa (senza TT, o con la TT in
  modalità di verifica); `[HEURISTIC]` sul valore con la TT in modalità normale; efficacia
  `[EMPIRICAL]`
- **Etichetta finale:** da compilare alla chiusura
- **Fase:** 3 ([roadmap](../docs/roadmap.md#fase-3))
- **Decisioni collegate:** [ADR-0021](../docs/adr/0021-transposition-table-del-livello-ottimizzato.md),
  [ADR-0022](../docs/adr/0022-pvs-negascout-e-tipi-di-nodo.md),
  [ADR-0023](../docs/adr/0023-ordinamento-delle-mosse-della-fase-3.md), tutti in stato Proposta

> **Nota sull'ordine delle tappe.** Le tre tecniche sono entrate nel codice insieme a questo
> record, non dopo: contro l'ordine che [research](README.md) chiede, come per EXP-0001 ed
> EXP-0002. Cambiano un'uscita della ricerca (i nodi; la mossa migliore e la variante fra mosse di
> valore uguale), quindi [ADR-0017](../docs/adr/0017-percorso-di-ricerca-per-le-alternative-exact.md)
> non si applica e vale la sequenza intera, self-play e validazione statistica comprese (INV-X3).
> Il repository non ha un ciclo di gioco né un'infrastruttura di self-play (Fase 10): le sezioni 7
> e 8 non si possono eseguire oggi. Il record non si chiude finché non lo sono. Le tecniche restano
> nel codice dietro i loro interruttori, come proposte (ADR-0021…0023), non come tecniche
> accettate.

## 1. Ipotesi

A profondità fissa, la ricerca di default della Fase 3 (iterative deepening di PVS con
l'ordinamento della Fase 3 e una TT, ADR-0022) visita meno nodi e costa meno tempo CPU di
alpha-beta della Fase 2 con iterative deepening, senza cambiare il valore; e a tempo fisso gioca
più forte.

- Metrica principale: la forza a tempo fisso (gradino 2 della
  [gerarchia](../docs/misure.md#gerarchia-delle-metriche)), quando il self-play esisterà. Fino ad
  allora, metriche secondarie e non decisive: nodi e tempo CPU a profondità fissa, efficienza
  dell'ordinamento, hit rate della TT, nelle righe di `make bench`.
- Effetto minimo che interessa: da fissare con il disegno del self-play (sezione 8), prima dei
  dati.

## 2. Razionale matematico

- **Ordinamento.** Con la mossa migliore per prima, alpha-beta visita l'albero minimo di Knuth e
  Moore, circa `b^⌈d/2⌉ + b^⌊d/2⌋ − 1` foglie in un albero uniforme, contro le `b^d` di negamax.
  La mossa TT e la mossa PV sono le migliori di una ricerca precedente; MVV/LVA è un'euristica
  sulle catture. L'ordine non cambia il valore di alpha-beta puro.
- **PVS e NegaScout.** Con un buon ordinamento la prima mossa è quasi sempre la migliore, e le
  altre si possono confutare con una finestra nulla, più stretta, che taglia di più; una
  ri-ricerca costa quando l'ordine sbaglia. Restituiscono il valore di alpha-beta.
- **TT.** Una posizione raggiunta per più percorsi (trasposizione) si cerca una volta; la mossa
  della entry ordina le iterazioni successive. Sotto TT-1…TT-4 il valore non cambia.
- Etichetta proposta e motivo: `[EXACT]` sul valore per le tre, con la base nei docstring e i
  test come evidenza per campioni (ADR-0021…0023);
  efficacia `[EMPIRICAL]`, perché il guadagno dipende dalle posizioni e dal costo per nodo.
- Ipotesi da cui dipende: TT-1…TT-4 in modalità di verifica; nessuna potatura oltre ad alpha-beta.
- Errore possibile: l'ordinamento e la TT costano per nodo (chiavi, sonde, inserimenti, cache
  miss di una tabella grande) più di quanto tolgono; una tabella grande può rallentare ogni sonda.
  In modalità normale il valore a profondità fissa può cambiare.

## 3. Implementazione

- Parametri esposti: l'algoritmo (`:alpha-beta`, `:pvs`, `:negascout`), l'ordinamento
  (`:ordering`), la tabella (`:tt`, con dimensione, politica e modalità come argomenti del
  costruttore). Nessuno è nel codice della ricerca.
- Interruttore che restituisce la baseline: `:algorithm :alpha-beta` senza `:ordering` né `:tt`
  esegue la baseline della Fase 2, invariata; la sua firma è la parte `:entries` di
  [`tests/search-signature.sexp`](../tests/search-signature.sexp).
- File toccati: `src/optimized/transposition.lisp`, `src/optimized/ordering.lisp`,
  `src/optimized/search.lisp`.

Reversibilità: le tre tecniche sono argomenti; togliere i file e le chiamate restituisce la
ricerca della Fase 2, la cui firma è registrata.

## 4. Verifica di correttezza

- Perft: la generazione delle mosse non cambia.
- Test differenziale: il valore e la variante principale della ricerca di default contro il
  riferimento (suite `differential`).
- Firma di ricerca: la parte di alpha-beta invariata; la parte della ricerca di default nuova
  (formato 2, ADR-0022).
- Suite per tecnica ([verifica](../docs/verifica.md#suite-per-tecnica)): `optimized-tt` e
  `optimized-pvs` ([verifica](../docs/verifica.md#ricerca-della-fase-3)).

## 5. Microbenchmark

Le righe della lookup di `make bench`: costo di un inserimento, di una sonda che trova e di una che
non trova, per dimensioni e politiche, su posizioni casuali con seme dichiarato. Il costo del
calcolo che la sonda sostituisce è quello di un sottoalbero, che le righe della ricerca danno
insieme. Nessuna esecuzione è registrata qui.

## 6. Benchmark di engine

Le righe della ricerca della Fase 3 di `make bench`: per undici configurazioni (alpha-beta di base,
alpha-beta, PVS e NegaScout ordinati, PVS con TT di tre dimensioni, tre politiche e due modalità,
PVS con TT senza ordinamento), su tre posizioni della firma, iterative deepening alla profondità
della firma: nodi, tempo CPU in due passate intercalate, quota dei tagli alla prima mossa, tagli
sui nodi che potevano tagliare, ri-ricerche, accordo fra tipo atteso e osservato, hit rate della
TT. Nessuna esecuzione è registrata qui: le cifre sono misure di una macchina, e dove tenerle è
[QA-14](../docs/limiti-e-rischi.md#qa-14). La regola di decisione per questa sezione non è
scritta: va scritta prima di un'esecuzione confermativa.

## 7. Self-play

Non eseguibile: nessun ciclo di gioco né infrastruttura di self-play nel repository (Fase 10).

## 8. Validazione statistica

Non eseguibile per la stessa ragione. Il test (SPRT o intervallo di confidenza) e i suoi
parametri si dichiarano prima dei dati.

## 9. Verdetto

Nessuno: il record è Proposto.

## 10. Riproducibilità

| Dato | Valore |
|---|---|
| Comandi esatti | `make bench` (righe della ricerca della Fase 3 e della lookup); `make test` e `make differential-deep` per la correttezza |
| Semi | quelli che `make bench` stampa nel registro dell'ambiente (`:tt-lookup`, `:tt-miss`) |
| Identità dei dati (hash) | le posizioni della firma, in `tests/test-optimized-search.lisp` |
| Versione di SBCL e parametri di avvio | da registrare con l'esecuzione |
| Macchina e sistema operativo | da registrare con l'esecuzione |
| Revisioni git | da registrare con l'esecuzione |
| Posizione dei risultati | aperta ([QA-14](../docs/limiti-e-rischi.md#qa-14)) |
