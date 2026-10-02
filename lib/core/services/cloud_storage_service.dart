import 'dart:convert';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import '../constants/firebase_collections.dart';

/// Service for uploading and managing user attachments and AI-generated images
/// in Firebase Cloud Storage.
///
/// Path structure (Conversation-Scoped):
///   users/
///     └── {uid}/
///           └── conversations/
///                 └── {conversationId}/
///                       ├── images/
///                       │     └── {timestamp}_{fileName}
///                       ├── pdfs/
///                       │     └── {timestamp}_{fileName}
///                       └── generated/
///                             └── generated_{timestamp}_{index}.png
///
/// This structured layout allows:
///   1. Unified audit & extraction: all assets for a given conversation are clustered in one root folder.
///   2. One-step deletion: all conversation media can be deleted in a single recursive sweep.
///   3. Strict Firebase Security Rules scoping by user ID (`users/{uid}/**`).
class CloudStorageService {
  static final CloudStorageService instance = CloudStorageService._();

  final FirebaseStorage _storage;

  CloudStorageService._({FirebaseStorage? storage})
      : _storage = storage ?? FirebaseStorage.instance;

  @visibleForTesting
  CloudStorageService.forTesting(this._storage);

  /// Uploads an AI-generated Base64 image to Firebase Cloud Storage.
  ///
  /// Replaces Cloudinary for AI image generation storage.
  ///
  /// Path: `users/{uid}/conversations/{conversationId}/generated/generated_{timestamp}_{index}.(png|jpg)`
  ///
  /// Returns the public HTTPS download URL on success, or null on failure.
  Future<String?> uploadGeneratedImageBase64({
    required String uid,
    required String conversationId,
    required String base64String,
    int index = 0,
    String? mimeType,
  }) async {
    try {
      if (base64String.isEmpty) return null;

      final cleanedBase64 = base64String.contains(',')
          ? base64String.split(',').last
          : base64String;

      final normalized = cleanedBase64.replaceAll(RegExp(r'\s+'), '');
      final bytes = base64Decode(base64.normalize(normalized));

      final effectiveMimeType = mimeType ??
          (normalized.startsWith('/9j/') ? 'image/jpeg' : 'image/png');
      final isJpeg =
          effectiveMimeType == 'image/jpeg' || effectiveMimeType == 'image/jpg';
      final ext = isJpeg ? 'jpg' : 'png';

      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = 'generated_${timestamp}_$index.$ext';
      final path = FirebaseCollections.storageGeneratedImagePath(
        uid,
        conversationId,
        fileName,
      );

      final ref = _storage.ref().child(path);
      final metadata = SettableMetadata(
        contentType: effectiveMimeType,
        customMetadata: {
          FirebaseCollections.storageMetaGeneratedBy: uid,
          FirebaseCollections.storageMetaConversationId: conversationId,
          FirebaseCollections.storageMetaType:
              FirebaseCollections.storageMetaTypeAiGenerated,
          'mimeType': effectiveMimeType,
          FirebaseCollections.storageMetaGeneratedAt:
              DateTime.now().toIso8601String(),
        },
      );

      final uploadTask = await ref.putData(bytes, metadata);
      final downloadUrl = await uploadTask.ref.getDownloadURL();

      debugPrint('☁️ CloudStorage: Uploaded generated image -> $path');
      return downloadUrl;
    } catch (e, stackTrace) {
      debugPrint('⚠️ CloudStorageService.uploadGeneratedImageBase64 error: $e');
      debugPrint(stackTrace.toString());
      return null;
    }
  }

  /// Uploads an AI-generated PDF document to Firebase Cloud Storage.
  ///
  /// Path: `users/{uid}/conversations/{conversationId}/generated_pdfs/generated_{timestamp}_{fileName}.pdf`
  ///
  /// Returns the public HTTPS download URL on success, or null on failure.
  Future<String?> uploadGeneratedPdfBytes({
    required String uid,
    required String conversationId,
    required Uint8List bytes,
    required String fileName,
  }) async {
    try {
      if (bytes.isEmpty) return null;

      final safeName = _sanitizeFileName(
          fileName.endsWith('.pdf') ? fileName : '$fileName.pdf');
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final storageFileName = 'generated_${timestamp}_$safeName';
      final path = FirebaseCollections.storageGeneratedPdfPath(
        uid,
        conversationId,
        storageFileName,
      );

      final ref = _storage.ref().child(path);
      final metadata = SettableMetadata(
        contentType: 'application/pdf',
        customMetadata: {
          FirebaseCollections.storageMetaGeneratedBy: uid,
          FirebaseCollections.storageMetaConversationId: conversationId,
          FirebaseCollections.storageMetaType:
              FirebaseCollections.storageMetaTypeAiGenerated,
          FirebaseCollections.storageMetaOriginalName: fileName,
          FirebaseCollections.storageMetaGeneratedAt:
              DateTime.now().toIso8601String(),
        },
      );

      final uploadTask = await ref.putData(bytes, metadata);
      final downloadUrl = await uploadTask.ref.getDownloadURL();

      debugPrint('☁️ CloudStorage: Uploaded generated PDF -> $path');
      return downloadUrl;
    } catch (e, stackTrace) {
      debugPrint('⚠️ CloudStorageService.uploadGeneratedPdfBytes error: $e');
      debugPrint(stackTrace.toString());
      return null;
    }
  }

  /// Uploads a user-attached image to Firebase Cloud Storage.
  ///
  /// Path: `users/{uid}/conversations/{conversationId}/images/{timestamp}_{fileName}`
  ///
  /// Returns the public HTTPS download URL on success, or null on failure.
  Future<String?> uploadImage({
    required String uid,
    required String conversationId,
    required Uint8List bytes,
    required String fileName,
    String? mimeType,
  }) async {
    try {
      if (bytes.isEmpty) return null;

      final safeName = _sanitizeFileName(fileName);
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final storageFileName = '${timestamp}_$safeName';
      final path = FirebaseCollections.storageImagePath(
        uid,
        conversationId,
        storageFileName,
      );

      final ref = _storage.ref().child(path);
      final metadata = SettableMetadata(
        contentType: mimeType ?? _guessImageMimeType(fileName),
        customMetadata: {
          FirebaseCollections.storageMetaUploadedBy: uid,
          FirebaseCollections.storageMetaConversationId: conversationId,
          FirebaseCollections.storageMetaOriginalName: fileName,
          FirebaseCollections.storageMetaUploadedAt:
              DateTime.now().toIso8601String(),
        },
      );

      final uploadTask = await ref.putData(bytes, metadata);
      final downloadUrl = await uploadTask.ref.getDownloadURL();

      debugPrint('☁️ CloudStorage: Uploaded image -> $path');
      return downloadUrl;
    } catch (e, stackTrace) {
      debugPrint('⚠️ CloudStorageService.uploadImage error: $e');
      debugPrint(stackTrace.toString());
      return null;
    }
  }

  /// Uploads a user-attached PDF document to Firebase Cloud Storage.
  ///
  /// Path: `users/{uid}/conversations/{conversationId}/pdfs/{timestamp}_{fileName}`
  ///
  /// Returns the public HTTPS download URL on success, or null on failure.
  Future<String?> uploadPdf({
    required String uid,
    required String conversationId,
    required Uint8List bytes,
    required String fileName,
  }) async {
    try {
      if (bytes.isEmpty) return null;

      final safeName = _sanitizeFileName(fileName);
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final storageFileName = '${timestamp}_$safeName';
      final path = FirebaseCollections.storagePdfPath(
        uid,
        conversationId,
        storageFileName,
      );

      final ref = _storage.ref().child(path);
      final metadata = SettableMetadata(
        contentType: 'application/pdf',
        customMetadata: {
          FirebaseCollections.storageMetaUploadedBy: uid,
          FirebaseCollections.storageMetaConversationId: conversationId,
          FirebaseCollections.storageMetaOriginalName: fileName,
          FirebaseCollections.storageMetaUploadedAt:
              DateTime.now().toIso8601String(),
        },
      );

      final uploadTask = await ref.putData(bytes, metadata);
      final downloadUrl = await uploadTask.ref.getDownloadURL();

      debugPrint('☁️ CloudStorage: Uploaded PDF -> $path');
      return downloadUrl;
    } catch (e, stackTrace) {
      debugPrint('⚠️ CloudStorageService.uploadPdf error: $e');
      debugPrint(stackTrace.toString());
      return null;
    }
  }

  /// Permanently deletes all uploaded attachments (images, PDFs, and generated images)
  /// for a given conversation.
  ///
  /// Cleans the unified conversation directory and handles legacy paths gracefully.
  Future<void> deleteConversationAttachments({
    required String uid,
    required String conversationId,
  }) async {
    try {
      // 1. Delete all attachments in the unified conversation directory
      final conversationFolderRef = _storage.ref().child(
            FirebaseCollections.storageConversationDir(uid, conversationId),
          );
      await _deleteFolderRecursive(conversationFolderRef);

      // 2. Legacy fallback cleanup in case older tests created root folders
      final legacyImageRef =
          _storage.ref().child('users/$uid/images/$conversationId');
      final legacyPdfRef =
          _storage.ref().child('users/$uid/pdfs/$conversationId');
      final legacyGeneratedRef =
          _storage.ref().child('users/$uid/generated_images/$conversationId');

      await Future.wait([
        _deleteFolderRecursive(legacyImageRef),
        _deleteFolderRecursive(legacyPdfRef),
        _deleteFolderRecursive(legacyGeneratedRef),
      ]);

      debugPrint(
          '🗑️ CloudStorage: Deleted all attachments for conversation $conversationId');
    } catch (e) {
      debugPrint(
          '⚠️ CloudStorageService.deleteConversationAttachments error: $e');
    }
  }

  /// Recursively deletes all files and subdirectories under [folderRef].
  Future<void> _deleteFolderRecursive(Reference folderRef) async {
    try {
      final listResult = await folderRef.listAll();
      final fileDeleteFutures = listResult.items.map((item) => item.delete());
      final subFolderFutures =
          listResult.prefixes.map((prefix) => _deleteFolderRecursive(prefix));
      await Future.wait([...fileDeleteFutures, ...subFolderFutures]);
    } catch (_) {
      // Folder might not exist if no attachments of that type were uploaded
    }
  }

  String _sanitizeFileName(String name) {
    final cleaned = name.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
    return cleaned.isEmpty ? 'attachment' : cleaned;
  }

  String _guessImageMimeType(String name) {
    final lower = name.toLowerCase();
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.webp')) return 'image/webp';
    if (lower.endsWith('.gif')) return 'image/gif';
    return 'image/jpeg';
  }
}
