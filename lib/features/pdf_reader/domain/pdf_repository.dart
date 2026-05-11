import 'dart:typed_data';

import 'package:ai_voice_genie/features/pdf_reader/domain/pdf_doc_model.dart';

import '../../../core/enums/app_enums.dart';

/// Abstract repository for PDF operations.
///
/// Responsibilities:
///   - Validate PDF file size before processing
///   - Extract text from PDF bytes using Syncfusion
///   - Save Q&A conversations to Firestore
///
/// All text extraction is local — no network call.
/// The AI call happens in PdfProvider via AiOrchestrator,
/// not inside this repository.
abstract class PdfRepository {
  /// Validate the PDF file size before attempting extraction.
  ///
  /// Returns an error localization key if size exceeds limit.
  /// Returns null if size is acceptable.
  String? validateFileSize(int fileSizeBytes);

  /// Extract text content from PDF bytes.
  ///
  /// Uses Syncfusion Flutter PDF for local extraction.
  /// Returns a [PdfDocumentModel] with the extracted text.
  /// Throws [PdfException] if extraction fails entirely.
  ///
  /// Text is automatically truncated at [AppConstants.maxPdfCharactersForAi]
  /// to stay within AI provider context window limits.
  Future<PdfDocumentModel> extractText({
    required Uint8List pdfBytes,
    required String fileName,
    required int fileSizeBytes,
  });
}

// =============================================================================
// PDF EXCEPTION
// =============================================================================

class PdfException implements Exception {
  final String code;
  final String? technicalMessage;

  const PdfException(this.code, {this.technicalMessage});

  @override
  String toString() =>
      'PdfException(code: $code, technical: $technicalMessage)';
}

class PdfErrorCodes {
  /// File exceeds the maximum allowed size
  static const String fileTooLarge = 'pdf_too_large';

  /// Syncfusion failed to parse the PDF bytes
  static const String extractionFailed = 'pdf_read_failed';

  /// PDF has no readable text layer (scanned document)
  static const String noTextContent = 'pdf_read_failed';

  /// Firestore save failed
  static const String saveFailed = 'something_went_wrong';
}