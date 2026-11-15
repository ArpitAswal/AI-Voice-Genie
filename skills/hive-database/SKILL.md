---
name: hive-database
description: Step-by-step execution checklist for creating, modifying, and migrating Hive local database models with hive_generator in the AI Voice Genie Flutter project. Load this skill whenever adding a new Hive type, adding fields to an existing model, or troubleshooting codegen errors.
---

# Hive Database Workflow

Follow this exact pipeline for every Hive model create/update task.

## Step 1: Design the Model
1. Identify the **stable `typeId`** for the new type. Search the entire codebase for existing `@HiveType(typeId: N)` annotations to find the next unused integer. Document the assignment in a comment.
2. Assign **`@HiveField(N)`** indices starting from `0`. Once assigned, indices are **permanent** — never change or reuse a field index (it breaks binary deserialization of existing data).
3. Keep models **immutable where possible**: use `final` fields. Provide a `copyWith()` method for state transitions.

```dart
import 'package:hive/hive.dart';

part 'message.g.dart';  // generated file

@HiveType(typeId: 2)   // ← unique; check existing adapters before assigning
class Message extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String content;

  @HiveField(2)
  final DateTime createdAt;

  Message({required this.id, required this.content, required this.createdAt});
}
```

## Step 2: Run Code Generation
```bash
dart run build_runner build --delete-conflicting-outputs
```
Verify that `message.g.dart` was generated with a `MessageAdapter` class.

## Step 3: Register the Adapter
Register the adapter in `main()` **before** `Hive.openBox()` or any box access:
```dart
Hive.registerAdapter(MessageAdapter());  // generated adapter
```

## Step 4: Open & Access the Box
```dart
// Open once at startup or lazily before first use
final box = await Hive.openBox<Message>('messages');

// Write
box.add(message);           // auto key
box.put('key', message);    // named key

// Read
final messages = box.values.toList();
final one = box.get('key');

// Delete
box.delete('key');
await box.deleteFromDisk();  // full purge
```

## Step 5: Close Properly
Close boxes when the owning screen or service disposes:
```dart
@override
void dispose() {
  Hive.box<Message>('messages').close();
  super.dispose();
}
```
**Do not** close boxes that are shared across the app lifecycle — only close screen-scoped boxes.

## Step 6: Field Migration (Adding Fields to Existing Model)
- Add the new `@HiveField` with the **next unused index** (never fill gaps — gaps are intentional tombstones).
- Provide a `defaultValue` or make the field nullable so old binary records (missing the new field) deserialize safely.
- Re-run `build_runner`. Test with existing box data to confirm deserialization does not throw.

## Step 7: Verification
```bash
dart run build_runner build --delete-conflicting-outputs
flutter analyze
flutter test  # run Hive unit tests with temp directory
```
