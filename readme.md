# OmsyServerStore

Collection de scripts shell pour installer une pile serveur web complète (web, base de données, PHP, cache) en la **compilant depuis les sources**, dans un répertoire isolé du système.

> ⚠️ Projet en cours de développement (version 0.1). Certaines étapes d'installation ne sont pas encore activées.

## Contenu

| Script | Rôle |
|---|---|
| `omsy-0.1.sh` | Script principal : prépare le système et lance les installations |
| `common.sh` | Fonctions et variables communes (ex. `PATH_ROOT`, téléchargement des sources) |
| `model.sh` | Modèle pour créer un nouveau script d'installation |
| `openssl-3.5.sh` | OpenSSL 3.5 |
| `mysql-8.4.sh` | MySQL 8.4 |
| `apache-2.4.sh` | Apache HTTP Server 2.4 |
| `nginx-1.28.sh` | Nginx 1.28 |
| `php-8.5.sh` | PHP 8.5 |
| `redis-7.2.sh` | Redis 7.2 |

## Systèmes supportés

- Ubuntu
- macOS (avec Homebrew)

## Ce que fait `omsy-0.1.sh`

1. Détecte le système (macOS ou Ubuntu).
2. Installe les outils de compilation et les bibliothèques nécessaires.
3. Crée l'utilisateur et le groupe système `omsy` (sans accès shell) pour exécuter les services.
4. Télécharge les sources des bibliothèques requises (apr, apr-util, pcre2, nghttp2, zlib, extension PHP redis).
5. Crée l'arborescence dans `PATH_ROOT` :
   ```
   PATH_ROOT/
   ├── sys/        (bin, lib, module)
   ├── share/      (config, logs, empty)
   └── usr/
   ```
6. Lance l'installation des composants (OpenSSL, MySQL, etc.).

## Installation

```bash
git clone https://github.com/is-omini/OmsyServerStore.git
cd OmsyServerStore
sudo bash omsy-0.1.sh
```

Les droits administrateur sont nécessaires (création d'utilisateur, installation de paquets, écriture dans `PATH_ROOT`).

## Avancement

- [x] Préparation du système et dépendances
- [x] OpenSSL
- [x] MySQL
- [ ] Nginx
- [ ] Apache
- [ ] PHP
- [ ] Redis
- [ ] phpMyAdmin, Node.js, vsftpd

## Avertissement

Ces scripts modifient le système (paquets, utilisateurs, fichiers). Lisez-les avant de les exécuter et testez-les d'abord sur une machine virtuelle ou un serveur de test.