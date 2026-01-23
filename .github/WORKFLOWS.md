# GitHub Actions Workflows - Documentation

Ce document décrit tous les workflows CI/CD configurés dans `.github/workflows/`.

## 📊 Vue d'ensemble

| Workflow | Déclencheur | Status | But |
|----------|-------------|--------|-----|
| `ci.yml` | Push, PR | ✅ Actif | Tests, linting, typecheck |
| `deploy-production.yml` | Push sur `modern-societies-customizations` | ✅ Actif | Build Docker + Deploy test/prod |
| `prettify.yml` | Push/PR sur `master` | ⚠️ Fork uniquement | Auto-format le code |
| `publish-ghcr.yml` | Push sur `modern-societies-customizations` | ⚠️ Obsolète | Build Docker (Dockerfile.scaleway) |
| `deploy-scaleway.yml` | Push sur `master` | ⚠️ Obsolète | Deploy sur Scaleway |
| `buildkite.yml` | PR fermée | ❌ OWID uniquement | Détruit staging Buildkite |
| `stale.yml` | Cron quotidien | ❌ OWID uniquement | Ferme issues/PRs inactives |
| `todo-checker.yml` | PR | ❌ OWID uniquement | Vérifie TODOs dans code |
| `codeql-analysis.yml` | Push/PR | ❌ OWID uniquement | Analyse sécurité CodeQL |
| `project-automations.yml` | Issues/PR | ❌ OWID uniquement | Automation GitHub Projects |
| `auto-author-assign.yml` | PR | ❌ OWID uniquement | Auto-assign auteur à PR |
| `sentry.yml` | Push sur `master` | ❌ OWID uniquement | Crée release Sentry |
| `check-default-grapher-config.yml` | Push/PR | ❌ OWID uniquement | Vérifie config grapher |
| `update-regions.yml` | Cron mensuel | ❌ OWID uniquement | MAJ données régions |
| `sync-grapher-schema-to-digital-ocean.yml` | Push sur `master` | ❌ OWID uniquement | Sync schéma DB |

---

## ✅ Workflows actifs (Fork MSO)

### 1. `ci.yml` - Tests et Validation

**Déclencheur**: Tous les push et pull requests

**Jobs**:
- `test-db`: Tests base de données (avec MySQL)
- `test`: Tests unitaires (vitest)
- `typecheck`: Vérification TypeScript
- `prettier`: Vérification formatage code
- `eslint`: Linting (max 0 warnings)
- ~~`bundlemon`~~: DÉSACTIVÉ (app GitHub non installée sur fork)

**Durée**: ~10-15 minutes

**Utilité**: Valide que le code compile, les tests passent, et le style est correct avant merge.

---

### 2. `deploy-production.yml` - Build et Déploiement Modern Societies Observatory

**Déclencheur**:
- Push sur `modern-societies-customizations` (auto)
- `workflow_dispatch` (manuel)

**Jobs**:
1. **`build`**: Build image Docker avec webpack assets
   - Utilise `Dockerfile.production`
   - Compile `yarn buildViteSite` + `yarn buildViteAdmin` sur Linux
   - Push vers `ghcr.io/vpicouet/owid-grapher:latest`
   - Durée: ~10-15 min (première fois), ~5 min (avec cache)

2. **`deploy-test`**: DÉSACTIVÉ (`if: false`)
   - SSH vers `64.23.242.13` (observatory.picouet.fr)
   - `git pull` + restart service
   - Health check

3. **`deploy-prod`**: DÉSACTIVÉ (`if: false`)
   - SSH vers `159.65.56.172` (mso.picouet.fr)
   - `git pull` + restart service
   - Health check

**Documentation complète**: `.github/workflows/README-DEPLOYMENT.md`

**Status**: Build actif, déploiements désactivés temporairement.

---

## ⚠️ Workflows partiellement actifs

### 3. `prettify.yml` - Auto-Format Code

**Déclencheur**: Push ou PR sur `master`

**Fonction**:
- Execute `yarn fixPrettierAll` sur le code
- Commit automatiquement les corrections de style
- Commit message: "🤖 style: prettify code"

**Note**: Sur le fork, s'exécute sur `master` (pas `modern-societies-customizations`), donc peu utilisé.

---

### 4. `publish-ghcr.yml` - Build Docker Image (Legacy)

**Déclencheur**: Push sur `modern-societies-customizations`

**Fonction**:
- Build `Dockerfile.scaleway` (⚠️ PAS Dockerfile.production)
- Push vers `ghcr.io/vpicouet/owid-grapher:latest`

**Status**: ⚠️ **OBSOLÈTE** - Remplacé par `deploy-production.yml`

**Action recommandée**: Désactiver ce workflow car il build l'ancien Dockerfile.scaleway qui ne compile pas les webpack assets.

---

### 5. `deploy-scaleway.yml` - Déploiement Scaleway (Legacy)

**Déclencheur**: Push sur `master`

**Fonction**: Déploie sur Scaleway Container Registry

**Status**: ⚠️ **OBSOLÈTE** - Documentation dans `.github/DEPLOYMENT.md`

**Action recommandée**: Désactiver ou supprimer si Scaleway n'est plus utilisé.

---

## ❌ Workflows OWID uniquement (Non pertinents pour le fork)

Ces workflows fonctionnent pour OWID mais nécessitent des secrets, tokens, ou infra OWID non disponibles sur le fork.

### 6. `buildkite.yml` - Nettoyage Staging Buildkite

**Déclencheur**: Quand une PR est fermée

**Fonction**: Détruit l'environnement de staging Buildkite associé à la branche de la PR

**Requis**: `BUILDKITE_API_ACCESS_TOKEN` (secret OWID)

---

### 7. `stale.yml` - Gestion Issues/PRs Inactives

**Déclencheur**: Cron quotidien à 7h UTC

**Fonction**:
- Marque les issues inactives depuis 120 jours comme "stale"
- Ferme après 30 jours supplémentaires
- Marque les PRs inactives depuis 14 jours comme "stale"
- Ferme après 3 jours supplémentaires

**Exemptions**: Labels `pinned`, `security`, `external-contributor`

---

### 8. `todo-checker.yml` - Vérification TODOs

**Déclencheur**: PR (sauf drafts)

**Fonction**: Scanne le code pour vérifier que tous les TODOs sont trackés/résolus avant merge

---

### 9. `codeql-analysis.yml` - Analyse de Sécurité

**Déclencheur**: Push, PR, cron hebdomadaire

**Fonction**: Analyse statique du code pour détecter vulnérabilités de sécurité (injection SQL, XSS, etc.)

---

### 10. `project-automations.yml` - Automation GitHub Projects

**Déclencheur**: Création/fermeture issues, ouverture/merge PR

**Fonction**: Ajoute automatiquement issues/PRs au GitHub Project board OWID

---

### 11. `auto-author-assign.yml` - Auto-Assignment PRs

**Déclencheur**: Ouverture PR

**Fonction**: Assigne automatiquement l'auteur de la PR comme "assignee"

---

### 12. `sentry.yml` - Releases Sentry

**Déclencheur**: Push sur `master`

**Fonction**: Crée une release Sentry pour tracking des erreurs en production

**Requis**: `SENTRY_AUTH_TOKEN`, `SENTRY_ORG`, `SENTRY_PROJECT`

---

### 13. `check-default-grapher-config.yml` - Validation Config Grapher

**Déclencheur**: Push, PR

**Fonction**: Vérifie que la config par défaut des graphers est valide

---

### 14. `update-regions.yml` - Mise à Jour Données Régions

**Déclencheur**: Cron mensuel (1er du mois)

**Fonction**: Télécharge et met à jour les données géographiques (régions, pays, etc.)

---

### 15. `sync-grapher-schema-to-digital-ocean.yml` - Sync Schéma DB

**Déclencheur**: Push sur `master`

**Fonction**: Synchronise le schéma de la base de données vers DigitalOcean

**Requis**: Secrets DigitalOcean

---

## 🔧 Actions Recommandées pour le Fork

### À désactiver/supprimer:

1. **`publish-ghcr.yml`**: Remplacé par `deploy-production.yml`
2. **`deploy-scaleway.yml`**: Si Scaleway n'est plus utilisé
3. **`buildkite.yml`**: Infra OWID uniquement
4. **`stale.yml`**: Gestion repo OWID
5. **`sentry.yml`**: Monitoring OWID
6. **`sync-grapher-schema-to-digital-ocean.yml`**: Infra OWID

### À garder:

- ✅ `ci.yml`: Tests essentiels
- ✅ `deploy-production.yml`: Workflow de déploiement MSO
- ⚠️ `prettify.yml`: Utile mais configurer pour `modern-societies-customizations`

### À configurer:

1. **Réactiver les déploiements** dans `deploy-production.yml` quand le build Docker fonctionne:
   ```yaml
   deploy-test:
     if: github.event_name == 'push'  # Changer if: false

   deploy-prod:
     if: github.event_name == 'workflow_dispatch'  # Changer if: false
   ```

2. **Configurer SSH_PRIVATE_KEY** dans GitHub Secrets pour les déploiements

3. **Désactiver `prettify.yml` sur `master`** ou le configurer pour `modern-societies-customizations`

---

## 📚 Documentation Connexe

- **Déploiement production**: `.github/workflows/README-DEPLOYMENT.md`
- **Déploiement Scaleway**: `.github/DEPLOYMENT.md`
- **Fork management**: `/Users/Vincent/Github/modern-societies-explorer/owid/FORK_MANAGEMENT.md`

---

**Dernière mise à jour**: 2026-01-23
