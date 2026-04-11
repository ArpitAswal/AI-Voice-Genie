import 'package:ai_voice_genie/core/extensions/build_context_extensions.dart';
import 'package:ai_voice_genie/core/localization/app_localizations.dart';
import 'package:ai_voice_genie/features/intro/presentation/intro_screen.dart';
import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      bottomNavigationBar: _buildBottomNavBar(),
      body: Stack(
        children: [
          // The selected tab body
          SafeArea(child: _buildBody()),

          // Floating Top Navbar
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: _buildTopNavBar(),
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    switch (_currentIndex) {
      case 0:
        return const IntroScreen();
      case 1:
        return const Center(
            child: Text("History Tab", style: TextStyle(color: Colors.white)));
      case 2:
        return const Center(
            child: Text("Settings Tab", style: TextStyle(color: Colors.white)));
      default:
        return const IntroScreen();
    }
  }

  Widget _buildTopNavBar() {
    return Container(
        padding: EdgeInsets.only(
          top: MediaQuery.of(context).padding.top,
          left: 24,
          right: 24,
          bottom: MediaQuery.of(context).padding.bottom,
        ),
        decoration: BoxDecoration(
            gradient: context.isDark
                ? AppColors.primaryGradientDark
                : null),
        child: const SizedBox());
  }

  Widget _buildBottomNavBar() => ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        child: Container(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).padding.bottom,
            top: 6,
          ),
          decoration: BoxDecoration(
            gradient: context.isDark
                ? AppColors.primaryGradientDark
                : AppColors.primaryGradientLight,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildNavItem(0, Icons.home_outlined, context.l10n.home, context),
              _buildNavItem(
                  1, Icons.chat_bubble_outline, context.l10n.history, context),
              _buildNavItem(
                  2, Icons.settings_outlined, context.l10n.settings, context),
            ],
          ),
        ),
      );

  Widget _buildNavItem(
      int index, IconData icon, String label, BuildContext context) {
    final isSelected = _currentIndex == index;

    return GestureDetector(
      onTap: () => setState(() => _currentIndex = index),
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 600),
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? (context.isDark
                  ? AppColors.cardDark.withValues(alpha: 0.5)
                  : AppColors.cardLight.withValues(alpha: 0.5))
              : null,
          borderRadius: BorderRadius.circular(32),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon,
                color: context.isDark
                    ? AppColors.primaryLight
                    : AppColors.primaryDark),
            const SizedBox(height: 4),
            Text(
              label.toUpperCase(),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: (context.isDark
                      ? AppColors.primaryLight
                      : AppColors.primaryDark),
                  fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }
}
