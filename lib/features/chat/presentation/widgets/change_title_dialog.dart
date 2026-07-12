import 'package:ai_voice_genie/core/utils/widget_utils.dart';
import 'package:flutter/material.dart';

import '../../../../core/extensions/build_context_extensions.dart';
import '../../../../core/localization/app_localizations.dart';

class ChangeTitleDialog extends StatefulWidget {
  final String initialTitle;

  const ChangeTitleDialog({
    super.key,
    required this.initialTitle,
  });

  @override
  State<ChangeTitleDialog> createState() => _ChangeTitleDialogState();
}

class _ChangeTitleDialogState extends State<ChangeTitleDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialTitle);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = context.theme;

    return AlertDialog(
      title: Text(
        l10n.translate('rename_conversation_name'),
        style: theme.textTheme.titleLarge,
      ),
      insetPadding: const EdgeInsets.all(20),
      contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 24),
      content: SizedBox(
        width: double.maxFinite,
        child: TextField(
          controller: _controller,
          autofocus: true,
          textCapitalization: TextCapitalization.sentences,
          decoration: InputDecoration(
            hintText: l10n.translate('rename_conversation_name'),
            enabledBorder: OutlineInputBorder(
              borderSide: BorderSide(color: theme.primaryColor),
              borderRadius: BorderRadius.circular(14)
            ),
            focusedBorder: OutlineInputBorder(
              borderSide: BorderSide(color: theme.primaryColor),
                borderRadius: BorderRadius.circular(14)
            ),
          ),
        ),
      ),
      actions: [
        Row(
        children: [
        Expanded(
          child: context.themedOutlinedButton(
            onPressed: () => Navigator.of(context).pop(),
            label:
              l10n.translate('cancel'),
          ),
        ),
          const SizedBox(width: 16),
        Expanded(
          child: context.themedOutlinedButton(
            onPressed: () {
              final newTitle = _controller.text.trim();
              if (newTitle.isNotEmpty && newTitle != widget.initialTitle) {
                Navigator.of(context).pop(newTitle);
              } else {
                Navigator.of(context).pop();
              }
            }, label: l10n.translate('rename'),
          ),
        )])
      ],
    );
  }
}
