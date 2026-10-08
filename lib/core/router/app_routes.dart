import 'package:ai_voice_genie/features/auth/presentation/auth_screen.dart';
import 'package:ai_voice_genie/features/chat/presentation/chat_screen.dart';
import 'package:ai_voice_genie/features/legal_section/presentation/legal_screen.dart';
import 'package:ai_voice_genie/features/onboarding/presentation/onboarding_screen.dart';
import 'package:ai_voice_genie/features/profile/presentation/profile_view.dart';
import 'package:ai_voice_genie/features/splash/presentation/splash_screen.dart';
import 'package:flutter/material.dart';

import '../../features/chat/presentation/chat_detail_screen.dart';
import '../../features/home/presentation/tab_bar_screen.dart';
import '../../features/key_setup/presentation/key_setup_screen.dart';
import '../enums/app_enums.dart';

/// Centralized route management for AI Voice Genie.
///
/// All navigation must go through this class.
/// Never use Navigator.push directly.

/// Global route observer to track navigation events.
final RouteObserver<ModalRoute<void>> routeObserver =
    RouteObserver<ModalRoute<void>>();

///
/// Usage:
/// ```dart
/// AppRoutes.navigateTo(context, AppRoutes.chat);
/// AppRoutes.navigateAndReplace(context, AppRoutes.home);
/// AppRoutes.navigateAndRemoveUntil(context, AppRoutes.home);
///
/// // With arguments
/// AppRoutes.navigateTo(
///   context,
///   AppRoutes.chatDetail,
///   arguments: ChatDetailArguments(conversationId: 'abc123'),
/// );
/// ```

// =============================================================================
// TRANSITION TYPES
// =============================================================================

enum TransitionType {
  slide, // Right-to-left (default for most screens)
  slideUp, // Bottom-to-top (bottom sheets, modals)
  fade, // Cross-fade (splash, auth root)
  scale, // Scale + fade (dialogs, celebratory screens)
  none, // Instant (no animation)
}

// =============================================================================
// APP ROUTES
// =============================================================================

class AppRoutes {
  /// Global navigator key for out-of-context navigation and snackbar alerts (e.g. session expired).
  static final GlobalKey<NavigatorState> navigatorKey =
      GlobalKey<NavigatorState>();

  // ── Route Name Constants ───────────────────────────────────────────────────

  /// Splash screen — initial route
  static const String splash = '/';

  /// Auth
  static const String login = '/login';

  /// Onboarding — shown once after first install
  static const String onboarding = '/onboarding';

  /// API Key setup — shown after first sign-in
  static const String keySetup = '/key-setup';

  /// Main tab bar screen — entry after auth
  static const String tabBar = '/tab-bar';

  /// Chat / Text conversation
  static const String chat = '/chat';
  static const String chatDetail = '/chat-detail';

  /// API key management
  static const String apiKeyManagement = '/api-keys';

  /// Edit profile
  static const String profileEdit = '/profile/edit';

  /// About app
  static const String about = '/about';

  /// Exception / 404
  static const String exception = '/exception';

  /// Privacy Policy
  static const String privacy = '/about/privacy-policy';

  /// Terms of Service
  static const String terms = '/about/terms-of-service';

  // ── Navigation Helpers ─────────────────────────────────────────────────────

  /// Push a new route onto the stack.
  ///
  /// User can go back to the previous screen.
  static Future<T?> navigateTo<T>(
    BuildContext context,
    String routeName, {
    Object? arguments,
  }) {
    return Navigator.of(context).pushNamed<T>(
      routeName,
      arguments: arguments,
    );
  }

  /// Replace the current route with a new one.
  ///
  /// User cannot go back to the replaced screen.
  static Future<T?> navigateAndReplace<T, TO>(
    BuildContext context,
    String routeName, {
    Object? arguments,
    TO? result,
  }) {
    return Navigator.of(context).pushReplacementNamed<T, TO>(
      routeName,
      arguments: arguments,
      result: result,
    );
  }

  /// Clear the entire stack and navigate to a new route.
  ///
  /// Used for: login → home, splash → home.
  static Future<T?> navigateAndRemoveUntil<T>(
    BuildContext context,
    String routeName, {
    Object? arguments,
  }) {
    return Navigator.of(context).pushNamedAndRemoveUntil<T>(
      routeName,
      (route) => false,
      arguments: arguments,
    );
  }

  /// Pop back to a specific route in the stack.
  static Future<T?> navigateAndRemoveUntilRoute<T>(
    BuildContext context,
    String routeName, {
    required String untilRoute,
    Object? arguments,
  }) {
    return Navigator.of(context).pushNamedAndRemoveUntil<T>(
      routeName,
      ModalRoute.withName(untilRoute),
      arguments: arguments,
    );
  }

  /// Pop the current route safely if there is a route on the stack.
  static void pop<T>(BuildContext context, [T? result]) {
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop<T>(result);
    }
  }

  /// Pop back to the very first route.
  static void popToFirst(BuildContext context) {
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  /// Pop back to a named route.
  static void popUntilRoute(BuildContext context, String routeName) {
    Navigator.of(context).popUntil(ModalRoute.withName(routeName));
  }

  /// Returns true if there is a route to pop back to.
  static bool canPop(BuildContext context) => Navigator.of(context).canPop();

  // ── Route Generator ────────────────────────────────────────────────────────

  /// Main route generator — wired to MaterialApp.onGenerateRoute.
  ///
  /// All routes are matched here. Unknown routes fall through to ExceptionScreen.
  static Route<dynamic> generateRoute(RouteSettings settings) {
    debugPrint('🔀 Route: ${settings.name}');

    final arguments = settings.arguments;

    switch (settings.name) {
      // ── Splash ─────────────────────────────────────────────────────────────
      case splash:
        // Lazy import — screen will be created in Phase 1
        return _buildRoute(
          const SplashScreen(),
          settings,
          TransitionType.fade,
        );

      // ── Auth ───────────────────────────────────────────────────────────────
      case login:
        return _buildRoute(
          const AuthScreen(),
          settings,
          TransitionType.scale,
        );

      // ── Onboarding ─────────────────────────────────────────────────────────
      case onboarding:
        return _buildRoute(
          const OnboardingScreen(),
          settings,
          TransitionType.slide,
        );

      // ── Key Setup ──────────────────────────────────────────────────────────
      case keySetup:
        return _buildRoute(
          const KeySetupScreen(),
          settings,
          TransitionType.slide,
        );

      // ── Tab Bar (Home) ────────────────────────────────────────────────────────
      case tabBar:
        return _buildRoute(
          const TabBarScreen(),
          settings,
          TransitionType.scale,
        );

      // ── Chat ───────────────────────────────────────────────────────────────
      case chat:
        // Extract optional ChatArguments to honour voice auto-start from Home.
        final chatArgs = arguments is ChatArguments ? arguments : null;
        return _buildRoute(
          ChatScreen(startMode: chatArgs?.startMode ?? ChatStartMode.normal),
          settings,
          TransitionType.fade,
        );

      case chatDetail:
        if (arguments is ChatDetailArguments) {
          return _buildRoute(
              ChatDetailScreen(
                  conversationId: arguments.conversationId,
                  initialTitle: arguments.initialTitle),
              settings,
              TransitionType.fade,
              const Duration(milliseconds: 700));
        } else {
          return _buildRoute(const ChatDetailScreen(), settings,
              TransitionType.fade, const Duration(milliseconds: 700));
        }

      // ── API Key Management ─────────────────────────────────────────────────
      case apiKeyManagement:
        final initialProvider = arguments is AiProviderId ? arguments : null;
        return _buildRoute(
          KeySetupScreen(
            isInitialSetup: false,
            initialFocusProvider: initialProvider,
          ),
          settings,
          TransitionType.slide,
        );

      // ── Profile Edit ───────────────────────────────────────────────────────
      case profileEdit:
        return _buildRoute(
          const EditProfileScreen(),
          settings,
          TransitionType.slideUp,
        );

      // ── About ──────────────────────────────────────────────────────────────
      case about:
        return _buildRoute(
          const AboutScreen(),
          settings,
          TransitionType.slide,
        );

      case privacy || terms:
        Map<String, dynamic>? value =
            arguments is Map<String, dynamic> ? arguments : null;
        return _buildRoute(
          LegalScreen(title: value?['title'], mdFileName: value?['mdFileName']),
          settings,
          TransitionType.slideUp,
        );
      // ── Exception / 404 ────────────────────────────────────────────────────
      default:
        return _buildErrorRoute(settings);
    }
  }

  // ── Private Route Builders ─────────────────────────────────────────────────

  /// Build a route with the specified transition type.
  static Route<dynamic> _buildRoute(Widget screen,
      [RouteSettings? settings,
      TransitionType transition = TransitionType.slide,
      Duration? dur = const Duration(milliseconds: 300)]) {
    // Default slide uses MaterialPageRoute for standard platform feel
    if (transition == TransitionType.slide) {
      return MaterialPageRoute(builder: (_) => screen, settings: settings);
    }
    return _buildCustomRoute(screen, settings, transition, duration: dur!);
  }

  /// Build a custom animated route.
  static PageRouteBuilder _buildCustomRoute(
    Widget screen,
    RouteSettings? settings,
    TransitionType transition, {
    Duration duration = const Duration(milliseconds: 300),
  }) {
    return PageRouteBuilder(
      pageBuilder: (context, animation, secondaryAnimation) => screen,
      transitionDuration: duration,
      settings: settings,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeInOut,
        );

        switch (transition) {
          case TransitionType.fade:
            return FadeTransition(opacity: animation, child: child);

          case TransitionType.slideUp:
            return SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0.0, 1.0),
                end: Offset.zero,
              ).animate(curved),
              child: child,
            );

          case TransitionType.scale:
            return ScaleTransition(
              scale: Tween<double>(begin: 0.85, end: 1.0).animate(curved),
              child: FadeTransition(opacity: animation, child: child),
            );

          case TransitionType.none:
            return child;

          case TransitionType.slide:
            return SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(1.0, 0.0),
                end: Offset.zero,
              ).animate(curved),
              child: child,
            );
        }
      },
    );
  }

  /// Build the 404 error route for unregistered route names.
  static MaterialPageRoute _buildErrorRoute(RouteSettings settings) {
    return MaterialPageRoute(
      builder: (_) => _PlaceholderScreen(
        label: 'ExceptionScreen — Route not found: ${settings.name}',
      ),
      settings: settings,
    );
  }
}

// =============================================================================
// PLACEHOLDER SCREEN
// Used during Phase 0 — replaced with real screens in subsequent phases.
// =============================================================================

class _PlaceholderScreen extends StatelessWidget {
  final String label;
  const _PlaceholderScreen({required this.label});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(label)),
      body: Center(
        child: Text(
          label,
          style: Theme.of(context).textTheme.bodyLarge,
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}

// =============================================================================
// TYPED ROUTE ARGUMENT CLASSES
// =============================================================================

/// Base class for all typed route arguments.
abstract class RouteArguments {
  const RouteArguments();
}

/// Arguments for ChatDetailScreen — open a specific conversation or view active new chat.
class ChatDetailArguments extends RouteArguments {
  final String? conversationId;
  final String? initialTitle;

  const ChatDetailArguments({
    this.conversationId,
    this.initialTitle,
  });
}

/// Arguments for ImageGeneratorScreen — optional pre-filled prompt.
class ImageGeneratorArguments extends RouteArguments {
  final String? initialPrompt;

  const ImageGeneratorArguments({this.initialPrompt});
}

/// Arguments for PdfReaderScreen — open with a specific PDF.
class PdfReaderArguments extends RouteArguments {
  final String? pdfPath;
  final String? pdfName;
  final String? conversationId;

  const PdfReaderArguments({
    this.pdfPath,
    this.pdfName,
    this.conversationId,
  });
}

/// Arguments for ApiKeyManagementScreen — optionally focus on a provider.
class ApiKeyManagementArguments extends RouteArguments {
  /// If set, scroll directly to this provider's card on open
  final String? focusProviderId;

  const ApiKeyManagementArguments({this.focusProviderId});
}

/// Arguments for [ChatScreen] — controls whether the screen opens in
/// voice-dictation mode (mic starts automatically) or in the default
/// text-compose mode.
class ChatArguments extends RouteArguments {
  /// Determines how the chat screen initializes after navigation.
  ///
  /// [ChatStartMode.voice] — mic listening begins immediately after the
  /// first frame, allowing hands-free dictation from the Home voice button.
  ///
  /// [ChatStartMode.normal] — default; user types manually.
  final ChatStartMode startMode;

  const ChatArguments({this.startMode = ChatStartMode.normal});
}
