---
description: Run a full security and readiness audit before pushing to GitHub or publishing to the Play Store.
---

1. Load `personas/security-reviewer.md` and `rules/common/security.md`.
2. Load `rules/platforms/flutter-firebase.md` (Firebase security rules are always in scope).
3. Execute all 5 security check categories from `personas/security-reviewer.md`:
   - **Category 1**: Secret & key exposure (scan for `sk-`, `AIza`, `Bearer ` patterns in Dart files).
   - **Category 2**: Local storage audit (Hive vs `flutter_secure_storage`, `no_screenshot` activation).
   - **Category 3**: Firebase security rules audit (Firestore + Storage rule review).
   - **Category 4**: Network layer (HTTPS enforcement, header redaction, `cleartext` manifest check).
   - **Category 5**: Platform permissions (`AndroidManifest.xml` and `Info.plist` review).
4. Verify `.gitignore` coverage: `.env`, `local.properties`, `*.jks`, `*.keystore`, `*.p12`.
5. Output findings grouped by `[CRITICAL]`, `[HIGH]`, `[MEDIUM]`, `[OK]` with file paths and fix snippets.
6. Provide a final **Go / No-Go** verdict for the push or release.
