# Platform Extension: iOS, Swift & SwiftUI

> **Activation**: Apply when working with `Package.swift`, `*.xcodeproj`, or `*.swift` files.

## 1. Type Modeling & Protocol Injection
- **Value Types First**: Default to `struct` and `enum` value types for data models, view states, and DTOs.
- **Protocol-Driven DI**: Define module boundaries using small, focused protocols (`protocol UserRepository: Sendable`) and inject them via initializers or SwiftUI `EnvironmentValues` for easy unit testing.
- **Safe Unwrapping**: Never use force unwrapping (`!`), `try!`, or force casts (`as!`) in production logic; use `guard let`, `if let`, or typed `throws`.

## 2. Swift Concurrency & Actors
- **MainActor Isolation**: Annotate UI state holders (`@Observable` classes or `ObservableObject` view models) with `@MainActor` to guarantee UI updates run on the main thread.
- **Actor Boundaries**: Use dedicated `actor` types for mutable in-memory caches, tracking `Sendable` conformance across boundaries. Be mindful of actor reentrancy across `await` suspension points.
- **Task Lifecycle**: Cancel asynchronous work when a view disappears; prefer SwiftUI's `.task { ... }` modifier, which cancels automatically on view dismissal.

## 3. ARC & Memory Management
- Break retain cycles in escaping closures stored on reference types using `[weak self]` and `guard let self else { return }`.
- Always mark delegate and parent references as `weak`.

## 4. Verification Commands
- SwiftPM: `swift test`
- Xcode Simulator: `xcodebuild test -scheme <SchemeName> -destination 'platform=iOS Simulator,name=iPhone 16'`