import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/enums/app_enums.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/preferences/ai_preferences_provider.dart';
import '../../../../core/router/app_routes.dart';
import '../../../../core/utils/status_message_utils.dart';
import '../../../voice_speech/presentation/voice_speech_provider.dart';

/// Supported quick exploration action categories
enum QuickActionType {
  askQuestion,
  summarizePdf,
  generateImage,
  analyzeImage,
  generatePdf,
  generateCode,
}

/// ViewModel for IntroScreen following MVVM architecture.
///
/// Encapsulates:
/// - Time-based greeting calculation.
/// - Guarded STT availability checks and voice chat navigation.
/// - Quick action routing with context-mounted safety.
/// - Decoupled business logic with zero memory leaks.
class IntroViewModel extends ChangeNotifier {
  /// Computes a localized greeting according to the current local hour.
  String getGreeting(BuildContext context) {
    final hour = DateTime.now().hour;
    if (hour < 12) {
      return context.l10n.morning;
    } else if (hour < 17) {
      return context.l10n.afternoon;
    } else {
      return context.l10n.evening;
    }
  }

  /// Handles tapping the primary Voice Assistant mic button.
  ///
  /// Performs availability check on STT engines and navigates directly into voice mode.
  /// Validates [context.mounted] before interacting with UI or router.
  Future<void> handleVoiceAssistantTap(BuildContext context) async {
    if (!context.mounted) return;

    final voiceProvider = context.read<VoiceProvider>();
    final l10n = context.l10n;

    // Guard: If STT is not supported or active on this device, alert the user
    if (!voiceProvider.isSttAvailable || voiceProvider.isUnavailable) {
      if (context.mounted) {
        context.showError(l10n.speechTextUnavailable);
      }
      return;
    }

    // Launch chat in dedicated voice mode
    if (context.mounted) {
      await AppRoutes.navigateTo(
        context,
        AppRoutes.chat,
        arguments: const ChatArguments(startMode: ChatStartMode.voice),
      );
    }
  }

  /// Opens the standard text-based chat interface.
  Future<void> openDirectChat(BuildContext context) async {
    if (!context.mounted) return;
    await AppRoutes.navigateTo(context, AppRoutes.chat);
  }

  /// Sets the selected provider as preferred and navigates directly into chat.
  Future<void> selectEngineAndChat(
    BuildContext context, {
    required AiProviderId provider,
  }) async {
    if (!context.mounted) return;
    context.read<AiPreferencesProvider>().setPreferredProvider(provider);
    await AppRoutes.navigateTo(context, AppRoutes.chat);
  }

  /// Handles quick action triggers with deep-linked intent payloads.
  Future<void> handleQuickAction(
    BuildContext context, {
    required QuickActionType action,
  }) async {
    if (!context.mounted) return;

    switch (action) {
      case QuickActionType.askQuestion:
        await AppRoutes.navigateTo(
          context,
          AppRoutes.chat,
          arguments: const ChatArguments(
            initialAction: ChatInitialAction.askQuestion,
          ),
        );
        break;
      case QuickActionType.summarizePdf:
        await AppRoutes.navigateTo(
          context,
          AppRoutes.chat,
          arguments: const ChatArguments(
            initialAction: ChatInitialAction.summarizePdf,
          ),
        );
        break;
      case QuickActionType.generateImage:
        await AppRoutes.navigateTo(
          context,
          AppRoutes.chat,
          arguments: const ChatArguments(
            initialAction: ChatInitialAction.generateImage,
          ),
        );
        break;
      case QuickActionType.analyzeImage:
        await AppRoutes.navigateTo(
          context,
          AppRoutes.chat,
          arguments: const ChatArguments(
            initialAction: ChatInitialAction.analyzeImage,
          ),
        );
        break;
      case QuickActionType.generatePdf:
        await AppRoutes.navigateTo(
          context,
          AppRoutes.chat,
          arguments: const ChatArguments(
            initialAction: ChatInitialAction.generatePdf,
          ),
        );
        break;
      case QuickActionType.generateCode:
        await AppRoutes.navigateTo(
          context,
          AppRoutes.chat,
          arguments: const ChatArguments(
            initialAction: ChatInitialAction.generateCode,
          ),
        );
        break;
    }
  }

  @override
  void dispose() {
    // Clean up any internal listeners or timers if added in future
    super.dispose();
  }
}
