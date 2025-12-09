#!/bin/bash

# Script pour finaliser la configuration sur l'ordinateur distant
echo "🔧 Finalisation de la configuration sur l'ordinateur distant..."

# Ajouter les PATHs au ~/.zshrc s'ils n'y sont pas déjà
echo "📋 Configuration des PATHs..."

# Vérifier et ajouter Homebrew au PATH
if ! grep -q "/opt/homebrew/bin" ~/.zshrc && ! grep -q "/usr/local/bin/brew" ~/.zshrc; then
    echo 'export PATH="/opt/homebrew/bin:/usr/local/bin:$PATH"' >> ~/.zshrc
fi

# Vérifier et ajouter MySQL au PATH
if ! grep -q "mysql@8.0" ~/.zshrc; then
    echo 'export PATH="/usr/local/opt/mysql@8.0/bin:$PATH"' >> ~/.zshrc
fi

# Vérifier et ajouter Node.js au PATH
if ! grep -q "node@22" ~/.zshrc; then
    echo 'export PATH="/usr/local/opt/node@22/bin:$PATH"' >> ~/.zshrc
fi

# Recharger le shell
source ~/.zshrc

# Vérifier les installations
echo "📋 Vérification des installations..."
which brew && echo "✅ Homebrew trouvé" || echo "❌ Homebrew non trouvé"
which node && echo "✅ Node.js trouvé: $(node --version)" || echo "❌ Node.js non trouvé"
which mysql && echo "✅ MySQL trouvé" || echo "❌ MySQL non trouvé"

# Démarrer MySQL
echo "📋 Démarrage de MySQL..."
brew services start mysql@8.0

# Attendre que MySQL soit prêt
sleep 10

# Créer les bases de données
echo "📋 Création des bases de données..."
mysql -u root -e "CREATE DATABASE IF NOT EXISTS owid;" 2>/dev/null && echo "✅ Base owid créée" || echo "❌ Erreur création base owid"
mysql -u root -e "CREATE DATABASE IF NOT EXISTS owid_test;" 2>/dev/null && echo "✅ Base owid_test créée" || echo "❌ Erreur création base owid_test"

# Vérifier le fichier .env
echo "📋 Vérification du fichier .env..."
cd /Users/Vincent/Github/owid-grapher

if [[ ! -f .env ]]; then
    echo "Copie de .env.example-full vers .env..."
    cp .env.example-full .env
fi

# Ajouter les variables manquantes au .env s'il le faut
if ! grep -q "GRAPHER_TEST_DB_NAME" .env; then
    echo "GRAPHER_TEST_DB_NAME=owid_test" >> .env
fi

# Vérifier si Docker est installé
echo "📋 Vérification de Docker..."
if command -v docker >/dev/null 2>&1; then
    echo "✅ Docker installé: $(docker --version)"
else
    echo "❌ Docker non installé - installation..."
    brew install --cask docker
fi

# Instructions finales
echo ""
echo "🎉 Configuration terminée !"
echo ""
echo "📝 Pour tester l'explorer :"
echo "cd /Users/Vincent/Github/modern-societies-explorer"
echo "yarn dev"
echo ""
echo "📝 Pour tester owid-grapher :"
echo "cd /Users/Vincent/Github/owid-grapher"
echo "make up"
echo ""
echo "🔄 Redémarrez votre terminal pour que tous les changements de PATH prennent effet."