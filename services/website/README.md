# CampusMate Website

Static landing page for CampusMate.

## Run locally

From repository root:

```powershell
cd services/website
python -m http.server 5173
```

Open:

- `http://localhost:5173`

## Files

- `index.html`
- `styles.css`
- `main.js`
- `assets/images/*`

## Deploy (GitHub Pages)

Workflow:

- `.github/workflows/deploy-website.yml`

Trigger:

- Push to `main` with changes under `services/website/**`
- Manual run via `workflow_dispatch`

Repository setting:

- `Settings > Pages > Build and deployment > Source` must be `GitHub Actions`
