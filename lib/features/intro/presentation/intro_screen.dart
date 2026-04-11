import 'package:ai_voice_genie/core/constants/app_constants.dart';
import 'package:ai_voice_genie/core/extensions/build_context_extensions.dart';
import 'package:ai_voice_genie/core/localization/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_colors.dart';
import '../../auth/presentation/auth_provider.dart';

class IntroScreen extends StatelessWidget {
  const IntroScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top, // Top Nav space
        bottom: MediaQuery.of(context).padding.bottom + 80, // Bottom Nav space
        left: context.horizontalPadding,
        right: context.horizontalPadding,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // The selected tab body
          _buildTopNavBar(context),
          SizedBox(height: (context.isTablet) ? 24 : 16),
          _buildHero(context),
          SizedBox(height: (context.isTablet) ? 40 : 30),
          _buildQuickActions(context),
          SizedBox(height: (context.isTablet) ? 40 : 30),
          _buildIntelligentEngines(context),
          SizedBox(height: (context.isTablet) ? 30 : 20),
          _buildTapToSpeak(context),
        ],
      ),
    );
  }

  Widget _buildHero(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _getGreeting(context),
          style: Theme.of(context).textTheme.displayMedium?.copyWith(
              color: context.isDark
                  ? AppColors.primaryLight
                  : AppColors.primaryDark),
        ),
        const SizedBox(height: 4),
        Text(
          context.l10n.aiAssist,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      ],
    );
  }

  Widget _buildQuickActions(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(context.l10n.askTodo,
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _QuickActionButton(
                icon: Icons.chat_bubble_rounded,
                label: context.l10n.askQuestion,
                iconColor: AppColors.primaryLight),
            _QuickActionButton(
                icon: Icons.palette_rounded,
                label: context.l10n.generateImage,
                iconColor: AppColors.purpleAccent),
            _QuickActionButton(
                icon: Icons.upload_file_rounded,
                label: context.l10n.uploadPdf,
                iconColor: AppColors.tealAccent),
          ],
        ),
      ],
    );
  }

  Widget _buildIntelligentEngines(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(context.l10n.intelligentModels,
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),
        ListView(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: EdgeInsets.zero,
          children: [
            _EngineCard(
                title: AppConstants.openAiDisplayName,
                description: context.l10n.chatGPTModelMessage,
                capability: AppConstants.openAICapabilities,
                faIcon: FontAwesomeIcons.openai,
                gradient: AppColors.openAIGradient,
                shadowColor: AppColors.openAiBrand),
            const SizedBox(height: 16),
            _EngineCard(
                title: AppConstants.geminiDisplayName,
                description: context.l10n.geminiModelMessage,
                capability: AppConstants.geminiAICapabilities,
                faIcon: FontAwesomeIcons.gemini,
                gradient: AppColors.geminiGradient,
                shadowColor: AppColors.geminiBrand),
            const SizedBox(height: 16),
            _EngineCard(
                title: AppConstants.claudeDisplayName,
                description: context.l10n.claudeModelMessage,
                capability: AppConstants.claudeAICapabilities,
                faIcon: FontAwesomeIcons.claude,
                gradient: AppColors.claudeGradient,
                shadowColor: AppColors.claudeBrand),
          ],
        ),
      ],
    );
  }

  Widget _buildTapToSpeak(BuildContext context) {
    return Center(
      child: Column(
        children: [
          SizedBox(
            width: 140,
            height: 140,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  width: 110,
                  height: 110,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: context.isDark
                        ? AppColors.purpleAccent.withValues(alpha: 0.1)
                        : AppColors.tealAccent.withValues(alpha: 0.1),
                  ),
                ),
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: (context.isDark)
                        ? AppColors.darkVoiceGradient
                        : AppColors.lightVoiceGradient,
                    boxShadow: [
                      BoxShadow(
                        color: (context.isDark)
                            ? AppColors.primaryDark.withValues(alpha: 0.4)
                            : AppColors.primaryLight.withValues(alpha: 0.4),
                        blurRadius: 20,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: Center(
                    child: Icon(Icons.mic_rounded,
                        color: Colors.white, size: context.isTablet ? 44 : 36),
                  ),
                ),
              ],
            ),
          ),
          Text(context.l10n.tapToSpeak.toUpperCase(),
              style: context.textTheme.bodyLarge?.copyWith(
                fontWeight: FontWeight.bold,
                letterSpacing: 1.5,
              )),
        ],
      ),
    );
  }

  Widget _buildTopNavBar(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final user = authProvider.currentUser;
    final userName = user?.displayName ?? context.l10n.user;
    final userInitial = userName.isNotEmpty
        ? userName[0].toUpperCase()
        : context.l10n.user[0].toUpperCase();

    return Row(
      mainAxisAlignment: MainAxisAlignment.start,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        CircleAvatar(
          radius: 23,
          backgroundColor:
              context.isDark ? AppColors.accentDark : AppColors.accentLight,
          child: Text(
            userInitial,
            style: TextStyle(
                color: context.isDark
                    ? AppColors.primaryLight
                    : AppColors.primaryDark,
                fontWeight: FontWeight.bold,
                fontSize: context.isTablet ? 36 : 24),
          ),
        ),
        SizedBox(width: context.isTablet ? 16 : 8),
        Flexible(
          child: Text(
            userName,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: context.isDark ? AppColors.primaryLight : AppColors.primaryDark
            ),
          ),
        ),
      ],
    );
  }

  String _getGreeting(BuildContext context) {
      final hour = DateTime.now().hour;

      if (hour < 12) {
        return context.l10n.morning;
      } else if (hour < 17) {
        return context.l10n.afternoon;
      } else {
        return context.l10n.evening;
      }
  }
}

class _QuickActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color iconColor;

  const _QuickActionButton(
      {required this.icon, required this.label, required this.iconColor});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: (context.isDark) ? AppColors.cardDark : AppColors.cardLight,
        borderRadius: BorderRadius.circular(30),
        border: Border.all(
            color: context.theme.dividerTheme.color ?? AppColors.grey),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: iconColor, size: 20),
          const SizedBox(width: 8),
          Text(label, style: Theme.of(context).textTheme.headlineSmall),
        ],
      ),
    );
  }
}

class _EngineCard extends StatelessWidget {
  final String title;
  final String description;
  final String capability;
  final FaIconData faIcon;
  final LinearGradient gradient;
  final Color shadowColor;

  const _EngineCard({
    required this.title,
    required this.description,
    required this.capability,
    required this.faIcon,
    required this.gradient,
    required this.shadowColor,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(context.horizontalPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    gradient: gradient,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: shadowColor.withValues(alpha: 0.3),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Center(child: FaIcon(faIcon, color: Colors.white)),
                ),
                const SizedBox(width: 12),
                Flexible(
                  child: Text(
                    title,
                    style: context.textTheme.headlineLarge,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              description,
              style: context.textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            Text(
              capability,
              style: context.textTheme.bodySmall
                  ?.copyWith(color: shadowColor, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }
}
