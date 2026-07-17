import 'package:ai_voice_genie/core/localization/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/enums/app_enums.dart';
import '../../../../core/extensions/build_context_extensions.dart';
import '../../../../core/utils/status_message_utils.dart';
import '../../../auth/presentation/auth_provider.dart';
import '../usage_provider.dart';

/// Bottom sheet for adding, editing, or removing a monthly budget for a
/// specific AI provider.
class BudgetEditorSheet extends StatefulWidget {
  final AiProviderId provider;
  final double? existingBudget;

  const BudgetEditorSheet({
    super.key,
    required this.provider,
    this.existingBudget,
  });

  /// Show the sheet and return true if the budget was saved/deleted.
  static Future<bool?> show(
    BuildContext context, {
    required AiProviderId provider,
    double? existingBudget,
  }) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => BudgetEditorSheet(
        provider: provider,
        existingBudget: existingBudget,
      ),
    );
  }

  @override
  State<BudgetEditorSheet> createState() => _BudgetEditorSheetState();
}

class _BudgetEditorSheetState extends State<BudgetEditorSheet> {
  late final TextEditingController _controller;
  final _formKey = GlobalKey<FormState>();
  final ValueNotifier<bool> _isSaving = ValueNotifier(false);

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(
      text: widget.existingBudget != null
          ? widget.existingBudget!.toStringAsFixed(2)
          : '',
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    _isSaving.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final amount = double.tryParse(_controller.text.trim());
    if (amount == null || amount <= 0) return;

    _isSaving.value = true;
    try {
      final uid = context.read<AuthProvider>().currentUser!.uid;
      await context.read<UsageProvider>().setBudget(
            uid: uid,
            provider: widget.provider,
            amountUsd: amount,
          );
      if (mounted) {
        Navigator.of(context).pop(true);
        context.showSuccess(context.l10n.budgetSaved);
      }
    } catch (_) {
      if (mounted) {
        context.showError(context.l10n.budgetSaveFailed);
      }
    } finally {
      if (mounted) _isSaving.value = false;
    }
  }

  Future<void> _delete() async {
    _isSaving.value = true;
    try {
      final uid = context.read<AuthProvider>().currentUser!.uid;
      await context.read<UsageProvider>().removeBudget(
            uid: uid,
            provider: widget.provider,
          );
      if (mounted) {
        Navigator.of(context).pop(true);
        context.showSuccess(context.l10n.budgetRemoved);
      }
    } catch (_) {
      if (mounted) {
        context.showError(context.l10n.budgetRemoveFailed);
      }
    } finally {
      if (mounted) _isSaving.value = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDark;
    final providerName = widget.provider.displayName;
    final hasExisting = widget.existingBudget != null;

    return Padding(
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? AppColors.cardDark : AppColors.cardLight,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        ),
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle bar
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: isDark ? Colors.grey[700] : Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Title
            Text(
              hasExisting
                  ? context.l10n.editMonthlyBudget
                  : context.l10n.setMonthlyBudget,
              style: context.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '$providerName • ${context.l10n.monthlySpendingLimit}',
              style: context.textTheme.bodySmall?.copyWith(
                color: context.isDark
                    ? AppColors.darkTextPrimary.withValues(alpha: 0.6)
                    : AppColors.lightTextPrimary.withValues(alpha: 0.55),
              ),
            ),
            const SizedBox(height: 24),

            // Budget input field
            Form(
              key: _formKey,
              child: TextFormField(
                controller: _controller,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
                ],
                decoration: InputDecoration(
                  prefixIcon: Padding(
                    padding: const EdgeInsets.only(left: 16, right: 8),
                    child: Text(
                      '\$',
                      style: context.textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: context.primaryColor,
                      ),
                    ),
                  ),
                  prefixIconConstraints: const BoxConstraints(minWidth: 0),
                  hintText: '10.00',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 18,
                  ),
                ),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) {
                    return context.l10n.enterBudgetAmount;
                  }
                  final parsed = double.tryParse(v.trim());
                  if (parsed == null || parsed <= 0) {
                    return context.l10n.enterValidAmount;
                  }
                  return null;
                },
              ),
            ),

            const SizedBox(height: 8),
            Text(
              context.l10n.translate('usage_disclaimer'),
              style: context.textTheme.bodySmall?.copyWith(
                color: context.isDark
                    ? AppColors.darkTextPrimary.withValues(alpha: 0.5)
                    : AppColors.lightTextPrimary.withValues(alpha: 0.45),
                fontStyle: FontStyle.italic,
              ),
            ),

            const SizedBox(height: 28),

            // Action buttons
            ValueListenableBuilder<bool>(
              valueListenable: _isSaving,
              builder: (context, isSaving, _) {
                return Column(
                  children: [
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        onPressed: isSaving ? null : _save,
                        style: ElevatedButton.styleFrom(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: isSaving
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              )
                            : Text(
                                hasExisting
                                    ? context.l10n.updateBudget
                                    : context.l10n.setBudget,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                      ),
                    ),
                    if (hasExisting) ...[
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: TextButton(
                          onPressed: isSaving ? null : _delete,
                          style: TextButton.styleFrom(
                            foregroundColor: AppColors.lightError,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          child: Text(
                            context.l10n.removeBudget,
                            style: const TextStyle(
                                fontSize: 16, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ),
                    ],
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
