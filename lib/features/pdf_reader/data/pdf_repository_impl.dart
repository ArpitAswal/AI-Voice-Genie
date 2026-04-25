import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/enums/app_enums.dart';
import '../../chat_prompt/data/chat_repository_impl.dart';
import '../../chat_prompt/domain/chat_repository.dart';
import '../../chat_prompt/domain/message_model.dart';
import '../domain/pdf_doc_model.dart';
import '../domain/pdf_repository.dart';

/// Concrete implementation of PdfRepository.
///
/// Text extraction strategy:
///   1. Load PDF bytes into Syncfusion PdfDocument
///   2. Iterate pages — extract text from each using PdfTextExtractor
///   3. Join all page text with double newlines
///   4. Truncate to AppConstants.maxPdfCharactersForAi if necessary
///   5. Dispose the Syncfusion document to free memory
///
/// Conversation save strategy:
///   Reuses ChatRepositoryImpl to create the conversation + messages.
///   This avoids duplicating Firestore write logic.
class PdfRepositoryImpl implements PdfRepository {
  final ChatRepository _chatRepository;

  PdfRepositoryImpl({ChatRepository? chatRepository})
      : _chatRepository = chatRepository ?? ChatRepositoryImpl();

  // ── File Size Validation ───────────────────────────────────────────────────

  @override
  String? validateFileSize(int fileSizeBytes) {
    if (fileSizeBytes > AppConstants.maxPdfSizeBytes) {
      debugPrint(
        '⚠️ PdfRepository: file too large — '
            '${(fileSizeBytes / (1024 * 1024)).toStringAsFixed(1)} MB',
      );
      return PdfErrorCodes.fileTooLarge;
    }
    return null;
  }

  // ── Text Extraction ────────────────────────────────────────────────────────

  @override
  Future<PdfDocumentModel> extractText({
    required Uint8List pdfBytes,
    required String fileName,
    required int fileSizeBytes,
  }) async {
    // Run extraction on a background isolate to avoid blocking the UI thread
    // Syncfusion PDF parsing can be CPU-intensive for large documents
    return compute(_extractTextIsolate, _PdfExtractionParams(
      pdfBytes: pdfBytes,
      fileName: fileName,
      fileSizeBytes: fileSizeBytes,
    ));
  }

  // ── Conversation Save ──────────────────────────────────────────────────────

  @override
  Future<String?> savePdfConversation({
    required String uid,
    required String pdfFileName,
    required String question,
    required String answer,
    required AiProviderId providerUsed,
  }) async {
    try {
      // Create conversation document for this PDF session
      // final conversation = await _chatRepository.createConversation(
      //   uid: uid,
      //   firstMessagePreview: 'PDF: $pdfFileName',
      //   capability: ConversationCapability.pdfReader,
      //   firstProvider: providerUsed,
      // );

      // User's question as first message
      final userMessage = MessageModel.userMessage(question).copyWith(
        status: MessageStatus.delivered,
        isOptimistic: false,
        pdfName: pdfFileName,
      );

      // AI answer as second message
      final aiMessage = MessageModel.aiResponse(
        content: answer,
        modelUsed: providerUsed,
        pdfName: pdfFileName,
      );
      return "";

      // await _chatRepository.saveMessagePair(
      //   uid: uid,
      //   conversationId: conversation.id,
      //   userMessage: userMessage,
      //   aiMessage: aiMessage,
      // );
      //
      //
      // debugPrint(
      //   '✅ PdfRepository: saved PDF conversation ${conversation.id}',
      // );
      // return conversation.id;
    } catch (e) {
      debugPrint('⚠️ PdfRepository.savePdfConversation error: $e');
      return null; // Non-fatal — Q&A still works even if save fails
    }
  }
}

// =============================================================================
// ISOLATE HELPERS
// =============================================================================

/// Parameters passed to the background isolate for text extraction.
/// Must be a simple data class — no Flutter objects allowed in isolates.
class _PdfExtractionParams {
  final Uint8List pdfBytes;
  final String fileName;
  final int fileSizeBytes;

  const _PdfExtractionParams({
    required this.pdfBytes,
    required this.fileName,
    required this.fileSizeBytes,
  });
}

/// Top-level function for compute() — extracts text from PDF bytes.
///
/// Runs on a background isolate so large PDFs do not freeze the UI.
/// Uses Syncfusion PdfDocument + PdfTextExtractor.
PdfDocumentModel _extractTextIsolate(_PdfExtractionParams params) {
  PdfDocument? document;

  try {
    // Load PDF from bytes — Syncfusion handles password-protected check
    document = PdfDocument(inputBytes: params.pdfBytes);
    final pageCount = document.pages.count;

    // Extract text from every page
    final extractor = PdfTextExtractor(document);
    final buffer = StringBuffer();

    for (int i = 0; i < pageCount; i++) {
      final pageText = extractor.extractText(startPageIndex: i, endPageIndex: i);
      if (pageText.trim().isNotEmpty) {
        buffer.write(pageText);
        buffer.write('\n\n'); // Separate pages with double newline
      }
    }

    final rawText = buffer.toString().trim();

    // Truncate if over the safety limit
    bool wasTruncated = false;
    String finalText = rawText;

    if (rawText.length > AppConstants.maxPdfCharactersForAi) {
      finalText = rawText.substring(0, AppConstants.maxPdfCharactersForAi);
      wasTruncated = true;
    }

    return PdfDocumentModel(
      fileName: params.fileName,
      fileSizeBytes: params.fileSizeBytes,
      pageCount: pageCount,
      extractedText: finalText,
      wasTruncated: wasTruncated,
    );
  } catch (e) {
    // If Syncfusion cannot parse this PDF, return empty model
    // UI will show the "no text content" warning
    return PdfDocumentModel(
      fileName: params.fileName,
      fileSizeBytes: params.fileSizeBytes,
      pageCount: 0,
      extractedText: '',
      wasTruncated: false,
    );
  } finally {
    // Always dispose Syncfusion document to release memory
    document?.dispose();
  }
}