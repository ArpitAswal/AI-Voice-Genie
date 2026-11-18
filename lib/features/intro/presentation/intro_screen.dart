import 'package:flutter/material.dart';

import '../../../core/extensions/build_context_extensions.dart';
import 'viewmodel/intro_viewmodel.dart';
import 'widgets/ai_engines_section.dart';
import 'widgets/intro_header_section.dart';
import 'widgets/quick_actions_section.dart';
import 'widgets/voice_mic_section.dart';

/// Adaptive Home/Intro landing screen for AI Voice Genie.
///
/// Responsive Architecture:
/// - Compact (< 600dp or height <= 550dp): Single scrollable column with centered Voice Mic CTA at the bottom.
/// - Medium & Expanded (>= 600dp):
///   - Natural top-to-bottom reading flow: Greeting -> Action Chips -> Full-width Responsive Model Cards.
///   - Eliminates dead zones: Cards breathe across the full width in a 2 or 3-column grid.
///   - Anchors Voice Assistant to a prominent Floating Action Button (FAB) at the bottom-right.
///
/// Engineering Guardrails:
/// - Uses [LayoutBuilder] constraints for adaptive composition.
/// - Tactical [SafeArea]: Handles top status bar insets cleanly while letting Scaffold handle bottom navigation.
/// - Dynamic keyboard handling: Content safely scrolls when virtual keyboard appears.
/// - Memory-safe MVVM lifecycle via [IntroViewModel].
class IntroScreen extends StatefulWidget {
  const IntroScreen({super.key});

  @override
  State<IntroScreen> createState() => _IntroScreenState();
}

class _IntroScreenState extends State<IntroScreen> {
  late final IntroViewModel _viewModel;

  @override
  void initState() {
    super.initState();
    // Initialize scoped ViewModel to guarantee zero memory leaks
    _viewModel = IntroViewModel();
  }

  @override
  void dispose() {
    // Explicit ViewModel disposal
    _viewModel.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Top status bar inset; bottom is handled by Scaffold in compact or custom FAB spacing
    final topPadding = MediaQuery.paddingOf(context).top;

    return SafeArea(
      top:
          false, // Custom header padding manages status bar for an immersive look
      bottom:
          false, // Prevent duplicate padding with TabBarScreen navigation bar
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          final height = constraints.maxHeight;

          // Compact screen guard (Mobile phones in portrait or landscape phones <= 550dp)
          if (width < 600.0 || height <= 550.0) {
            return _buildCompactLayout(
              context,
              topPadding: topPadding,
              isShortHeight: height <= 550.0,
            );
          }

          // Tablet Portrait, Tablet Landscape & Desktop (>= 600dp)
          // Visual balance: Full-width breathing cards + Bottom-Right anchored Voice Assistant FAB
          return _buildTabletLayout(
            context,
            topPadding: topPadding,
            isExpanded: width >= 840.0,
          );
        },
      ),
    );
  }

  // ── 1. Compact Layout (< 600dp or height <= 550dp: Mobile) ─────────────────
  Widget _buildCompactLayout(
    BuildContext context, {
    required double topPadding,
    required bool isShortHeight,
  }) {
    final verticalSpacing = isShortHeight ? 16.0 : 26.0;

    return SingleChildScrollView(
      physics: const ClampingScrollPhysics(),
      padding: EdgeInsets.symmetric(
        vertical: topPadding + (isShortHeight ? 10.0 : 16.0),
        horizontal: context.horizontalPadding,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          IntroHeaderSection(
              greeting: _viewModel.getGreeting(context),
              onOpenChat: () => _viewModel.openDirectChat(context),
              isShortHeight: isShortHeight),
          SizedBox(height: verticalSpacing),
          QuickActionsSection(
              onActionSelected: (action) =>
                  _viewModel.handleQuickAction(context, action: action),
              isShortHeight: isShortHeight),
          SizedBox(height: verticalSpacing),
          AiEnginesSection(
              onEngineSelected: (provider) =>
                  _viewModel.selectEngineAndChat(context, provider: provider),
              isShortHeight: isShortHeight),
          SizedBox(height: verticalSpacing),
          VoiceMicSection(
            onTap: () => _viewModel.handleVoiceAssistantTap(context),
          ),
        ],
      ),
    );
  }

  // ── 2. Tablet & Desktop Layout (>= 600dp: Real Estate Optimized) ───────────
  Widget _buildTabletLayout(
    BuildContext context, {
    required double topPadding,
    required bool isExpanded,
  }) {
    final horizontalPadding = isExpanded ? 32.0 : context.horizontalPadding;

    return SingleChildScrollView(
      physics: const ClampingScrollPhysics(),
      padding: EdgeInsets.symmetric(
        vertical: topPadding + 20.0,
        horizontal: horizontalPadding,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top: Greeting & direct chat button
          IntroHeaderSection(
            greeting: _viewModel.getGreeting(context),
            onOpenChat: () => _viewModel.openDirectChat(context),
          ),
          const SizedBox(height: 20),
          // Directly Below: Quick actions spanning horizontally across the width
          QuickActionsSection(
            onActionSelected: (action) =>
                _viewModel.handleQuickAction(context, action: action),
          ),
          const SizedBox(height: 26),
          // Full-Width Responsive AI Model Cards (2-column in portrait, 3-column in landscape)
          AiEnginesSection(
            onEngineSelected: (provider) =>
                _viewModel.selectEngineAndChat(context, provider: provider),
          ),
          const SizedBox(height: 26),
          // Primary Voice Assistant Action: Anchored as a large FAB at the bottom-right
          Align(
              alignment: context.isTablet && context.isExpanded
                  ? Alignment.bottomRight
                  : Alignment.center,
              child: context.isTablet && context.isExpanded
                  ? VoiceMicFab(
                      onTap: () => _viewModel.handleVoiceAssistantTap(context),
                    )
                  : VoiceMicSection(
                      onTap: () => _viewModel.handleVoiceAssistantTap(context),
                    )),
        ],
      ),
    );
  }
}
