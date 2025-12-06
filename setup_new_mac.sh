#!/bin/bash

# Script de configuration pour un nouveau Mac - Projet Modern Societies Explorer & OWID Grapher
# Usage: ./setup_new_mac.sh
# Auteur: Vincent

set -e  # Arrêter le script en cas d'erreur

echo "🚀 Configuration d'un nouveau Mac pour le projet Modern Societies Explorer & OWID Grapher"
echo "=================================================================="

# Fonction pour afficher les étapes
log_step() {
    echo ""
    echo "📋 $1"
    echo "----------------------------------------"
}

# Fonction pour vérifier si une commande existe
command_exists() {
    command -v "$1" &> /dev/null
}

# Fonction pour vérifier si un service Homebrew tourne
service_running() {
    brew services list | grep "$1" | grep -q "started"
}

# Vérifier si on est sur macOS
if [[ "$OSTYPE" != "darwin"* ]]; then
    echo "❌ Ce script est conçu pour macOS uniquement"
    exit 1
fi

# 1. Installation de Homebrew
log_step "Installation de Homebrew"
if ! command -v brew &> /dev/null; then
    echo "Installation de Homebrew..."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    
    # Ajouter Homebrew au PATH
    if [[ -f "/opt/homebrew/bin/brew" ]]; then
        echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >> ~/.zshrc
        eval "$(/opt/homebrew/bin/brew shellenv)"
    elif [[ -f "/usr/local/bin/brew" ]]; then
        echo 'eval "$(/usr/local/bin/brew shellenv)"' >> ~/.zshrc
        eval "$(/usr/local/bin/brew shellenv)"
    fi
else
    echo "✅ Homebrew déjà installé"
fi

# 2. Mise à jour de Homebrew
log_step "Mise à jour de Homebrew"
brew update

# 3. Installation des outils essentiels
log_step "Installation des outils essentiels"
brew_packages=(
    "node@22"          # Node.js version 22 (spécifiée dans le projet)
    "yarn"             # Gestionnaire de packages
    "git"              # Git (souvent déjà installé)
    "mysql@8.4"        # MySQL 8.4 (compatible avec mysql_native_password)
    "curl"             # Pour les téléchargements
    "wget"             # Utilitaire de téléchargement
)

for package in "${brew_packages[@]}"; do
    if brew list "$package" &>/dev/null; then
        echo "✅ $package déjà installé"
    else
        echo "📦 Installation de $package..."
        brew install "$package"
    fi
done

# 4. Configuration de Node.js
log_step "Configuration de Node.js"
# Lier Node 22 si nécessaire
brew link node@22 --force --overwrite

# Ajouter Node au PATH
if ! grep -q "node@22" ~/.zshrc; then
    echo 'export PATH="/opt/homebrew/opt/node@22/bin:$PATH"' >> ~/.zshrc
    export PATH="/opt/homebrew/opt/node@22/bin:$PATH"
fi

# 5. Configuration avancée de MySQL
log_step "Configuration avancée de MySQL 8.4"

# Déterminer le chemin MySQL selon l'architecture
if [[ -d "/opt/homebrew/opt/mysql@8.4" ]]; then
    MYSQL_PATH="/opt/homebrew/opt/mysql@8.4"
elif [[ -d "/usr/local/opt/mysql@8.4" ]]; then
    MYSQL_PATH="/usr/local/opt/mysql@8.4"
else
    echo "❌ MySQL@8.4 non trouvé"
    exit 1
fi

# Arrêter d'autres versions de MySQL qui pourraient tourner
for version in "mysql" "mysql@8.0" "mysql@9.0"; do
    if service_running "$version" 2>/dev/null; then
        echo "🛑 Arrêt de $version..."
        brew services stop "$version" 2>/dev/null || true
    fi
done

# Vérifier si les données MySQL existent et sont incompatibles
MYSQL_DATA_DIR="/usr/local/var/mysql"
if [[ -d "$MYSQL_DATA_DIR" ]] && [[ -f "$MYSQL_DATA_DIR/mysql.ibd" ]]; then
    echo "⚠️  Détection d'anciennes données MySQL..."
    
    # Sauvegarder les anciennes données
    if [[ ! -d "${MYSQL_DATA_DIR}_backup" ]]; then
        echo "💾 Sauvegarde des anciennes données..."
        cp -r "$MYSQL_DATA_DIR" "${MYSQL_DATA_DIR}_backup"
    fi
    
    # Supprimer les anciennes données pour éviter les conflits de version
    echo "🗑️  Suppression des données incompatibles..."
    rm -rf "$MYSQL_DATA_DIR"
    mkdir -p "$MYSQL_DATA_DIR"
    
    # Initialiser MySQL avec les nouveaux paramètres
    echo "🔧 Initialisation de MySQL@8.4..."
    "$MYSQL_PATH/bin/mysqld" --initialize-insecure --datadir="$MYSQL_DATA_DIR"
fi

# Créer le fichier de configuration MySQL pour activer mysql_native_password
echo "📝 Configuration de MySQL pour la compatibilité..."
cat > /usr/local/etc/my.cnf << EOF
[mysqld]
# Activer le plugin mysql_native_password pour la compatibilité
mysql_native_password=ON
default_authentication_plugin=mysql_native_password

# Configuration recommandée pour le développement
bind-address=127.0.0.1
port=3306
max_connections=200
innodb_buffer_pool_size=256M

# Désactiver le mode strict pour plus de flexibilité
sql_mode=''

[mysql]
default-character-set=utf8mb4

[client]
default-character-set=utf8mb4
EOF

# Démarrer MySQL@8.4
if ! service_running "mysql@8.4"; then
    echo "🚀 Démarrage de MySQL@8.4..."
    brew services start mysql@8.4
    
    # Attendre que MySQL soit prêt
    echo "⏳ Attente du démarrage de MySQL..."
    for i in {1..30}; do
        if "$MYSQL_PATH/bin/mysqladmin" ping -h localhost --silent 2>/dev/null; then
            echo "✅ MySQL est prêt !"
            break
        fi
        sleep 2
        if [[ $i -eq 30 ]]; then
            echo "❌ Timeout: MySQL n'a pas démarré"
            exit 1
        fi
    done
fi

# Ajouter MySQL au PATH
if ! grep -q "mysql@8.4" ~/.zshrc; then
    echo 'export PATH="'$MYSQL_PATH'/bin:$PATH"' >> ~/.zshrc
    export PATH="$MYSQL_PATH/bin:$PATH"
fi

# 6. Configuration SSH
log_step "Configuration SSH"
mkdir -p ~/.ssh
chmod 700 ~/.ssh

# Générer une clé SSH si elle n'existe pas
if [[ ! -f ~/.ssh/id_rsa ]]; then
    echo "Génération d'une nouvelle clé SSH..."
    ssh-keygen -t rsa -b 4096 -C "$(whoami)@$(hostname)" -f ~/.ssh/id_rsa -N ""
    echo "✅ Clé SSH générée : ~/.ssh/id_rsa"
else
    echo "✅ Clé SSH existante trouvée"
fi

# 7. Configuration Git
log_step "Configuration Git"
read -p "Entrez votre nom pour Git (ou appuyez sur Entrée pour garder la configuration actuelle): " git_name
read -p "Entrez votre email pour Git (ou appuyez sur Entrée pour garder la configuration actuelle): " git_email

if [[ -n "$git_name" ]]; then
    git config --global user.name "$git_name"
fi

if [[ -n "$git_email" ]]; then
    git config --global user.email "$git_email"
fi

# 8. Clonage des projets
log_step "Clonage des projets"
GITHUB_DIR="$HOME/Github"
mkdir -p "$GITHUB_DIR"
cd "$GITHUB_DIR"

# Cloner modern-societies-explorer
if [[ ! -d "modern-societies-explorer" ]]; then
    echo "Clonage de modern-societies-explorer..."
    git clone https://github.com/vpicouet/modern-societies-explorer.git
else
    echo "✅ modern-societies-explorer déjà cloné"
fi

# Cloner owid-grapher (votre fork)
if [[ ! -d "owid-grapher" ]]; then
    echo "Clonage de owid-grapher (votre fork)..."
    git clone https://github.com/vpicouet/owid-grapher.git
else
    echo "✅ owid-grapher déjà cloné"
    cd owid-grapher
    echo "Mise à jour du remote origin vers votre fork..."
    git remote set-url origin https://github.com/vpicouet/owid-grapher.git
    cd ..
fi

# 9. Installation des dépendances Node.js
log_step "Installation des dépendances Node.js"

# Modern Societies Explorer
if [[ -d "modern-societies-explorer" ]]; then
    cd modern-societies-explorer
    if [[ -f "package.json" ]]; then
        echo "Installation des dépendances pour modern-societies-explorer..."
        yarn install
    fi
    cd ..
fi

# OWID Grapher
if [[ -d "owid-grapher" ]]; then
    cd owid-grapher
    if [[ -f "package.json" ]]; then
        echo "Installation des dépendances pour owid-grapher..."
        yarn install
    fi
    cd ..
fi

# 10. Configuration de la base de données
log_step "Configuration de la base de données MySQL"

# Configurer le mot de passe root et créer les bases de données
echo "🔐 Configuration des utilisateurs et bases de données..."

# Définir le mot de passe root
ROOT_PASSWORD="hupinaise"
DB_PASSWORD="hupinaise"

# Sécuriser l'installation MySQL et définir le mot de passe root
"$MYSQL_PATH/bin/mysql" -u root -e "ALTER USER 'root'@'localhost' IDENTIFIED BY '$ROOT_PASSWORD';" 2>/dev/null || echo "Root password déjà configuré"

# Créer les bases de données nécessaires
echo "📊 Création des bases de données..."
"$MYSQL_PATH/bin/mysql" -u root -p"$ROOT_PASSWORD" -e "
CREATE DATABASE IF NOT EXISTS grapher;
CREATE DATABASE IF NOT EXISTS graphertest;
CREATE DATABASE IF NOT EXISTS owid;
CREATE DATABASE IF NOT EXISTS owid_test;
" 2>/dev/null

# Créer l'utilisateur vincent avec les bonnes permissions
echo "👤 Configuration de l'utilisateur 'vincent'..."
"$MYSQL_PATH/bin/mysql" -u root -p"$ROOT_PASSWORD" -e "
CREATE USER IF NOT EXISTS 'vincent'@'localhost' IDENTIFIED WITH mysql_native_password BY '$DB_PASSWORD';
GRANT ALL PRIVILEGES ON *.* TO 'vincent'@'localhost';
FLUSH PRIVILEGES;
" 2>/dev/null

# Tester la connexion avec l'utilisateur vincent
echo "🔍 Test de connexion avec l'utilisateur vincent..."
if "$MYSQL_PATH/bin/mysql" -u vincent -p"$DB_PASSWORD" -e "SHOW DATABASES;" &>/dev/null; then
    echo "✅ Connexion MySQL réussie avec l'utilisateur vincent"
else
    echo "❌ Problème de connexion avec l'utilisateur vincent"
fi

# 11. Variables d'environnement
log_step "Configuration des variables d'environnement"
cd "$GITHUB_DIR/owid-grapher"

# Copier le fichier d'exemple d'environnement
if [[ -f ".env.example-full" ]] && [[ ! -f ".env" ]]; then
    cp .env.example-full .env
    echo "✅ Fichier .env créé à partir de .env.example-full"
    echo "⚠️  Vous devrez peut-être modifier les variables dans .env"
fi

# 12. Installation et configuration de Docker
log_step "Installation et configuration de Docker"

# Vérifier si Docker Desktop est installé
if ! command_exists docker || ! docker --version &>/dev/null; then
    echo "📦 Installation de Docker Desktop..."
    brew install --cask docker
    echo "🚀 Lancement de Docker Desktop..."
    open -a Docker
    echo "⏳ Attente du démarrage de Docker Desktop (peut prendre 1-2 minutes)..."
    
    # Attendre que Docker soit prêt
    for i in {1..60}; do
        if docker --version &>/dev/null; then
            echo "✅ Docker Desktop est prêt !"
            break
        fi
        sleep 5
        if [[ $i -eq 60 ]]; then
            echo "⚠️  Docker Desktop prend du temps à démarrer. Continuez manuellement."
        fi
    done
else
    echo "✅ Docker Desktop déjà installé"
    # Vérifier que Docker fonctionne
    if ! docker ps &>/dev/null; then
        echo "🚀 Démarrage de Docker Desktop..."
        open -a Docker
        echo "⏳ Attente que Docker soit prêt..."
        for i in {1..30}; do
            if docker ps &>/dev/null; then
                echo "✅ Docker est prêt !"
                break
            fi
            sleep 2
        done
    fi
fi

# 13. Vérification finale des installations
log_step "Vérification finale des installations"
echo "Versions installées :"
"$MYSQL_PATH/bin/mysql" --version 2>/dev/null && echo "✅ MySQL installé" || echo "❌ Problème avec MySQL"
node --version 2>/dev/null && echo "✅ Node.js installé" || echo "❌ Problème avec Node.js"
npm --version 2>/dev/null && echo "✅ NPM installé" || echo "❌ Problème avec NPM"
yarn --version 2>/dev/null && echo "✅ Yarn installé" || echo "❌ Problème avec Yarn"
git --version 2>/dev/null && echo "✅ Git installé" || echo "❌ Problème avec Git"
docker --version 2>/dev/null && echo "✅ Docker installé" || echo "❌ Problème avec Docker"

# Test de la stack complète
echo ""
echo "🧪 Tests de la configuration complète :"
if "$MYSQL_PATH/bin/mysql" -u vincent -p"$DB_PASSWORD" -e "SELECT 'MySQL OK' as status;" &>/dev/null; then
    echo "✅ Connexion MySQL fonctionnelle"
else
    echo "❌ Problème de connexion MySQL"
fi

if docker ps &>/dev/null; then
    echo "✅ Docker fonctionnel"
else
    echo "❌ Docker non fonctionnel"
fi

# 14. Instructions finales
log_step "Instructions finales"
echo "🎉 Configuration terminée !"
echo ""
echo "📝 Prochaines étapes :"
echo "1. Redémarrez votre terminal ou exécutez : source ~/.zshrc"
echo "2. Vérifiez les variables d'environnement dans $GITHUB_DIR/owid-grapher/.env"
echo ""
echo "🚀 Pour démarrer les projets :"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📊 Modern Societies Explorer :"
echo "   cd $GITHUB_DIR/modern-societies-explorer"
echo "   yarn dev"
echo "   ➡️  http://localhost:3030"
echo ""
echo "📈 OWID Grapher (stack complète) :"
echo "   cd $GITHUB_DIR/owid-grapher"
echo "   make up                    # Lance tous les services"
echo "   ➡️  http://localhost:3030  # Interface admin"
echo ""
echo "🧪 Tests rapides :"
echo "   make test                  # Tests unitaires"
echo "   yarn typecheck            # Vérification TypeScript"
echo ""
echo "🛠️  Commandes utiles :"
echo "   make migrate              # Migrations de base de données"
echo "   make down                 # Arrêter tous les services"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "🔐 Configuration MySQL :"
echo "   Utilisateur : vincent"
echo "   Mot de passe : hupinaise"
echo "   Bases créées : grapher, graphertest, owid, owid_test"
echo ""
echo "🔑 Votre clé SSH publique (à ajouter sur GitHub) :"
echo "----------------------------------------"
cat ~/.ssh/id_rsa.pub 2>/dev/null || echo "❌ Erreur lors de la lecture de la clé SSH"
echo "----------------------------------------"
echo ""
echo "🌐 Ajoutez cette clé à votre compte GitHub : https://github.com/settings/keys"
echo ""
echo "📋 En cas de problème :"
echo "   • MySQL : brew services restart mysql@8.4"
echo "   • Docker : relancer Docker Desktop"
echo "   • Node : vérifier le PATH dans ~/.zshrc"
echo ""
echo "✅ Script terminé avec succès ! Votre environnement de développement est prêt."