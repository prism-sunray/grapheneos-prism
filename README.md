# GrapheneOS tegu Build Runner

This repo is structured to run GitHub Actions builds for GrapheneOS (`tegu` / Pixel 9a).

## Layout

- `.github/workflows/build.yml`: GitHub Actions workflow
- `scripts/generate-keys.sh`: generate signing keys locally
- `scripts/prepare-signing-secrets.sh`: package keys and upload GitHub Secrets
- `patches/`: optional custom patches (`write_at_cmd.sh` for KR VoLTE, `*.patch` files)

## Quick start

1. Generate keys locally (one time):

```bash
./scripts/generate-keys.sh
```

2. Upload encrypted secrets to GitHub:

```bash
./scripts/prepare-signing-secrets.sh
```

3. Commit and push this repo:

```bash
git init
git add .
git commit -m "Set up GrapheneOS build runner"
git branch -M main
git remote add origin <your-repo-url>
git push -u origin main
```

4. Trigger build manually:

```bash
gh workflow run build.yml
```

Force a specific tag:

```bash
gh workflow run build.yml -f force_tag=2026040300
```

## Notes

- `keys/` is ignored by git and should never be committed.
- `patches/write_at_cmd.sh` is optional; workflow skips KR VoLTE step if missing.
- The workflow uses `ubuntu-latest` by default.
