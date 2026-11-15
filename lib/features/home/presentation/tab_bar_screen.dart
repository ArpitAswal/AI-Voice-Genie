import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/extensions/build_context_extensions.dart';
import '../../../core/localization/app_localizations.dart';
import '../../chat/presentation/chat_history_screen.dart';
import '../../intro/presentation/intro_screen.dart';
import '../../profile/presentation/profile_view.dart';
import 'viewmodel/home_nav_viewmodel.dart';
import 'widgets/adaptive_bottom_nav_bar.dart';
import 'widgets/adaptive_nav_rail.dart';

/// Root tab navigation shell for AI Voice Genie.
///
/// Implements responsive Material 3 navigation:
/// - Compact & Medium (< 840dp): Persistent bottom navigation bar with rounded top corners.
/// - Expanded (>= 840dp): Vertical side NavigationRail to maximize vertical canvas space.
/// - Handles Android back button double-press to exit gracefully with debounce.
/// - MVVM architecture via [HomeNavViewModel] with zero memory leaks.
class TabBarScreen extends StatefulWidget {
  const TabBarScreen({super.key});

  @override
  State<TabBarScreen> createState() => _TabBarScreenState();
}

class _TabBarScreenState extends State<TabBarScreen> {
  late final HomeNavViewModel _viewModel;

  @override
  void initState() {
    super.initState();
    // Initialize the ViewModel scoped to this screen's lifecycle
    _viewModel = HomeNavViewModel();
  }

  @override
  void dispose() {
    // Dispose ViewModel explicitly to eliminate memory leaks
    _viewModel.dispose();
    super.dispose();
  }

  /// Displays floating warning snackbar requesting second back-press to exit
  void _showExitSnackbar() {
    if (!mounted) return;

    final backgroundColor =
        context.isDark ? AppColors.cardDark : AppColors.cardLight;
    final textColor = context.isDark ? Colors.white : Colors.black;

    ScaffoldMessenger.of(context).removeCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          context.l10n.pressBackAgainToExit,
          style: TextStyle(
            color: textColor,
            fontWeight: FontWeight.w500,
          ),
        ),
        backgroundColor: backgroundColor,
        duration: const Duration(seconds: 4),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
            color:
                context.isDark ? AppColors.darkDivider : AppColors.lightDivider,
          ),
        ),
        margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Adaptive check: Wide viewports (Tablets in landscape / Desktop >= 840dp) use NavigationRail
    final isExpanded = context.isExpanded;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;

        // Delegate double-back logic to the ViewModel
        final shouldExit = _viewModel.handleBackPress(
          onShowExitWarning: () {
            if (mounted) _showExitSnackbar();
          },
        );

        if (shouldExit) {
          await SystemNavigator.pop();
        }
      },
      child: ListenableBuilder(
        listenable: _viewModel,
        builder: (context, _) {
          final activeIndex = _viewModel.currentIndex;

          if (isExpanded) {
            // ── Expanded Layout (>= 840dp): Side Navigation Rail ─────────────
            return Scaffold(
              body: Row(
                children: [
                  AdaptiveNavRail(
                    currentIndex: activeIndex,
                    onTabSelected: _viewModel.selectTab,
                  ),
                  Expanded(
                    child: _buildBody(activeIndex),
                  ),
                ],
              ),
            );
          }

          // ── Compact / Medium Layout (< 840dp): Bottom Navigation Bar ───────
          return Scaffold(
            // Bottom navigation bar automatically consumes bottom safe area insets
            bottomNavigationBar: AdaptiveBottomNavBar(
              currentIndex: activeIndex,
              onTabSelected: _viewModel.selectTab,
            ),
            body: _buildBody(activeIndex),
          );
        },
      ),
    );
  }

  /// Preserves screen state across tab switches via [IndexedStack]
  Widget _buildBody(int activeIndex) {
    return IndexedStack(
      index: activeIndex,
      children: const [
        IntroScreen(),
        ConversationHistoryScreen(),
        ProfileScreen(),
      ],
    );
  }
}
