import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';

import '../../../ai_layer/models/ai_request.dart';
import '../../../ai_layer/orchestrator/ai_orchestrator.dart';
import '../../../core/enums/app_enums.dart';
import '../../../core/error/ai_exception.dart';
import '../../../core/error/effect_bus.dart';
import '../../../core/services/analytics_service.dart';
import '../data/pdf_repository_impl.dart';
import '../domain/pdf_doc_model.dart';
import '../domain/pdf_repository.dart';

/// State manager for the PDF reader feature.
///
/// Manages three distinct states:
///   1. idle        — no PDF uploaded, shows upload prompt
///   2. extracting  — PDF picked, text being extracted
///   3. ready       — PDF extracted, user can ask questions
///   4. generating  — AI is answering a question
///
/// The Q&A message list is local — it is NOT the same ChatProvider
/// used for text chat. PDF Q&A is a separate, session-only list.
/// Each question is saved to Firestore individually via PdfRepository.
///
/// Usage:
/// ```dart
/// await pdfProvider.pickAndLoadPdf();
/// await pdfProvider.askQuestion(uid, prompt, validProviders);
/// ```
class PdfProvider extends ChangeNotifier {
  final PdfRepository _repository;
  final AiOrchestrator _orchestrator;
  final AnalyticsService _analytics;

  PdfProvider({
    PdfRepository? repository,
    AiOrchestrator? orchestrator,
    AnalyticsService? analytics,
  })  : _repository = repository ?? PdfRepositoryImpl(),
        _orchestrator = orchestrator ?? AiOrchestrator.instance,
        _analytics = analytics ?? AnalyticsService.instance;

  // ── State ──────────────────────────────────────────────────────────────────

  PdfDocumentModel? _document;
  final List<PdfQaMessage> _messages = [];
  bool _isExtracting = false;
  bool _isGenerating = false;
  String? _errorMessage;

  PdfDocumentModel? get document => _document;
  List<PdfQaMessage> get messages => List.unmodifiable(_messages);
  bool get isExtracting => _isExtracting;
  bool get isGenerating => _isGenerating;
  String? get errorMessage => _errorMessage;
  bool get hasPdf => _document != null;
  bool get hasMessages => _messages.isNotEmpty;

  // ── PDF Picking and Extraction ─────────────────────────────────────────────

  /// Open the file picker, validate, extract text, and update state.
  ///
  /// Returns true if a PDF was successfully loaded.
  Future<bool> pickAndLoadPdf() async {
    _errorMessage = null;

    // Open system file picker — PDF only
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
      withData: true, // load bytes directly into memory
    );

    // User cancelled the picker
    if (result == null || result.files.isEmpty) return false;

    final file = result.files.first;

    // Guard: file must have bytes (withData: true should always provide them)
    if (file.bytes == null) {
      _errorMessage = PdfErrorCodes.extractionFailed;
      notifyListeners();
      return false;
    }

    final fileSizeBytes = file.bytes!.lengthInBytes;
    final fileName = file.name;

    // Validate file size BEFORE extraction
    final sizeError = _repository.validateFileSize(fileSizeBytes);
    if (sizeError != null) {
      _errorMessage = sizeError;
      notifyListeners();
      return false;
    }

    // Start extraction
    _isExtracting = true;
    _document = null;
    _messages.clear();
    notifyListeners();

    try {
      final doc = await _repository.extractText(
        pdfBytes: file.bytes!,
        fileName: fileName,
        fileSizeBytes: fileSizeBytes,
      );

      _document = doc;
      _isExtracting = false;
      notifyListeners();

      debugPrint(
        '📄 PdfProvider: loaded "$fileName" — '
            '${doc.pageCount} pages, ${doc.wordCount} words, '
            'truncated: ${doc.wasTruncated}',
      );

      return true;
    } catch (e) {
      debugPrint('❌ PdfProvider.pickAndLoadPdf error: $e');
      _errorMessage = PdfErrorCodes.extractionFailed;
      _isExtracting = false;
      notifyListeners();
      return false;
    }
  }

  // ── Ask a Question ─────────────────────────────────────────────────────────

  /// Send a question about the loaded PDF to the AI.
  ///
  /// [uid]            — current user's Firebase UID
  /// [question]       — the user's question about the PDF
  /// [validProviders] — providers with valid API keys
  ///
  /// Returns true on success, false on failure.
  Future<bool> askQuestion({
    required String uid,
    required String question,
    required List<AiProviderId> validProviders,
  }) async {
    if (_document == null) return false;
    if (question.trim().isEmpty) return false;

    _errorMessage = null;

    // Add question to local message list optimistically
    _messages.add(PdfQaMessage.question(question.trim()));
    _isGenerating = true;
    notifyListeners();

    try {
      final response = await _orchestrator.execute(
        request: AiRequest(
          capability: AiCapability.pdfParsing,
          uid: uid,
          prompt: question.trim(),
          pdfText: _document!.extractedText,
          pdfFileName: _document!.fileName,
        ),
        userKeyedProviders: validProviders,
      );

      final answer = response.text ?? '';

      // Add AI answer to local message list
      _messages.add(PdfQaMessage.answer(
        answer,
        provider: response.modelUsed,
      ));

      // Save to Firestore (non-blocking)
      await EffectBus.instance.safeEffect(() async {
        await _repository.savePdfConversation(
          uid: uid,
          pdfFileName: _document!.fileName,
          question: question.trim(),
          answer: answer,
          providerUsed: response.modelUsed,
        );
      });

      await _analytics.logFeatureUsed(AppFeature.pdfReader);

      _isGenerating = false;
      notifyListeners();
      return true;
    } on AiExhaustedException catch (e) {
      _removeLastQuestion();
      _errorMessage = e.message;
      _isGenerating = false;
      notifyListeners();
      return false;
    } on AiException catch (e) {
      _removeLastQuestion();
      _errorMessage = e.message;
      _isGenerating = false;
      notifyListeners();
      return false;
    } catch (e) {
      _removeLastQuestion();
      _errorMessage = 'something_went_wrong';
      _isGenerating = false;
      notifyListeners();
      return false;
    }
  }

  // ── Clear State ────────────────────────────────────────────────────────────

  /// Remove the current PDF and reset all state.
  ///
  /// Called when user taps "Remove PDF" or uploads a new one.
  void clearPdf() {
    _document = null;
    _messages.clear();
    _errorMessage = null;
    _isExtracting = false;
    _isGenerating = false;
    notifyListeners();
  }

  void clearError() {
    if (_errorMessage != null) {
      _errorMessage = null;
      notifyListeners();
    }
  }

  // ── Private ────────────────────────────────────────────────────────────────

  /// Remove the last question on failure (optimistic rollback).
  void _removeLastQuestion() {
    if (_messages.isNotEmpty &&
        _messages.last.type == PdfQaMessageType.question) {
      _messages.removeLast();
    }
  }
}

// =============================================================================
// LOCAL Q&A MESSAGE MODEL
// =============================================================================

/// Session-only message model for PDF Q&A.
///
/// NOT persisted to Firestore as an in-memory list.
/// Each question+answer pair is saved as a separate conversation via
/// PdfRepository.savePdfConversation().
class PdfQaMessage {
  final String content;
  final PdfQaMessageType type;
  final AiProviderId? provider; // only set on answer messages
  final DateTime timestamp;

  PdfQaMessage._({
    required this.content,
    required this.type,
    this.provider,
  }) : timestamp = DateTime.now();

  factory PdfQaMessage.question(String content) =>
      PdfQaMessage._(content: content, type: PdfQaMessageType.question);

  factory PdfQaMessage.answer(String content, {required AiProviderId provider}) =>
      PdfQaMessage._(
          content: content,
          type: PdfQaMessageType.answer,
          provider: provider);

  bool get isQuestion => type == PdfQaMessageType.question;
  bool get isAnswer => type == PdfQaMessageType.answer;
}

enum PdfQaMessageType { question, answer }