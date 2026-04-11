import '../../core/enums/app_enums.dart';
import '../models/ai_request.dart';
import '../models/ai_response.dart';

/// Abstract interface for all AI provider adapters.
///
/// Every adapter (OpenAI, Gemini, Claude) implements this interface.
/// The orchestrator only ever talks to this interface — never to
/// a concrete adapter directly.
///
/// Each method corresponds to one AiCapability.
/// Adapters only need to implement the capabilities they support.
/// Calling an unsupported method throws UnsupportedError immediately.
///
/// Error contract:
///   All methods throw typed AiException subclasses (from core/error/ai_exception.dart)
///   NEVER throw raw HTTP errors, platform exceptions, or provider-specific errors.
///   All provider-specific errors must be mapped to AiException types inside the adapter.
abstract class AiProviderAdapter {
  /// Which provider this adapter handles
  AiProviderId get providerId;

  /// Generate a text response from a prompt + optional history.
  ///
  /// Capability: AiCapability.textGeneration
  /// Supported by: OpenAI, Gemini, Claude
  Future<AiResponse> generateText({
    required AiRequest request,
    required String apiKey,
  });

  /// Generate an image from a text description.
  ///
  /// Capability: AiCapability.imageGeneration
  /// Supported by: OpenAI, Gemini
  /// NOT supported by: Claude — throws UnsupportedError if called
  Future<AiResponse> generateImage({
    required AiRequest request,
    required String apiKey,
  });

  /// Analyze an image and answer a question about it.
  ///
  /// Capability: AiCapability.imageUnderstanding
  /// Supported by: OpenAI, Gemini, Claude
  Future<AiResponse> analyzeImage({
    required AiRequest request,
    required String apiKey,
  });

  /// Answer questions about a PDF document's extracted text.
  ///
  /// Capability: AiCapability.pdfParsing
  /// Supported by: OpenAI, Gemini, Claude
  Future<AiResponse> parsePdf({
    required AiRequest request,
    required String apiKey,
  });

  // ── Routing Helper ─────────────────────────────────────────────────────────

  /// Route a request to the correct adapter method based on capability.
  ///
  /// Called by the orchestrator — never call individual methods directly
  /// from outside the ai/ layer.
  Future<AiResponse> execute({
    required AiRequest request,
    required String apiKey,
  }) {
    switch (request.capability) {
      case AiCapability.textGeneration:
        return generateText(request: request, apiKey: apiKey);
      case AiCapability.imageGeneration:
        return generateImage(request: request, apiKey: apiKey);
      case AiCapability.imageUnderstanding:
        return analyzeImage(request: request, apiKey: apiKey);
      case AiCapability.pdfParsing:
        return parsePdf(request: request, apiKey: apiKey);
      case AiCapability.speechToText:
      case AiCapability.textToSpeech:
      // Voice capabilities are handled by VoiceRepository (Phase 7)
        throw UnsupportedError(
          'Voice capabilities are not routed through AiOrchestrator. '
              'Use VoiceRepository instead.',
        );
    }
  }
}