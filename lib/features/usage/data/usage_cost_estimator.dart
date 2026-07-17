import '../../../core/enums/app_enums.dart';
import 'usage_pricing_table.dart';

/// Computes the estimated USD cost of an AI request.
///
/// Formula:
///   inputCost  = inputTokens  / 1,000,000 * inputPricePerMillion
///   outputCost = outputTokens / 1,000,000 * outputPricePerMillion
///   imageCost  = imageCount * pricePerImage
///   totalCost  = inputCost + outputCost + imageCost
///
/// Returns 0.0 if pricing is unavailable for the provider.
abstract final class UsageCostEstimator {
  /// Estimates the cost for a text / vision / PDF request.
  ///
  /// [provider]     — which AI provider handled the request
  /// [inputTokens]  — number of input/prompt tokens consumed
  /// [outputTokens] — number of output/completion tokens generated
  static double estimateTextCost({
    required AiProviderId provider,
    required int inputTokens,
    required int outputTokens,
  }) {
    final inputPrice = UsagePricingTable.inputPricePerMillion(provider);
    final outputPrice = UsagePricingTable.outputPricePerMillion(provider);

    if (inputPrice == null || outputPrice == null) return 0.0;

    final inputCost = inputTokens / 1000000 * inputPrice;
    final outputCost = outputTokens / 1000000 * outputPrice;
    return inputCost + outputCost;
  }

  /// Estimates the cost for an image generation request.
  ///
  /// [provider]   — which AI provider generated the images
  /// [imageCount] — number of images generated
  /// [quality]    — quality level (low / medium / high)
  static double estimateImageCost({
    required AiProviderId provider,
    required int imageCount,
    ImageQuality quality = ImageQuality.low,
  }) {
    if (imageCount <= 0) return 0.0;
    final pricePerImage =
        UsagePricingTable.imageGenerationPrice(provider, quality);
    return imageCount * pricePerImage;
  }

  /// Estimates the combined cost for any capability type.
  ///
  /// This is the single method to call from the orchestrator/repository.
  static double estimate({
    required AiProviderId provider,
    required AiCapability capability,
    required int inputTokens,
    required int outputTokens,
    int imageCount = 0,
    ImageQuality imageQuality = ImageQuality.low,
  }) {
    if (capability == AiCapability.imageGeneration) {
      return estimateImageCost(
        provider: provider,
        imageCount: imageCount,
        quality: imageQuality,
      );
    }
    return estimateTextCost(
      provider: provider,
      inputTokens: inputTokens,
      outputTokens: outputTokens,
    );
  }
}
