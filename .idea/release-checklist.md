# CodexPet v0.1 Release Checklist

## 1. Desktop App (`codexpet-nest`)
- [ ] **Clean Build**: `make clean && make` succeeds.
- [ ] **Release Build**: `make release` succeeds with optimizations.
- [ ] **App Bundle**: `make app` generates a valid `.app`.
- [ ] **Smoke Test - Pets**:
  - [ ] Browse online marketplace.
  - [ ] Install a pet (e.g., "Codie").
  - [ ] Verify directory structure in `~/.codex/pets/`.
  - [ ] Verify SHA256 check pass/fail (test with tampered ZIP if needed).
- [ ] **Smoke Test - Nests**:
  - [ ] Browse official nest skins.
  - [ ] Install and "Apply Now".
  - [ ] Verify background and widgets render correctly.
- [ ] **Smoke Test - Widgets**:
  - [ ] Enable all widgets.
  - [ ] Verify usage indicator reflects current Codex state.
  - [ ] Test pomodoro start/stop.
- [ ] **Cleanup**: Ensure `~/Library/Application Support/CodexPet Nest/tmp` is empty after use.

## 2. Website (`codexpet`)
- [ ] **Build**: `npm run build` succeeds.
- [ ] **Deployment**: `wrangler deploy --dry-run` or staging deploy verified.
- [ ] **API Smoke Test**:
  - [ ] `GET /api/pets` returns valid JSON.
  - [ ] `GET /api/nests` returns valid JSON (official seeds).
  - [ ] `GET /api/nests/:id/download` returns correct metadata (SHA256/Size).
- [ ] **Asset Check**:
  - [ ] Preview images load for all official nests.
  - [ ] ZIP packages are accessible and not corrupted.

## 3. Documentation & Legal
- [ ] **README**: Accurate feature list and installation guide.
- [ ] **Privacy**: `PRIVACY.md` covers all file and network access.
- [ ] **Security**: `SECURITY.md` covers implementation of safe ZIP and SHA256.
- [ ] **Permissions**: `docs/permissions.md` matches app behavior.
- [ ] **Spec**: `docs/specs/nest-package.md` matches current `nest.json` format.

## 4. Final Packaging
- [ ] Create `CodexPetNest.dmg`.
- [ ] Draft GitHub Release notes.
- [ ] Ensure `.gitignore` is correctly excluding `.build/`, `tmp/`, and `.DS_Store`.
