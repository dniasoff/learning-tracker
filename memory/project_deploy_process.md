---
name: Deploy process
description: How to build and deploy to Google Play Store tracks
type: project
---

Deployment is via GitHub Actions workflow `deploy-play-store.yml`.

**To deploy to a specific track manually:**
```bash
gh workflow run deploy-play-store.yml --ref dev -f track=internal
# track options: internal | alpha | beta | production
```

**To deploy via tag:**
```bash
git tag v1.2.3-internal && git push origin --tags   # → internal track
git tag v1.2.3-alpha   && git push origin --tags   # → alpha
git tag v1.2.3         && git push origin --tags   # → production
```

**Why:** The workflow requires secrets (keystore, google-services.json, Firebase options, Play service account) so it can only run in CI — no local build path.

**How to apply:** After committing and pushing to dev, trigger via `gh workflow run` for the desired track. Watch with `gh run watch <run-id>`.
