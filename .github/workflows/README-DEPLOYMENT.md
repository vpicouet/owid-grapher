# 🚀 Deployment Workflow for Modern Societies Observatory

This document explains the automated CI/CD workflow for building and deploying the OWID Grapher fork.

## 📋 Workflow Overview

**File**: `deploy-production.yml`

**Triggers**:
- ✅ **Automatic**: Every push to `modern-societies-customizations` → Builds image + Deploys to TEST
- 🔘 **Manual**: Workflow dispatch → Builds image + Deploys to TEST + Deploys to PROD (requires approval)

**Jobs**:
1. **Build**: Compiles webpack assets on Linux (resolves Mac→Linux incompatibility)
2. **Deploy Test**: Auto-deploys to `observatory.picouet.fr` (64.23.242.13)
3. **Deploy Prod**: Manual deploy to `mso.picouet.fr` (159.65.56.172) with approval

---

## ⚙️ Setup Instructions (One-Time)

### Step 1: Generate SSH Key for GitHub Actions

```bash
# On your local machine
cd ~/.ssh

# Generate a dedicated key for GitHub Actions
ssh-keygen -t ed25519 -C "github-actions-deploy" -f github-actions-deploy

# This creates:
# - github-actions-deploy (private key) → Goes to GitHub Secrets
# - github-actions-deploy.pub (public key) → Goes to servers
```

### Step 2: Copy Public Key to Servers

```bash
# Copy to test server
ssh-copy-id -i ~/.ssh/github-actions-deploy.pub root@64.23.242.13

# Copy to production server
ssh-copy-id -i ~/.ssh/github-actions-deploy.pub root@159.65.56.172

# Verify connection works
ssh -i ~/.ssh/github-actions-deploy root@64.23.242.13 'echo "Test server OK"'
ssh -i ~/.ssh/github-actions-deploy root@159.65.56.172 'echo "Prod server OK"'
```

### Step 3: Add Private Key to GitHub Secrets

```bash
# Display the PRIVATE key
cat ~/.ssh/github-actions-deploy
```

1. Go to: https://github.com/vpicouet/owid-grapher/settings/secrets/actions
2. Click **"New repository secret"**
3. Name: `SSH_PRIVATE_KEY`
4. Value: Paste the entire content of the private key (including `-----BEGIN` and `-----END` lines)
5. Click **"Add secret"**

### Step 4: Configure GitHub Environments (Optional but Recommended)

For manual approval on production deploys:

1. Go to: https://github.com/vpicouet/owid-grapher/settings/environments
2. Create environment: `production`
3. Enable: **"Required reviewers"**
4. Add yourself as reviewer
5. Save

Now production deploys will require your manual approval.

---

## 🔄 How to Use

### Deploy to Test (Automatic)

Just push your code:

```bash
cd ~/Github/owid-grapher

# Make changes
vim packages/@ourworldindata/explorer/src/Explorer.tsx

# Commit and push
git add -A
git commit -m "Update explorer"
git push origin modern-societies-customizations

# GitHub Actions will automatically:
# 1. Build Docker image with webpack assets (on Linux)
# 2. Push image to ghcr.io/vpicouet/owid-grapher:latest
# 3. Deploy to test server
# 4. Run health checks
# 5. Report success/failure
```

Watch progress: https://github.com/vpicouet/owid-grapher/actions

### Deploy to Production (Manual)

1. Go to: https://github.com/vpicouet/owid-grapher/actions/workflows/deploy-production.yml
2. Click **"Run workflow"**
3. Select branch: `modern-societies-customizations`
4. Click **"Run workflow"**
5. If you configured approval: Approve the production deployment when prompted

---

## 📊 Workflow Details

### Build Job

- **Runs on**: Ubuntu (Linux) - Resolves Mac→Linux incompatibility
- **Duration**: ~10-15 minutes (first time), ~5 minutes (with cache)
- **Output**: Docker image at `ghcr.io/vpicouet/owid-grapher:latest`

**What it does**:
1. Checkout code
2. Setup Docker Buildx
3. Build Dockerfile.production (multi-stage):
   - Stage 1: Install deps + Build webpack assets (`yarn buildViteSite`, `yarn buildViteAdmin`)
   - Stage 2: Copy built assets to slim production image
4. Push to GitHub Container Registry

### Deploy Test Job

- **Runs on**: Test server `64.23.242.13`
- **Trigger**: Automatically after build succeeds
- **Duration**: ~1 minute

**What it does**:
1. SSH to test server
2. `git pull` latest code
3. Restart OWID service
4. Wait 45 seconds
5. Health check: `curl https://observatory.picouet.fr`
6. Report success/failure

### Deploy Prod Job

- **Runs on**: Production server `159.65.56.172`
- **Trigger**: Manual only (workflow_dispatch)
- **Duration**: ~1 minute
- **Requires**: Manual approval if environment protection enabled

**What it does**:
1. SSH to prod server
2. `git pull` latest code
3. Restart OWID service
4. Wait 45 seconds
5. Health check: `curl https://mso.picouet.fr`
6. Report success/failure

---

## 🐛 Troubleshooting

### Build Fails: "yarn buildViteSite failed"

**Cause**: Syntax error or dependency issue in code.

**Solution**:
1. Check GitHub Actions logs for error details
2. Fix the code locally
3. Push again

### Deploy Fails: "Connection refused"

**Cause**: SSH key not configured or server unreachable.

**Solution**:
1. Verify SSH key in GitHub Secrets: https://github.com/vpicouet/owid-grapher/settings/secrets/actions
2. Test SSH manually: `ssh -i ~/.ssh/github-actions-deploy root@64.23.242.13`
3. Check server is online: `ping 64.23.242.13`

### Health Check Fails: "HTTP 502 Bad Gateway"

**Cause**: Service didn't start properly.

**Solution**:
1. SSH to server: `ssh root@64.23.242.13`
2. Check logs: `tail -100 /tmp/owid-prod.log`
3. Check service: `systemctl status owid-prod` or `ps aux | grep startAdminServer`
4. Manual restart: `systemctl restart owid-prod`

### Deploy Succeeds but Site Shows Old Version

**Cause**: Browser cache or webpack assets not rebuilt.

**Solution**:
1. Hard refresh browser: Cmd+Shift+R (Mac) or Ctrl+Shift+R (Windows)
2. Check deployment logs: Verify webpack build step succeeded
3. SSH to server and verify: `ls -la /opt/owid-grapher/dist/assets/`

---

## 🔍 Monitoring

### View Workflow Runs

https://github.com/vpicouet/owid-grapher/actions

### View Docker Images

https://github.com/vpicouet/owid-grapher/pkgs/container/owid-grapher

### Check Deployment Logs

```bash
# Test server
ssh root@64.23.242.13 'tail -100 /tmp/owid-prod.log'

# Production server
ssh root@159.65.56.172 'tail -100 /tmp/owid-prod.log'
```

---

## 📝 Notes

- **Docker Image**: Built but not currently used for deployment (we use git pull + restart instead)
- **Future Enhancement**: Could deploy Docker container directly instead of git pull
- **Webpack Cache**: Docker layer caching makes rebuilds fast (~5 min instead of 15 min)
- **Rollback**: If deployment fails, previous version keeps running (service only restarts if code pulls successfully)

---

## 🚀 Next Steps

1. ✅ Configure SSH_PRIVATE_KEY secret
2. ✅ Test workflow with a dummy commit
3. ✅ Verify test deployment works
4. ✅ Configure production environment with approval
5. ✅ Test production deployment manually

---

**Last Updated**: 2026-01-23
**Maintainer**: Modern Societies Observatory Team
