import 'package:ai_voice_genie/core/localization/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/enums/app_enums.dart';
import '../../../../core/extensions/build_context_extensions.dart';
import '../../../../core/utils/status_message_utils.dart';
import '../../../../core/widgets/app_alert_dialog.dart';
import '../../../auth/presentation/auth_provider.dart';
import '../usage_provider.dart';

/// Bottom sheet for adding, editing, or removing a monthly budget for a
/// specific AI provider.
class BudgetEditorSheet extends StatefulWidget {
  final AiProviderId provider;
  final double? existingBudget;
  final double? existingUsed;

  const BudgetEditorSheet({
    super.key,
    required this.provider,
    this.existingBudget,
    this.existingUsed,
  });

  /// Show the sheet and return true if the budget was saved/deleted.
  static Future<bool?> show(
    BuildContext context, {
    required AiProviderId provider,
    double? existingBudget,
    double? existingUsed,
  }) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      showDragHandle: false,
      builder: (_) => BudgetEditorSheet(
        provider: provider,
        existingBudget: existingBudget,
        existingUsed: existingUsed,
      ),
    );
  }

  @override
  State<BudgetEditorSheet> createState() => _BudgetEditorSheetState();
}

class _BudgetEditorSheetState extends State<BudgetEditorSheet> {
  late final TextEditingController _controller;
  late final TextEditingController _usedController;
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
    _usedController = TextEditingController(
      text: widget.existingUsed != null
          ? widget.existingUsed!.toStringAsFixed(2)
          : '',
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    _usedController.dispose();
    _isSaving.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final amount = double.tryParse(_controller.text.trim());
    if (amount == null || amount <= 0) return;
    final alreadyUsed = double.tryParse(_usedController.text.trim());

    _isSaving.value = true;
    try {
      final uid = context.read<AuthProvider>().currentUser!.uid;
      await context.read<UsageProvider>().setBudget(
            uid: uid,
            provider: widget.provider,
            amountUsd: amount,
            alreadyUsedUsd: alreadyUsed,
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

  /// Shows a confirmation dialog before permanently removing the budget.
  /// Destructive actions always require explicit user confirmation (agent rule).
  Future<void> _confirmDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AppAlertDialog(
        title: Text(context.l10n.budgetRemoveConfirmTitle),
        content: Text(context.l10n.budgetRemoveConfirmMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(context.l10n.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: TextButton.styleFrom(foregroundColor: AppColors.lightError),
            child: Text(context.l10n.removeBudget),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await _delete();
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
        child: SafeArea(
          bottom: false,
          child: Container(
            decoration: BoxDecoration(
              color: isDark ? AppColors.cardDark : AppColors.cardLight,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(32)),
            ),
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                                hasExisting
                                    ? context.l10n.editTotalBudget
                                    : context.l10n.setTotalBudget,
                                style: context.textTheme.titleLarge),
                            const SizedBox(height: 4),
                            Text(
                              '$providerName • ${context.l10n.totalSpendingLimit}',
                              style: context.textTheme.bodySmall?.copyWith(
                                color: context.isDark
                                    ? AppColors.darkTextPrimary
                                        .withValues(alpha: 0.6)
                                    : AppColors.lightTextPrimary
                                        .withValues(alpha: 0.55),
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: Icon(
                          Icons.close,
                          color: context.isDark
                              ? AppColors.darkTextPrimary.withValues(alpha: 0.6)
                              : AppColors.lightTextPrimary
                                  .withValues(alpha: 0.55),
                        ),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Budget input field
                  Text(
                    context.l10n.totalSpendingLimit,
                    style: context.textTheme.bodySmall?.copyWith(
                      color: context.isDark
                          ? AppColors.darkTextPrimary.withValues(alpha: 0.6)
                          : AppColors.lightTextPrimary.withValues(alpha: 0.55),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Form(
                    key: _formKey,
                    child: TextFormField(
                      controller: _controller,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(
                            RegExp(r'^\d+\.?\d{0,2}')),
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
                        prefixIconConstraints:
                            const BoxConstraints(minWidth: 0),
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
                  const SizedBox(height: 16),
                  Text(
                    context.l10n.alreadyUsedCredits,
                    style: context.textTheme.bodySmall?.copyWith(
                      color: context.isDark
                          ? AppColors.darkTextPrimary.withValues(alpha: 0.6)
                          : AppColors.lightTextPrimary.withValues(alpha: 0.55),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _usedController,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(
                          RegExp(r'^\d+\.?\d{0,2}')),
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
                      hintText: context.l10n.enterAlreadyUsedAmount,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 18,
                      ),
                    ),
                    validator: (v) {
                      if (v != null && v.trim().isNotEmpty) {
                        final parsed = double.tryParse(v.trim());
                        if (parsed == null || parsed < 0) {
                          return context.l10n.enterValidAmount;
                        }
                      }
                      return null;
                    },
                  ),

                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: context.isDark
                          ? AppColors.darkError.withValues(alpha: 0.1)
                          : AppColors.lightError.withValues(alpha: 0.1),
                      border: Border.all(
                          color: (context.isDark
                                  ? AppColors.darkError
                                  : AppColors.lightError)
                              .withValues(alpha: 0.5)),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.info_outline,
                            color: context.isDark
                                ? AppColors.darkError
                                : AppColors.lightError,
                            size: 20),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            context.l10n.budgetCalculationWarning,
                            style: context.textTheme.bodySmall?.copyWith(
                              color: context.isDark
                                  ? AppColors.darkTextPrimary
                                      .withValues(alpha: 0.8)
                                  : AppColors.lightTextPrimary
                                      .withValues(alpha: 0.9),
                              height: 1.4,
                            ),
                          ),
                        ),
                      ],
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
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2),
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
                                onPressed: isSaving ? null : _confirmDelete,
                                style: TextButton.styleFrom(
                                  foregroundColor: AppColors.lightError,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                ),
                                child: Text(
                                  context.l10n.removeBudget,
                                  style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600),
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
          ),
        ));
  }
}
