import 'package:flutter/foundation.dart';

import '../../../ai_layer/models/ai_request.dart';
import '../../../ai_layer/orchestrator/ai_orchestrator.dart';
import '../../../ai_layer/orchestrator/model_selector.dart';
import '../../../core/enums/app_enums.dart';
import '../../../core/error/ai_exception.dart';
import '../../../core/error/effect_bus.dart';
import '../../../core/services/analytics_service.dart';
import '../data/image_repository_impl.dart';
import '../domain/image_repository.dart';

/// State manager for the image generation feature.
///
/// Manages:
///   - Prompt and size selection state
///   - Generation loading state
///   - The generated image result
///   - Capability gap detection before any API call
///   - Analytics events
///
/// Usage:
/// ```dart
/// await imageProvider.generateImage(
///   uid: uid,
///   prompt: 'A red fox in snow',
///   size: AiImageSize.square,
///   validProviders: apiKeyProvider.validProviders,
/// );
/// ```
class ImageGeneratorProvider extends ChangeNotifier {
  final ImageRepository _repository;
  final AiOrchestrator _orchestrator;
  final AnalyticsService _analytics;

  ImageGeneratorProvider({
    ImageRepository? repository,
    AiOrchestrator? orchestrator,
    AnalyticsService? analytics,
  })  : _repository = repository ?? ImageRepositoryImpl(),
        _orchestrator = orchestrator ?? AiOrchestrator.instance,
        _analytics = analytics ?? AnalyticsService.instance;

  // ── State ──────────────────────────────────────────────────────────────────

  bool _isGenerating = false;
  String? _errorMessage;
  GeneratedImageResult? _currentImage;

  /// Currently selected image size
  AiImageSize _selectedSize = AiImageSize.square;

  bool get isGenerating => _isGenerating;
  String? get errorMessage => _errorMessage;
  GeneratedImageResult? get currentImage => _currentImage;
  AiImageSize get selectedSize => _selectedSize;
  bool get hasImage => _currentImage != null;

  // ── Size Selection ─────────────────────────────────────────────────────────

  void setImageSize(AiImageSize size) {
    if (_selectedSize == size) return;
    _selectedSize = size;
    notifyListeners();
  }

  // ── Generate Image ─────────────────────────────────────────────────────────

  /// Generate an image from a text prompt.
  ///
  /// [uid]            — current user's Firebase UID
  /// [prompt]         — text description of the desired image
  /// [validProviders] — providers the user has valid keys for
  ///
  /// Returns true on success, false on failure.
  Future<bool> generateImage({
    required String uid,
    required String prompt,
    required List<AiProviderId> validProviders,
  }) async {
    _errorMessage = null;

    // ── Step 1: Capability check before any API call ─────────────────────────
    final hasCapableProvider = ModelSelector.isCapabilityAvailable(
      capability: AiCapability.imageGeneration,
      userKeyedProviders: validProviders,
    );

    if (!hasCapableProvider) {
      // Find which providers support image gen (for the gap message)
      final supportedProviders = ModelSelector.providerNamesFor(
        AiCapability.imageGeneration,
      );
      debugPrint(
        '⚠️ ImageGeneratorProvider: no capable provider for imageGeneration. '
            'Supported by: $supportedProviders',
      );

      await _analytics.logAiCapabilityGap(
        modelSelected: validProviders.isNotEmpty
            ? validProviders.first
            : AiProviderId.claude,
        capabilityAttempted: AiCapability.imageGeneration,
      );

      _errorMessage = 'capability_gap_image_gen';
      notifyListeners();
      return false;
    }

    // ── Step 2: Start generation ─────────────────────────────────────────────
    _isGenerating = true;
    _currentImage = null;
    notifyListeners();

    try {
      final response = await _orchestrator.execute(
        request: AiRequest(
          capability: AiCapability.imageGeneration,
          uid: uid,
          prompt: prompt.trim(),
          imageSize: _selectedSize,
        ),
        userKeyedProviders: validProviders,
      );

      // ── Step 3: Process response into displayable bytes ───────────────────
      final imageBytes = await _repository.processImageResponse(response);

      if (imageBytes == null || imageBytes.isEmpty) {
        _errorMessage = 'image_generation_failed';
        _isGenerating = false;
        notifyListeners();
        return false;
      }

      // ── Step 4: Save to conversation history (non-blocking) ───────────────
      String? conversationId;
      await EffectBus.instance.safeEffect(() async {
        conversationId = await _repository.saveImageConversation(
          uid: uid,
          prompt: prompt.trim(),
          response: response,
          providerUsed: response.modelUsed,
        );
      });

      // ── Step 5: Store result in state ─────────────────────────────────────
      _currentImage = GeneratedImageResult(
        imageBytes: imageBytes,
        provider: response.modelUsed,
        prompt: prompt.trim(),
        remoteUrl: response.imageUrl,
        conversationId: conversationId,
      );

      await _analytics.logFeatureUsed(AppFeature.imageGeneration);

      _isGenerating = false;
      notifyListeners();
      return true;
    } on AiExhaustedException catch (e) {
      _errorMessage = e.message;
      _isGenerating = false;
      notifyListeners();
      return false;
    } on AiException catch (e) {
      _errorMessage = e.message;
      _isGenerating = false;
      notifyListeners();
      return false;
    } catch (e) {
      _errorMessage = 'something_went_wrong';
      _isGenerating = false;
      notifyListeners();
      return false;
    }
  }

  // ── Save to Gallery ────────────────────────────────────────────────────────

  Future<bool> saveCurrentImageToGallery() async {
    if (_currentImage == null) return false;

    final fileName =
        'ai_voice_genie_${DateTime.now().millisecondsSinceEpoch}.png';
    return _repository.saveToGallery(_currentImage!.imageBytes, fileName);
  }

  // ── Clear State ────────────────────────────────────────────────────────────

  void clearImage() {
    _currentImage = null;
    _errorMessage = null;
    notifyListeners();
  }

  void clearError() {
    if (_errorMessage != null) {
      _errorMessage = null;
      notifyListeners();
    }
  }
}