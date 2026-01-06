# Deployment Guide - GitHub Actions to Scaleway

## Configuration des Secrets GitHub

Pour que le CI/CD fonctionne, vous devez ajouter ces secrets dans votre repo GitHub:

1. Allez sur: `https://github.com/vpicouet/owid-grapher/settings/secrets/actions`

2. Ajoutez ces secrets:

### SCALEWAY_SECRET_KEY
Votre clé secrète Scaleway API.

**Comment l'obtenir:**
```bash
# Depuis votre terminal
scw config get secret-key
```

Ou créez une nouvelle clé: https://console.scaleway.com/iam/api-keys

### SCALEWAY_ORGANIZATION_ID
```bash
scw config get default-organization-id
```

### SCALEWAY_PROJECT_ID
```bash
scw config get default-project-id
```

## Workflow de Déploiement

Le workflow se déclenche automatiquement à chaque push sur `master`:

1. ✅ Build de l'image Docker (`Dockerfile.scaleway`)
2. ✅ Push vers Scaleway Registry
3. ✅ Déploiement sur Scaleway Container
4. ✅ Health check (attend HTTP 200)
5. ⚠️ Si échec → Scaleway garde automatiquement l'ancienne version

## Test manuel

Pour tester le workflow sans attendre un push:

```bash
# Depuis votre machine
cd /Users/Vincent/Github/owid-grapher
git add .
git commit -m "Test CI/CD"
git push origin master
```

Puis surveillez: https://github.com/vpicouet/owid-grapher/actions

## Configuration Railway (Alternative)

Le fichier `railway.json` est configuré pour utiliser le même `Dockerfile.scaleway`.

Railway buildera et déploiera automatiquement depuis GitHub quand vous pushez.

## Rollback Manuel

Si besoin de revenir en arrière:

```bash
# Lister les images
scw registry image list namespace-id=526af5c2-f1b3-4a76-89fe-a7f7e68902fd

# Déployer une version spécifique
scw container container update 51b0f9bd-d7a1-4066-a605-727b8b694b53 \
  registry-image=rg.fr-par.scw.cloud/modern-societies-observatory/owid-grapher:<TAG>
```

## URLs de Production

- **Scaleway**: https://msocontainersvu6ld2gy-owid-grapher.functions.fnc.fr-par.scw.cloud
- **Railway**: https://owid-grapher-production.up.railway.app

## Monitoring

- **GitHub Actions**: https://github.com/vpicouet/owid-grapher/actions
- **Scaleway Console**: https://console.scaleway.com/containers/namespaces
- **Railway Dashboard**: https://railway.app/dashboard
