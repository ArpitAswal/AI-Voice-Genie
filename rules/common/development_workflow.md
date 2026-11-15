# Common Development & Git Workflow Rules

## 1. Execution Lifecycle
1. **Context Check**: Read `context.md` (project root) and recent git log to understand active architectural direction.
2. **Impact Analysis**: Search call sites across the codebase before altering shared models, Hive type adapters, or API contracts.
3. **Codegen Gate**: After editing any `@HiveType`/`@HiveField` annotated model, always run:
   ```bash
   dart run build_runner build --delete-conflicting-outputs
   ```
4. **Incremental Changes**: Build features in verifiable layers (Contracts → Data Layer + Tests → State Logic + Tests → UI).
5. **Verification Gate**: Run `dart format .` → `flutter analyze` → `flutter test` before completing any task.

## 2. Git Hygiene
- Make atomic, single-purpose commits.
- Follow Conventional Commits: `feat:`, `fix:`, `refactor:`, `test:`, `docs:`, `chore:`.
- Never commit build artifacts (`build/`, `.dart_tool/`, `.gradle/`, `*.g.dart` generated files are allowed but check `.gitignore`).
- Never run destructive commands (`git reset --hard`, `git push --force`) without confirmation.
- Ensure `firebase_options.dart` is tracked (it contains no secrets — secrets live in `.env` / `local.properties`).