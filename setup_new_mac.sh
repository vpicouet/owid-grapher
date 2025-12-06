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
    "mysql@8.0"        # MySQL 8.0 (base de données du projet)
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

# 5. Configuration de MySQL
log_step "Configuration de MySQL 8.0"
# Démarrer MySQL
brew services start mysql@8.0

# Ajouter MySQL au PATH
if ! grep -q "mysql@8.0" ~/.zshrc; then
    echo 'export PATH="/opt/homebrew/opt/mysql@8.0/bin:$PATH"' >> ~/.zshrc
    export PATH="/opt/homebrew/opt/mysql@8.0/bin:$PATH"
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
echo "Création de la base de données OWID..."

# Attendre que MySQL soit prêt
sleep 5

mysql -u root -e "CREATE DATABASE IF NOT EXISTS owid;" 2>/dev/null || echo "⚠️  Erreur lors de la création de la base de données. Vous devrez peut-être configurer MySQL manuellement."

# 11. Variables d'environnement
log_step "Configuration des variables d'environnement"
cd "$GITHUB_DIR/owid-grapher"

# Copier le fichier d'exemple d'environnement
if [[ -f ".env.example-full" ]] && [[ ! -f ".env" ]]; then
    cp .env.example-full .env
    echo "✅ Fichier .env créé à partir de .env.example-full"
    echo "⚠️  Vous devrez peut-être modifier les variables dans .env"
fi

# 12. Vérification des installations
log_step "Vérification des installations"
echo "Versions installées :"
node --version 2>/dev/null && echo "✅ Node.js installé" || echo "❌ Problème avec Node.js"
npm --version 2>/dev/null && echo "✅ NPM installé" || echo "❌ Problème avec NPM"
yarn --version 2>/dev/null && echo "✅ Yarn installé" || echo "❌ Problème avec Yarn"
mysql --version 2>/dev/null && echo "✅ MySQL installé" || echo "❌ Problème avec MySQL"
git --version 2>/dev/null && echo "✅ Git installé" || echo "❌ Problème avec Git"

# 13. Instructions finales
log_step "Instructions finales"
echo "🎉 Configuration terminée !"
echo ""
echo "📝 Prochaines étapes :"
echo "1. Redémarrez votre terminal ou exécutez : source ~/.zshrc"
echo "2. Vérifiez les variables d'environnement dans $GITHUB_DIR/owid-grapher/.env"
echo "3. Pour démarrer les projets :"
echo "   - Modern Societies Explorer : cd $GITHUB_DIR/modern-societies-explorer && yarn dev"
echo "   - OWID Grapher : cd $GITHUB_DIR/owid-grapher && yarn dev"
echo ""
echo "🔑 Votre clé SSH publique (à ajouter sur GitHub) :"
echo "----------------------------------------"
cat ~/.ssh/id_rsa.pub 2>/dev/null || echo "❌ Erreur lors de la lecture de la clé SSH"
echo "----------------------------------------"
echo ""
echo "🌐 Ajoutez cette clé à votre compte GitHub : https://github.com/settings/keys"
echo ""
echo "✅ Script terminé avec succès !"