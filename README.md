# Phoenix_Claranet_MarcoLaRocca

Phoenix Application Problem - Indice
---
Seguire le Fasi nell'ordine seguente:
- Fase1 - Creazione tramite CloudFormation dell'ambiente MONGODB
- Fase2 - Creazione dell'ambiente che ospitera l'applicazione tramite CloudFormation e Elastich Beanstalk
- Fase3 - Monitoraggio WEB APP e MONGODB
- Fase4 - Autoscaling WebApp
- Fase5 - Backup DB
- Fase6 - Creazione PIPELINE 

FASE 1 - Creazione tramite CloudFormation dell'ambiente MONGODB
---
In questa fase, tramite l'utilizzo di CloudFormation e seguendo le best pratices di Amazon andremo a creare un nuovo ambiente che includerà i seguenti oggetti:
- VPC
- Subnet
- Bastian Host in autoscaling per garantire alta affibabilità che ci consentirà di effettuare l'accesso nei server nelle subnet private
- Nat Gateway per consentire alle EC2 di andare su internet senza essere esposti al web.
- EC2 con a bordo il Database MongoDb.

Pre-Requisiti prima di lanciare il CF template:
Creazione di una KEYPAIR per poter accedere ai server.
All'interno di questo GIT è presente cloudformationMondoDb.yml.

Creazione ambiente
Procedere con la creazione di un nuovo stack importando il template cloudformationMondoDb.yml.

Ci saranno una serie di campi in cui inserire dei parametri, lasciare tutto default ad eccezione dei seguenti valori:
StackName --> nome dello stack CF
Availability Zones --> Indicarne 3 ( non obbligatorio ma consigliato )
Number Availability Zones --> Selezionare 3 (non obbligatorio ma consigliato)
Allowed Bastian External Access CIDR --> Per consentire l'accesso al Bastian Host da internet inserire 0.0.0.0/0 o uno specifico IP
KeyPair --> Selezionare la keypair creata
MondoDB Admin username --> admin username
MongoDB Password --> admin password.

Lasciare tutto di default nei seguenti NEXT e flaggare i campi sotto la sezione CAPABILITIES.

Al termine di 10 minuti avremo tutto l'ambiente creato e in stato running.

FASE 2 - Creazione dell'ambiente che ospitera l'applicazione tramite CloudFormation e Elastich Beanstalk

In questa fase verrà creato un ambiente che ospiterà l'app Node.js Phoenix.
Per poter rendere l'ambiente affidabile (automatizzando l'autostart a seguito di crash grazie all'autoscaling) e resilente è stato scelto l'utilizzo di Elastich Beanstalk e per l'automatizzazione CloudFormation.

Pre-requisiti:
Aver verificato che l'ambiente creato nella fase 1 sia up&running.
Aver ricavato la stringa di connessione a mongoDB cosi formata: 
mongodb://[username:password@]host1[:port1][,host2[:port2],...[,hostN[:portN]]][/[database][?options]]
E' importante verificare se il replica set sia attivo per fare ciò andare sul nodo Primario del DB tramite SSH.
Una volta dentro al server lanciare il comando mongo per entrare in una nuova shell di controllo del DB.
Autenticarsi eseguendo questo semplici comandi:
use admin
db.auth("username","password")
rs.status()
Infine bisogna creare un bucket s3 su cui bisognerà caricare il bundle in formato zip dell'applicazione Phoenix.

Creazione Ambiente
All'interno di questo GIT è possibile scaricare il template CF CloudFormationBeanStalk.yml.
Questo template creera un nuovo Ambiente e una nuova APP su Beanstalk che sarà, inizialmente, raggiungibile solo all'interno della VPC.
A questo punto creiamo un nuovo stack e importiamo il template CloudFormationBeanStalk.yml.
Di seguito i campi:
ApplicationKeyPair --> inserire la chiave per poter accedere sui server
ApplicationName	--> Nome dell'applicazione 
CreateApplicationCheck -->	yes/no se l'applicazione già esiste selezionare NO se non esiste SI,cosi facendo ne creerà una nuova	 
ELBScheme	--> internal (ELB esposto internamente)
EnvironmentName	--> nome dell'environment	 
HealthCheckPath	--> /	 
InstanceProfile	aws --> elasticbeanstalk ec2 role	 
InstanceType -->	t3.medium	 
MatcherHTTPCode -->	200,302	 
PlatformArn -->	platform/Node.js running on 64bit Amazon Linux/4.8.1	 
S3PackageBucket -->	Bucketname che ospita il bundle 
S3PackageKey -->	bundlephoenixApp.zip (nome del bundle importato nel bucket)	 
SecurityGroups -->	SG da assegnare alle EC2	 
ServiceRole	aws --> elasticbeanstalk service role	 
Subnets	--> scegliere almeno 2 subnet (private) per l'alta affidabilità su cui verranno attestati le EC2 e il LoadBalancer	 
VPCId	--> VPC creata con la FASE1

Al completamento dello stack per poter rendere utilizzabile l'App bisogna accedere alla console AWS ed effettuare alcune operazioni di completamento:

1)Di default il CF di mongoDB (FASE1) crea un security group "SGperaccessoaiDB" per le istanze che devono connettersi ai db, inserire qui la regola per aprire le porte 27017 all'ip della webapp o al SG a cui è associata la WebApp , ed associare il SG "SGperaccessoaiDB"  ai DB.
2)Andiamo nella console di Elasitch Beanstalk ed eseguiamo le seguenti operazioni :
  -Andiamo sull'app creata e clicchiamo su configurazione e successivamente clicchiamo su modifica nel riquadro Software
  -Impostiamo i seguenti parametri:
    -Server Proxy: Nessuno
    -Versione Node.js: 8.15
    -Comando nodo: npm start
    -Variabili d'ambiente: DB_CONNECTION_STRING/mongodb://[username:password@]host1[:port1][,host2[:port2],...[,hostN[:portN]]][/[database][?options]]
    
3) Se vogliamo rendere pubblica l'app eseguiamo questi step:

1.Disassociare il target group dall'internal load balancer creato da ElastiBeanstalk eseguendo il Delete listener dal Load Balancer Internal.
2. Modificare sulla Console EB il Load balancer da internal ad internet-Facing ed associare le subnet publiche al nuovo LoadBalancer.

FASE 3 - Monitoraggio WEB APP e MONGODB
-WEB APP
L'abilitazione del monitoraggio e notifica della CPU si può effettuare tramite la console di Elastic Beanstalk di seguito le operazioni:
1.Una volta entrati dentro l'environmnet creato andare su Monitoraggio
2.Selezionare il chart con la CPU e cliccare sul simbolo della campana, cosi facendo si aprirà una nuova pagina dove è possibile inserire:
NOME --> Nome dell'allarme
DESCRIZIONE --> Descrizione allarme(opzionale)
PERIODO --> Tempo necessario per il controllo dell'allarme
SOGLIA --> Utilizzo Medio della CPU nel Periodo indicato, indicare un valore di soglia.
CAMBIA STATO --> tempo necessario affinchè l'allarme cambi stato.
NOTIFICA --> Inserimento TOPIC EMail
NOTIFICA QUANTO LO STATO DIVENTA --> OK, ALLARME, DATI INSUFFICIENTI

-MongoDB
Per effettuare il monitoraggio della CPU sulle istanze di MONGODB è stato configurato CloudWatch.
Ecco i passaggi necessari:
1. APrire il servizio CloudWatch e cliccare su Allarme e Crea Allarme.
2.Selezioniamo il parametro andando sulla risorsa( in questo caso sarà una EC2 ) e scegliamo il parametro CPUUtilization.
3.Diamo un nome all'allarme e impostiamo la soglia ad esempio all'interno di un datapoint se il valore CPUUtilization supera il 90% scatta l'allarme.
4.Definiamo le operazioni da compiere nel momento in cui scatta l'allarme, ovvero indichiamo una email, cloud whatch creerà un nuovo topic ed invierà l'email all'indirizzo indicato quando la condizione di CPUUtilization si verificherà.

FASE 4 - Autoscaling per WEBAPP
La configurazione necessaria affinche la WEBAPP scali al superamento delle 10 request/s si può effettuare tramite la console di Elastich Beanstalk di seguito le operazioni:

Recarsi sul pannello dell'environment creato e selezionare configurazione.
Andare nel riquadro Capacità e successivamente cliccare su modifica.
Nel Trigger di dimensionamento selezionare:
Parametro RequestCount che è la metrica presa in questione.
Statistica --> Somma
Unità --> Conteggio 
Periodo --> 1 minuto
Durata dell'utilizzo fuori limite --> 1 minuto
Soglia Superiore --> 600 ( numero di richieste totali al minuto )
Incremento per aumento --> 1 ( numero di EC2 che si avviano al trigger )
Soglia inferiore --> 0 
Incremento per riduzione --> -1 ( numero di EC2 che vengono eliminate quando avviene uno scaling )

FASE 5 - Backup DB

All'interno di questo GIT c'è lo script mongodbtos3.sh che va eseguito dentro uno dei 3 server di MondoDB, preferibilmente il nodo secondario per evitare impatti sul primario che lavora in R/W.
Prima di eseguire lo script creare un bucket e uno IAM User che è autorizzato ad accedere su S3 ed impostare un lifecycle rule che eliminerà i file più vecchi di 7 giorni.

I pre-requisiti per eseguirlo correttamente sono questo:

1. Eseguire sul server il comando pip install awscli --upgrade --user 
2. Eseguire aws configure e mettere aws_access_key_id e aws_secret_access_key oltre alla region.
3. Customizzare i valori HOME,DB HOST, DBNAME, BUCKET e USER.
4. Concedere i permessi di eseguibilità con il comando chmod +x mongodbtos3.sh
5. Testare lo script eseguendolo ./mongodbtos3.sh
6. Impostare il backup per essere eseguito ogni giorno in modo automatico con crontab -e:
  -0 0 * * * /home/ec2-user/backup.sh > /home/ec2-user/mongodbtos3.log
  
FASE 6 - Creazione PIPELINE 

In questo git è stato caricato il json CloudFormationPipeline.json, prima di lanciarlo è necessario creare un repository su S3 con versioning abilitato e successivamente caricare il bundle dell'applicazione.

Alcune note prima di creare lo stack:
All'interno del template si devono customizzare alcuni valori:
Sotto la sezione resource va indicato sia il Repository(s3bucket) sia il pacchetto(Bucketkey), i valori sono i seguenti:

.......
  ],
                "Configuration": {
                  "S3Bucket": "phoenixmarco", <--
                  "S3ObjectKey": "cloud-phoenix-kata-master.zip", <--
 ......
 
 Inoltre è necessario definire Environment e l'app Beanstalk dove deployare il pacchetto, cambiando i valori seguenti:
 
 .....
      "Configuration":{
                  "ApplicationName":"marco", <--
                  "EnvironmentName":"marco-env" <--
......  

Ed infine bisogna indicare la location dell'ArtifactStore:

......
  "ArtifactStore":{
          "Type":"S3",
          "Location":"phoenixmarco" <--
        }
......        

Al termine di queste modifiche è possibile creare lo stack che in pochi minuti provvederà alla distribuzione del bundle desiderato.
