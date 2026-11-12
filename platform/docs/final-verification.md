# Verifica finale — 12 novembre 2026

Ambiente: cluster locale kind-kiratech-l2-rebuild.
Revisione verificata: 02e97fbc, branch challenge/platform.

## Risultati

- Nodo Ready e tutti i pod osservati pronti dopo il riavvio.
- Frontend dev con una replica e prod con due repliche.
- Homepage dev e prod raggiungibili tramite Traefik con HTTP 200.
- Percorso manuale prodotto, carrello, valuta EUR e checkout
  completato nei due ambienti, con conferma dell'ordine.
- Mappa del progetto pubblicata e diagrammi controllati su GitHub.
- Repository pubblico.

La CI della revisione verificata è terminata con successo:
https://github.com/Owl9696/kiratech-l2-challenge/actions/runs/43232289510

## Anomalia osservata in prod

Durante la prima prova sono state osservate richieste al carrello
e al checkout registrate dal frontend con HTTP 500 e context canceled.
Un tentativo di checkout è terminato dopo 7,54 secondi.

Sono seguiti due checkout con HTTP 200 e ID ordine differenti,
con durate registrate di 1,224 secondi e 364 millisecondi.
Le richieste della stessa sessione risultavano in parte sovrapposte.

Il terminale del port-forward ha inoltre mostrato un broken pipe,
continuando successivamente a gestire connessioni.
Questi elementi non dimostrano la causa delle cancellazioni.

Una successiva prova manuale, eseguita attendendo la risposta a ogni
passaggio, è stata confermata riuscita dall'operatore.
Non sono stati acquisiti nuovi log del checkout per questa ripetizione.
Non sono state applicate modifiche alla configurazione.

## Limiti della verifica

La prova conferma il funzionamento osservato, ma non costituisce
un test di carico o una garanzia di assenza di errori intermittenti.
La causa dell'anomalia iniziale rimane non determinata.

Le verifiche automatiche degli endpoint sono distinte dalla prova
manuale del percorso di acquisto.
