# Common Testing Strategy & Standards

## 1. Testing Philosophy & Coverage Target
- Test **observable behavior and domain contracts**, not private implementation details.
- **Coverage Target**: 80% line/branch coverage for domain logic, state holders (ChangeNotifier), repositories, and data mappers. Run with:
  ```bash
  flutter test --coverage
  genhtml coverage/lcov.info -o coverage/html
  ```
- High target (95–100%) for authentication flows, API key storage, and usage tracking.
- Pragmatic exemptions for thin UI wrappers, generated code (`*.g.dart`), and DI wiring.

## 2. Test Pyramid
1. **Unit Tests (~70%)**: Test use cases, `ChangeNotifier` state classes, Hive data mappers, and serializers. Run in milliseconds using `Mockito`/`mocktail` fakes. Never open real Hive boxes — use `Hive.init()` with a temp directory and `hive.registerAdapter()` in `setUp()`.
2. **Widget / Component Tests (~20%)**: Test UI rendering across loading, empty, error, and populated states plus user taps. Wrap the widget under test with a `ChangeNotifierProvider` / `MultiProvider` that supplies mock notifiers.
3. **Integration Tests (~10%)**: Test critical end-to-end journeys: sign-in with Google, voice capture → AI response cycle, PDF export.

## 3. Mocking Hive & Firebase
- **Hive**: In tests, use `setUpAll(() async { final dir = await Directory.systemTemp.createTemp(); Hive.init(dir.path); });` and tear down with `Hive.close()`.
- **Firebase**: Use the `firebase_auth_mocks` / `fake_cloud_firestore` packages or manual fakes. Never call real Firebase in unit or widget tests.
- **HTTP**: Use `MockClient` from `package:http/testing.dart` to intercept all REST calls to AI endpoints.

## 4. Determinism
- Zero arbitrary `sleep` or wall-clock delays in tests.
- Use `fakeAsync` and `pump`/`pumpAndSettle` in widget tests.
- Follow **Arrange → Act → Assert** (Given / When / Then).