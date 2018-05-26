# MASI-OpenSource

## Introduction
Désireuse de moderniser son infrastructure, la société IGLU a décidé de se tourner vers des conteneurs Docker afin d’allouer les différentes ressources nécessaires à ses projets. La première partie de ce rapport détaille le choix de ces services en fonction des besoins de la société.

Dans la seconde partie, l’architecture globale des services mis en place est présentée ainsi que le détail des dépendances entre les différents conteneurs.

Ensuite, les scripts généraux automatisant le déploiement de toute l’infrastructure sont documentés et commentés. Les différents fichiers nécessaires aux configurations des scripts sont également listés et expliqués. 

Enfin, la solution proposée n’étant pas exempte de défauts, les différents problèmes connus sont listés et pour chacun d’entre eux, des pistes d’améliorations possibles sont données avant de passer à la conclusion.

## Choix des services

Pour chacun des services dont la société a besoin, nous avons tenté de sélectionner les services open source les plus pertinents. Nos principaux critères ont été la documentation disponible, la gestion via des interfaces user-friendly et l’intégration LDAP.

### Serveur LDAP

| **OpenLDAP** | Principalement CLI → extensible avec une interface web pour la gestion |
| ApacheDS | - Écrit en Java<br> - Gestion par software |
| 389 Directory Server | - Développé par Red Hat<br> - Gestion possible via web interface + software |
| Forgerock directory services | - Écrit en Java<br> - Gestion par software |

Nous avons choisi OpenLDAP car il est déjà fort établi dans les annuaires open source, ce qui se traduit par une grande quantité de documentation.

Nous avon étendu ce conteneur afin d'intégrer un script de création d'une structure prédéfinie d'Organizational Units et de groupes.

### Serveur DNS + DB (pour enregistrements)

| **PowerDNS** | Supporte beaucoup de back-end (MySQL, Postgresql, etc… lien) |
| MyDNS-NG | - Support pour des DB en back-end<br> - Pas de DB |

#### DB :
| **PostgreSQL** | - Peut également être utilisée avec Gitlab (regroupement des services sur un sgbd -> voir améliorations possibles)<br> - choisie arbitrairement (habitude de travailler avec ce sgbd) |

Nous désirions avoir un service DNS qu'il était possible d'étendre sans manipuler des fichiers. Une gestion par base de données se présentait comme plus adéquate (comme expliqué dans le détail du script).

Nous avons également étendu le conteneur du service DNS et le conteneur de base de données de back-end. Ceci afin de n'intégrer que le conteneur back-end nécessaire pour le service DNS, réduisant sa complexité et sa taille, ainsi que le conteneur de base de données pour pré-créer le schéma nécessaire pour le service DNS de front-end.

### Serveur mail

| Zimbra | Pas prévu pour déploiement Docker |
| **tvial/docker-mailserver** | Solution tout-en-un permettant de directement interconnecter avec un serveur LDAP |
| hardware/mailserver | Ensemble de conteneur préfait |
| Mailu | Solution Open source mais non testée pour un environnement de production |
| poste.io | - FGratuit mais pour usage personnel uniquement<br> - Open source ? |
| freeposte.io | - Alternative Open source  à poste.io<br> - Solution de type tout-en-un |
| postfix/dovecot | Implémentation à la main sans webmail  |

Nous avons choisi ce conteneur pour sa facilité de déploiement sur un service LDAP existant. Cependant la configuration des services dovecot (IMAP) et postfix (SMTP) pour l'authentification et la livraison des mails respectivement a demandé un grand nombre de modifications.

Pour ces raisons, nous avons étendu ce conteneur pour y intégrer notre propre script d'entrypoint afin de mieux le personnaliser sans devoir y apporter des modifications après lancement.

### Serveur de fichiers

| Owncloud | - Connection serveur LDAP possible<br> - Possible d’avoir plusieurs compte avec client Windows |
| Syncthing | Connection serveur LDAP possible |
| Seafile | - Connection a serveur LDAP possible<br> - Support sync multiple folder sur client ??? |
| Resilio | propriétaire |
| Rclone | Uniquement en ligne de commande |
| Nextcloud | - Connection a serveur LDAP possible<br> - Support sync multiple folder sur client ???<br> - Fonctionne également avec client OwnCloud |

Malheureusement, notre choix initial de Owncloud ne proposait pas de configuration d'authentification au LDAP scriptable. Par un souci de temps, nous sommes donc passés sur un serveur Samba contenant deux partages pré-créer (un conteneur que nous avons créé nous-mêmes), un partage pour les membres internes au projet et un partage pour les membres externes.

### Serveur web

Nous avons décidé de scinder le serveur web en deux avec deux fonctionnalités différentes : un CMS pour gérer le contenu des sites vitrines des projets et un serveur web pour fournir un environnement de test aux développeurs.

#### Vitrine

| **Wordpress** | - Connexion via LDAP avec un plugin<br> - Très connu et  très utilisé -> communauté<br> - Convient pour des sites vitrines |
| Drupal | - CMS correct<br> - Authentification via LDAP avec le LDAP Project<br> - Orienté développeurs -> plus complexe<br> - Convient à des sites complexes |

Nous avons sélectionné Wordpress comme CMS afin de gérer les sites reprenant les différentes publications relatives aux projets en cours car il est entouré d’une grande communauté (fournissant une documentation étoffée). De plus, il nous a paru être intuitif d’utilisation.

Wordpress dispose d’une place de marché comprenant plusieurs plug-ins permettant une authentification via OpenLDAP.

#### Serveur Test

| **Apache HTTP Server** | - Nombreuses possibilités de configuration<br> - Très connu -> communauté |

Nous avons choisi d’utiliser Apache comme serveur web car il s’agit d’un serveur web solide, largement utilisé. 

### Serveur de versionning

| **Gitlab** | - Service de management de repository git en ligne<br> - Issues tracking<br> - User-friendly |
| Trac | Issues tracking plus que vraiment du versioning |
| Gogs | Moins connu |

### Conteneur personnalisé
Les conteneurs que nous avons étendus/créés de nous même sont:
 * [cajetan19/samba-ldap](https://hub.docker.com/r/cajetan19/samba-ldap/)
 * [cajetan19/powerdns-pgsql](https://hub.docker.com/r/cajetan19/powerdns-pgsql/)
 * [cajetan19/postgresql-powerdns](https://hub.docker.com/r/cajetan19/postgresql-powerdns/)
 * [cajetan19/openldap](https://hub.docker.com/r/cajetan19/openldap/)
 * [cajetan19/mailserver](https://hub.docker.com/r/cajetan19/mailserver/)

Les conteneurs sont liés à leur propre repository GitHub, donnant accès au code source.

## Architecture

Voici un schéma représentant les différents services repris par notre solution. Ils sont divisés en deux parties : la partie propre à l’infrastructure de la société et la partie propre à chaque projet.

Les flèches représentent les dépendances entre les différents conteneurs. 

Nous avons souhaité rendre l’authentification plus aisée (et uniforme) en passant par un service LDAP. C’est pourquoi nous avons tenté de lier le plus de conteneurs possibles au service OpenLDAP. Malheureusement, nous avons rencontré de nombreuses difficultés quant à la configuration à appliquer aux conteneurs pour accrocher au serveur LDAP.

## Détail des scripts

### main/start.sh

C’est le script à lancer pour la création des services propres à l'infrastructure de la société. Il n’est lancé qu’une seule fois.

#### Prérequis

Les fichiers nécessaires à la configuration sont:

**docker-compose.yml** : reprenant tous les services à créer avec leur image respective, les volumes à allouer, les variables d’environnement à lier, etc...
**.env** : reprenant toutes les variables contenant les informations nécessaires à la configuration :

 * les noms d’utilisateur, les mots de passe, les ports à allouer pour chaque service, les chemins des volumes et les IP. 

**users.csv** : contenant la liste des utilisateurs à créer (répartis entre 3 différents groupes : Administrators, Users ou Externals).

#### Lancement

Le fichier s’exécute sans argument. Il sera néanmoins demandé à l’administrateur d’entrer son mot de passe afin de permettre certaines configurations. L’exécution demandant un certain temps, des messages détaillant l’état d’avancement sont régulièrement affichés à l’utilisateur.

#### Explications 

Le script commence par récupérer les variables d’environnement du fichier .env et par créer l’arborescence des volumes partagés par les conteneurs.

Ensuite, le docker-compose.yml est appelé.

La partie suivante comprend la création des entrées DNS qui sont directement insérées dans la base de données. S’en suit la création du schéma LDAP, ainsi que des utilisateurs dont les informations sont récupérées depuis le fichiers users.csv.

En fin d’exécution, le détail des configurations effectuées est affiché à l’utilisateur afin de lui donner un récapitulatif.

### project_name/start.sh

Avant de pouvoir configurer les fichiers requis pour la création d’un nouveau projet, il est nécessaire de lancer le script **newproject.sh** contenu dans le dossier project et d’indiquer le nom du nouveau projet lorsque qu'il vous l'est demandé.

```
bash newproject.sh
```

Ce script a pour effet de créer un dossier au nom du nouveau projet où se trouve le script start.sh, point de départ du déploiement de tous les services nécessaires au projet. Les fichiers de configurations à éditer sont également présents dans le dossier.

Le script newproject.sh doit être lancé pour la création de tout nouveau projet.

#### Prérequis

Ce script nécessite que le **main/start.sh** ait été lancé en premier et que les services principaux tournent.

Les fichiers nécessaires à la configuration sont:

**users.csv** contenant les listes des utilisateurs, nouveaux ou existants en annuaire, qui feront partie du projet.
La syntaxe doit être:

```
name,surname,username,group
```

 * name
    * Prénom de l'utilisateur
 * surname
    * Nom de famille
 * username
    * Nom d'utilisateur
    * Doit être unique
 * group
    * Peut être une de ces trois valeurs:
        * administrators
        * users
        * externals

**.env** contenant les variables qui vont définir les services du projet telles que son nom, les identifiants et mots de passe des services, etc. Les valeurs les plus importantes **à modifier pour chaque nouveau projet** sont:

 * PROJECT_NAME
    * Définit le nom du projet ainsi que le nom de domaine est les adresse mails utilisés
 * Les champs USER et PASSWD
    * Définissent les identifiants des services, notamment SMB pour le partage de fichier, ou Wordpress pour l'accès au service par defaut.
 * Les champs IP
    * Il est impératif de les changer pour une réseau qui n'est pas déjà existant.

#### Lancement

Une fois les fichiers **users.csv** et **.env** modifiés accordement au projet, il est possible de lancer la création de services:

```
bash start.sh <address ip externe>/<masque>
```

Le seul argument à fournir est une adresse IP libre sur le réseau à travers lequel les utilisateurs vont accéder aux services.

Le lancement des services prend un certain temps, des messages sont affichés afin de tenir informé de la progression.

A certaines étapes, il vous sera demandé d'entrer le mot de passe administrateur afin de configurer certains aspects plus bas niveau.

#### Explication

Le script commence par créer une sous-interface dédiée pour les services du projet. A cette interface est attribuée l'adresse IP passée en argument.

Le script récupère ensuite les variables du fichier **.env** et lance la création des conteneurs avec **docker-compose**. Après le lancement des conteneurs, le script attend 30 secondes afin de laisser le temps aux services de démarrer.

La prochaine étape est la création des enregistrements DNS afin de rendre les services accessibles via un nom de domaine dont le format est <nom du projet>.iglu.lu. Un pointeur est également créé pour le serveur mail.

Les enregistrements DNS créés sont:
* mail.<nom du projet>.iglu.lu
* webmail.<nom du projet>.iglu.lu
* gitlab.<nom du projet>.iglu.lu
* cms.<nom du projet>.iglu.lu
* www.<nom du projet>.iglu.lu

Une fois les enregistrements créés, le script va alors utiliser le fichier **users.csv** pour créer ou modifier les utilisateurs.

La première sous-étape de la création est de parcourir le fichier et de créer les utilisateurs n'existant pas. Les utilisateurs existant sont modifié pour se voir attribuer une adresse mail supplémentaire correspondant à leur boîte mail par projet.

La deuxième sous-étape consiste à créer les groupes propres au projet et à y ajouter les utilisateurs correspondant. Les groupes créés sont:
 * <nom du projet>Administrators
 * <nom du projet>Users
 * <nom du projet>Externals
 * <nom du projet>Mails

Tous les utilisateurs sont créés avec le mot de passe par défaut de **Tigrou007**, il revient à l'administrateur de les changer via **phpLDAPAdmin**.

Une fois les utilisateurs créés, le script configure alors le service GitLab en modifiant le fichier de configuration afin de lui passer les arguments nécessaires pour se connecter à l'annuaire LDAP.

Lors de la première connexion, il est cependant nécessaire de créer un mot de passe administrateur. Une fois celui-ci configuré, il est possible de se connecter avec un compte utilisateur du projet.

Le script se termine avec un résumé des services disponibles et des identifiants configurés dans le fichier **.env**.

### project/script-config-gitlab-ldap.sh

Il s’agit du script comprenant les modifications à apporter au fichier de configuration générale de Gitlab afin d’ajouter l’authentification via OpenLDAP.

L’adresse de l’host hébergeant OpenLDAP y est renseignée ainsi que le distinguished name (reprenant la hiérarchie OU, DC, etc…).

## Problèmes connus et améliorations possibles

Certains services ne possèdent pas d’authentification via OpenLDAP. Par manque de temps, il n’a pas été possible d’approfondir nos recherches afin de mettre en place les configurations nécessaires.

Les authentifications avec les services LDAP ainsi que le service mail se font de manière transparente sans chiffrement. Ceci a été fait pour des raisons de temps et de complexité à forcer l'utilisation de certificats qui ne seraient pas reconnus comme de confiance par les serveurs.

Dans la solution présentée, plusieurs sgbd sont créés et ne contiennent qu’une seule base de données. Il pourrait être intéressant de réunir toutes les bases de données sur un seul sgbd et d’en faire plusieurs clusters.

De même, pour chaque projet, différents serveurs (web, de versionning, etc) sont créés. Or, il semblerait plus pertinent (et nettement moins demandant en ressources) de partager un seul de ces serveurs à tous les projets et d’en faire plusieurs clusters pour atteindre un seuil de haute disponibilité.

Les services mails présentent des comportements instables, notamment l'impossibilité d'envoyer des messages vers le monde extérieur. De plus, les serveurs de projets ne savent pas envoyer de mails au serveur mail parent (iglu.lu). Malgré tout, ce dernier arrive à envoyer des mails aux serveurs de projets individuels.

Dû au désir de centraliser les identifiants en un seul endroit, les boîtes mails multiples demandent que chaque utilisateur ait une entrée pour chaque boîte mails par projet. Ce comportement cause un dédoublement des mails reçus sur les boîtes mails de projet.

Concernant le serveur de fichiers, dû à la manière dont Windows gère les identifiants, lorsqu’un client se connecte à l'un des partages (par exemple data), il est impossible de se connecter à l'autre partage (external) sans que la cache d'identifiant de WIndows n'interfère et ne détecte plusieurs connexions simultanées. Le message d'erreurs résultant mets en garde contre l'impossibilité de se connecter à une ressource avec le même compte plus d'une fois, et ceci malgré que les identifiants pour le partage data et external sont différents.

## Conclusion

La solution présentée comprend les différents services retenus pour subvenir aux besoins de la société : OpenLDA, PowerDNS, docker MailServer, Samba, Gitlab, WordPress, Apache. La plupart des conteneurs créés ont nécessité la création d’une image personnalisée afin d’alléger les modifications à apporter dans les fichiers de configuration.

L’architecture est divisée en deux partie, l’une propre à toute l’infrastructure de la société et l’autre propre à chaque projet.

Chacune de ces parties est construite via l’exécution d’un script unique reposant sur différents fichiers.

Les principaux problèmes rencontrés ont été la difficulté de configuration afin de permettre une authentification généralisée via serveur LDAP (par manque de temps et de documentation pour certains services), la sécurité de certaines communications (textes passés en clair), la redondance de sgbd qui pourraient être regroupés, et l’instabilité des serveurs mails, 

Néanmoins, la solution présentée constitue une bonne base pour une première approche de dockerization pour une société souhaitant n’utiliser que des services open source. 
