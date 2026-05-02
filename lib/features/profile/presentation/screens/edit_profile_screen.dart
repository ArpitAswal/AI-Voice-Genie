import 'package:ai_voice_genie/core/utils/loading_overlay.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/extensions/build_context_extensions.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/router/app_routes.dart';
import '../../../../core/utils/status_message_utils.dart';
import '../../../../core/utils/widget_utils.dart';
import '../../../auth/presentation/auth_provider.dart';
import '../../domain/profile_view_model.dart';
import '../widgets/profile_avatar.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;

  @override
  void initState() {
    super.initState();
    final user = context.read<AuthProvider>().currentUser;
    _nameController = TextEditingController(text: user?.displayName ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _saveProfile(ProfileViewModel viewModel) async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    LoadingOverlay.show(context, message: context.l10n.profileUpdating);
    final success = await viewModel.updateProfile(
      authProvider: context.read<AuthProvider>(),
      displayName: _nameController.text,
      photoUrl: "",
    );

    LoadingOverlay.hide();
    if (!mounted) return;

    if (success) {
      MessageUtils.showSuccess(context, context.l10n.profileUpdated);
      AppRoutes.pop(context);
    } else {
      context.showError(context.l10n.profileUpdateFailed);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => ProfileViewModel(),
      child: Consumer<ProfileViewModel>(
        builder: (context, viewModel, _) {
          return Scaffold(
            appBar: AppBar(title: Text(context.l10n.editProfile)),
            body: SafeArea(
              child: ListView(
                padding: EdgeInsets.all(context.horizontalPadding),
                children: [
                  Form(
                    key: _formKey,
                    child: Column(
                      children: [
                        const EditableAvatarPreview(),
                        const SizedBox(height: 28),
                        context.themedTextField(
                          controller: _nameController,
                          label: context.l10n.translate('display_name'),
                          prefixIcon: Icons.person_outline_rounded,
                          textCapitalization: TextCapitalization.words,
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return context.l10n.fieldRequired;
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 28),
                        context.themedElevatedButton(
                          label: context.l10n.save.toUpperCase(),
                          onPressed: viewModel.isSavingProfile
                              ? null
                              : () => _saveProfile(viewModel),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
