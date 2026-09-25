#!/bin/bash

# Script de diagnostic et configuration partielle pour un nouveau Mac
# Usage: ./setup_new_mac_no_sudo.sh
# Note: Certaines étapes nécessiteront sudo à exécuter manuellement

set -e  # Arrêter le script en cas d'erreur

echo "🔍 Diagnostic de l'environnement Mac pour le projet Modern Societies Explorer & OWID Grapher"
echo "=================================================================="

# Fonction pour afficher les étapes
log_step() {
    echo ""
    echo "📋 $1"
    echo "----------------------------------------"
}

# 1. Vérification de l'environnement actuel
log_step "Vérification de l'environnement actuel"

echo "Système d'exploitation : $(uname -s)"
echo "Architecture : $(uname -m)"

# Vérifier les outils existants
echo ""
echo "🔍 Outils déjà installés :"
command -v brew >/dev/null 2>&1 && echo "✅ Homebrew : $(brew --version | head -1)" || echo "❌ Homebrew : non installé"
command -v node >/dev/null 2>&1 && echo "✅ Node.js : $(node --version)" || echo "❌ Node.js : non installé"
command -v npm >/dev/null 2>&1 && echo "✅ NPM : $(npm --version)" || echo "❌ NPM : non installé"  
command -v yarn >/dev/null 2>&1 && echo "✅ Yarn : $(yarn --version)" || echo "❌ Yarn : non installé"
command -v mysql >/dev/null 2>&1 && echo "✅ MySQL : $(mysql --version)" || echo "❌ MySQL : non installé"
command -v git >/dev/null 2>&1 && echo "✅ Git : $(git --version)" || echo "❌ Git : non installé"

# 2. Vérification des projets
log_step "Vérification des projets"
GITHUB_DIR="$HOME/Github"

if [[ -d "$GITHUB_DIR/modern-societies-explorer" ]]; then
    echo "✅ modern-societies-explorer trouvé"
    cd "$GITHUB_DIR/modern-societies-explorer"
    echo "  - Branche actuelle : $(git branch --show-current)"
    echo "  - Remote : $(git remote get-url origin)"
    echo "  - Status : $(git status --porcelain | wc -l) fichiers modifiés"
else
    echo "❌ modern-societies-explorer : non trouvé"
fi

if [[ -d "$GITHUB_DIR/owid-grapher" ]]; then
    echo "✅ owid-grapher trouvé"
    cd "$GITHUB_DIR/owid-grapher"
    echo "  - Branche actuelle : $(git branch --show-current)"
    echo "  - Remote : $(git remote get-url origin)"
    echo "  - Status : $(git status --porcelain | wc -l) fichiers modifiés"
else
    echo "❌ owid-grapher : non trouvé"
fi

# 3. Vérification SSH
log_step "Vérification SSH"
if [[ -f ~/.ssh/id_rsa ]]; then
    echo "✅ Clé SSH privée trouvée : ~/.ssh/id_rsa"
else
    echo "❌ Clé SSH privée non trouvée"
fi

if [[ -f ~/.ssh/id_rsa.pub ]]; then
    echo "✅ Clé SSH publique trouvée : ~/.ssh/id_rsa.pub"
else
    echo "❌ Clé SSH publique non trouvée"
fi

# 4. Test des dépendances Node si disponible
if command -v node >/dev/null 2>&1 && command -v yarn >/dev/null 2>&1; then
    log_step "Test des dépendances Node.js"
    
    if [[ -d "$GITHUB_DIR/owid-grapher" ]]; then
        cd "$GITHUB_DIR/owid-grapher"
        if [[ -f "package.json" ]]; then
            echo "Package.json trouvé, vérification des dépendances..."
            if [[ -d "node_modules" ]]; then
                echo "✅ node_modules existe"
            else
                echo "❌ node_modules n'existe pas"
                echo "💡 Essai d'installation des dépendances..."
                yarn install 2>&1 || echo "❌ Erreur lors de l'installation"
            fi
        fi
    fi
fi

# 5. Test de la base de données
log_step "Vérification de la base de données"
if command -v mysql >/dev/null 2>&1; then
    echo "✅ MySQL installé"
    
    # Tester la connexion
    if mysql -u root -e "SHOW DATABASES;" 2>/dev/null; then
        echo "✅ Connexion MySQL réussie"
        mysql -u root -e "SHOW DATABASES;" 2>/dev/null | grep -q "owid" && echo "✅ Base de données 'owid' trouvée" || echo "❌ Base de données 'owid' non trouvée"
    else
        echo "❌ Impossible de se connecter à MySQL"
    fi
else
    echo "❌ MySQL non installé"
fi

# 6. Instructions pour les étapes manuelles
log_step "Instructions pour les étapes manuelles nécessaires"

echo ""
echo "🛠️  ÉTAPES À EFFECTUER MANUELLEMENT :"
echo ""

if ! command -v brew >/dev/null 2>&1; then
    echo "1️⃣  Installer Homebrew :"
    echo "   /bin/bash -c \"\$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)\""
    echo ""
fi

if ! command -v node >/dev/null 2>&1; then
    echo "2️⃣  Installer Node.js via Homebrew :"
    echo "   brew install node@22"
    echo "   brew link node@22 --force --overwrite"
    echo ""
fi

if ! command -v yarn >/dev/null 2>&1; then
    echo "3️⃣  Installer Yarn :"
    echo "   brew install yarn"
    echo ""
fi

if ! command -v mysql >/dev/null 2>&1; then
    echo "4️⃣  Installer MySQL :"
    echo "   brew install mysql@8.0"
    echo "   brew services start mysql@8.0"
    echo "   mysql -u root -e \"CREATE DATABASE IF NOT EXISTS owid;\""
    echo ""
fi

echo "5️⃣  Configurer les variables d'environnement :"
echo "   cd $GITHUB_DIR/owid-grapher"
echo "   cp .env.example-full .env"
echo "   # Modifier .env selon vos besoins"
echo ""

echo "6️⃣  Installer les dépendances :"
echo "   cd $GITHUB_DIR/owid-grapher && yarn install"
echo "   cd $GITHUB_DIR/modern-societies-explorer && yarn install"
echo ""

echo "7️⃣  Tester le lancement :"
echo "   cd $GITHUB_DIR/modern-societies-explorer && yarn dev"
echo ""

echo "✅ Diagnostic terminé ! Suivez les instructions ci-dessus pour compléter l'installation."