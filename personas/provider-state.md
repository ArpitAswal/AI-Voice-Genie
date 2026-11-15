---
name: provider-state
description: Enforces correct Provider/ChangeNotifier patterns for the AI Voice Genie Flutter project. Load this persona whenever creating or modifying a ChangeNotifier class, adding a new provider, or reviewing state management code.
---

# Provider & ChangeNotifier State Persona

## Objective
Ensure every state class and widget integration follows the Provider pattern used by this project — no mixed paradigms, no anti-patterns.

## Rules

### 1. ChangeNotifier Design
- Keep each `ChangeNotifier` **single-responsibility**: one class = one feature domain (e.g., `ChatNotifier`, `VoiceNotifier`, `AuthNotifier`).
- Expose only immutable views of state to the UI:
  ```dart
  // ✅ Good — UI reads an immutable list copy
  List<Message> get messages => List.unmodifiable(_messages);

  // ❌ Bad — exposes mutable internal list directly
  List<Message> get messages => _messages;
  ```
- Call `notifyListeners()` only **after** the full state mutation is complete, never in the middle of an async chain.
- Model loading/error/success states as a sealed class or enum, not multiple boolean flags:
  ```dart
  // ✅ Good
  sealed class ChatState { ... }
  class ChatInitial extends ChatState {}
  class ChatLoading extends ChatState {}
  class ChatSuccess extends ChatState { final List<Message> messages; ... }
  class ChatFailure extends ChatState { final String message; ... }

  // ❌ Bad
  bool isLoading = false;
  bool hasError = false;
  String? errorMessage;
  ```

### 2. Provider Registration (main.dart / MultiProvider)
- Register all notifiers at the highest appropriate ancestor — typically `MultiProvider` wrapping `MaterialApp`.
- Use `ChangeNotifierProvider` for screen-scoped notifiers or `ChangeNotifierProvider.value` when passing an existing instance down.
- Never create a `ChangeNotifier` inside a `build()` method — it will be recreated on every rebuild.

### 3. Widget Consumption Rules
| Use Case | Correct API |
|----------|------------|
| Rebuild widget on state change | `context.watch<T>()` or `Consumer<T>` |
| Narrow rebuild to one field | `Selector<T, R>(selector: (_, n) => n.field, builder: ...)` |
| Call a method / trigger event | `context.read<T>().method()` |
| One-time read in `initState` | `context.read<T>()` inside `WidgetsBinding.instance.addPostFrameCallback` |

- **Never** use `context.watch<T>()` inside `initState`, `dispose`, or callbacks — it throws at runtime.
- **Never** use `context.watch<T>()` at the top of a large `build()` if only a small sub-widget depends on that state.

### 4. Async Operations in ChangeNotifier
```dart
Future<void> sendMessage(String text) async {
  _state = const ChatLoading();
  notifyListeners();
  try {
    final response = await _repository.send(text);
    _state = ChatSuccess(messages: [..._messages, response]);
  } on NetworkFailure catch (e) {
    _state = ChatFailure(message: e.message);
  } finally {
    notifyListeners();
  }
}
```
- Always set a loading state **before** the async call and a final state (success or failure) **after** it.
- Catch only typed failures — never bare `catch (e)` that swallows exceptions silently.

### 5. Disposal
- If a `ChangeNotifier` holds `StreamSubscription`s, `Timer`s, or audio resources, override `dispose()`:
  ```dart
  @override
  void dispose() {
    _subscription?.cancel();
    _tts.stop();
    super.dispose();
  }
  ```
- Use `ChangeNotifierProvider` (not `.value`) for lifecycle-owned notifiers so Flutter calls `dispose()` automatically.
