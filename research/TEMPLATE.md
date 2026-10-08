# EXP-NNNN — Titolo breve dell'esperimento

- **Stato:** Proposto | In corso | Accettato | Rifiutato | Abbandonato
- **Data di apertura:** AAAA-MM-GG
- **Autore:**
- **Revisione di base:** revisione git su cui si misura la baseline
- **Etichetta proposta:** una o più delle sette di [classificazione](../docs/classificazione.md)
- **Etichetta finale:** compilare alla chiusura
- **Fase:** numero della [roadmap](../docs/roadmap.md)

<!--
Ogni sezione risponde a una tappa della metodologia della specifica:
ipotesi, razionale matematico, implementazione, microbenchmark, benchmark di engine,
self-play, validazione statistica, accettazione o rifiuto.
Una tecnica non si accetta perché «sembra più veloce».
Non si inventano numeri: ogni cifra viene da un comando riportato in «Riproducibilità».
Un esperimento rifiutato non si cancella: il risultato negativo resta.
-->

## 1. Ipotesi

Che cosa si pensa che migliori, in quale direzione, rispetto a quale metrica della
[gerarchia](../docs/misure.md#gerarchia-delle-metriche). Deve poter essere smentita.

- Metrica principale:
- Effetto minimo che interessa:

## 2. Razionale matematico

Perché dovrebbe funzionare. Quali ipotesi servono. Quali casi sono noti per far fallire la
tecnica. Su questa base si sceglie l'etichetta proposta.

- Etichetta proposta e motivo:
- Ipotesi da cui dipende:
- Errore possibile:

## 3. Implementazione

Che cosa cambia. Dove.

- Parametri esposti in configurazione (nessun parametro importante vive nel codice):
- Interruttore che spegne la tecnica e restituisce il comportamento della baseline:
- File toccati:

Reversibilità: come si toglie la tecnica senza lasciare tracce.

## 4. Verifica di correttezza

- Perft, se cambia la generazione delle mosse:
- Test differenziale, se cambia il livello ottimizzato:
- Firma di ricerca: invariata, oppure cambiata per questo motivo:
- Suite per tecnica ([verifica](../docs/verifica.md#suite-per-tecnica)):

## 5. Microbenchmark

Solo se la modifica ha un kernel misurabile. Che cosa si misura, con quali ingressi e quali semi,
contro la baseline, con la dispersione. Il costo del meccanismo (lookup, aggiornamento) contro il
calcolo che sostituisce.

## 6. Benchmark di engine

Contro la baseline, sulla stessa macchina: nodi e QNodes, profondità a tempo fisso, hit rate della
TT, cutoff rate, efficienza dell'ordinamento, valutazione, allocazione, GC, RSS.

## 7. Self-play

- Modalità: tempo fisso | nodi fissi
- Limiti di tempo o di nodi; dimensione della TT; thread:
- Insieme di aperture (identità) e seme:
- Revisioni di A e di B:

## 8. Validazione statistica

- Test: SPRT | intervallo di confidenza
- Parametri dichiarati **prima** dei dati (`elo0`, `elo1`, `α`, `β`, o larghezza obiettivo):
- Numero di varianti provate contro la stessa baseline (confronti multipli):
- Risultato: partite (W, D, L), Elo stimato con intervallo, esito del test:
- Conferma indipendente (altro seme, altre aperture):

## 9. Verdetto

**Accettato | Rifiutato | Abbandonato.** Il motivo, in poche righe.

- Etichetta finale e su quale evidenza:
- Che cosa cambia in [classificazione](../docs/classificazione.md) o in un ADR:
- Come si torna indietro:

## 10. Riproducibilità

Ciò che serve a ripetere tutto.

| Dato | Valore |
|---|---|
| Comandi esatti | |
| Semi | |
| Identità dei dati (hash) | |
| Versione di SBCL e parametri di avvio | |
| Macchina e sistema operativo | |
| Revisioni git | |
| Posizione dei risultati | |
