/// Immutable entity representing an uploaded PDF document.
///
/// Holds metadata and extracted text content.
/// The raw PDF bytes are NOT stored here — they are used once
/// for extraction and then discarded to avoid memory pressure.
///
/// The [extractedText] field holds the full text content extracted
/// by Syncfusion. This is what gets sent to AI providers as context.
class PdfDocumentModel {
  /// Original file name (e.g. "report.pdf")
  final String fileName;

  /// File size in bytes — used for the size display label
  final int fileSizeBytes;

  /// Number of pages in the document
  final int pageCount;

  /// Full extracted text content from all pages.
  ///
  /// May be empty if the PDF has no text layer (scanned document).
  /// Truncated to [AppConstants.pdfMaxChars] before being sent to AI.
  final String extractedText;

  /// Whether the extracted text was truncated due to length limits
  final bool wasTruncated;

  const PdfDocumentModel({
    required this.fileName,
    required this.fileSizeBytes,
    required this.pageCount,
    required this.extractedText,
    this.wasTruncated = false,
  });

  /// Whether this document has any readable text content
  bool get hasText => extractedText.trim().isNotEmpty;

  /// Human-readable file size label (e.g. "2.4 MB", "850 KB")
  String get fileSizeLabel {
    if (fileSizeBytes >= 1000 * 1000) {
      final mb = fileSizeBytes / (1000 * 1000);
      return '${mb.toStringAsFixed(1)} MB';
    }
    final kb = fileSizeBytes / 1000;
    return '${kb.toStringAsFixed(0)} KB';
  }

  /// Word count of the extracted text — shown in the PDF card
  int get wordCount => extractedText.trim().isEmpty
      ? 0
      : extractedText.trim().split(RegExp(r'\s+')).length;

  PdfDocumentModel copyWith({
    String? fileName,
    int? fileSizeBytes,
    int? pageCount,
    String? extractedText,
    bool? wasTruncated,
  }) {
    return PdfDocumentModel(
      fileName: fileName ?? this.fileName,
      fileSizeBytes: fileSizeBytes ?? this.fileSizeBytes,
      pageCount: pageCount ?? this.pageCount,
      extractedText: extractedText ?? this.extractedText,
      wasTruncated: wasTruncated ?? this.wasTruncated,
    );
  }

  @override
  String toString() => 'PdfDocumentModel(file: $fileName, pages: $pageCount, '
      'chars: ${extractedText.length}, truncated: $wasTruncated)';
}
