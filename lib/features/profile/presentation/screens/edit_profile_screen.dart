import 'dart:io';
import 'package:ai_voice_genie/core/utils/loading_overlay.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

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
  late final TextEditingController _emailController;
  late final TextEditingController _dobController;
  late final TextEditingController _ageController;

  DateTime? _selectedDob;
  // String _selectedModel = 'gemini';
  File? _pickedImageFile;

  @override
  void initState() {
    super.initState();
    final user = context.read<AuthProvider>().currentUser;
    _nameController = TextEditingController(text: user?.displayName ?? '');
    _emailController = TextEditingController(text: user?.email ?? '');
    _selectedDob = user?.dateOfBirth;
    _dobController = TextEditingController(
      text: _selectedDob != null
          ? DateFormat('dd/MM/yyyy').format(_selectedDob!)
          : '',
    );
    _ageController = TextEditingController(
      text: user?.age?.toString() ?? '',
    );
    // _selectedModel = user?.preferredAiModel ?? 'gemini';
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _dobController.dispose();
    _ageController.dispose();
    super.dispose();
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDob ??
          DateTime.now().subtract(const Duration(days: 365 * 20)),
      firstDate: DateTime(1900),
      lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
    );
    if (picked != null && picked != _selectedDob) {
      setState(() {
        _selectedDob = picked;
        _dobController.text = DateFormat('dd/MM/yyyy').format(picked);
      });
    }
  }

  Future<void> _saveProfile(ProfileViewModel viewModel) async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    LoadingOverlay.show(context, message: context.l10n.profileUpdating);

    final success = await viewModel.updateProfile(
      authProvider: context.read<AuthProvider>(),
      displayName: _nameController.text,
      photoUrl:
          "", // This will be updated by repository if photoFile is present
      dateOfBirth: _selectedDob,
      age: int.tryParse(_ageController.text),
      photoFile: _pickedImageFile,
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
                        ProfileAvatar(
                          pickedFile: _pickedImageFile,
                          onImagePicked: (file) {
                            setState(() {
                              _pickedImageFile = file;
                            });
                          },
                          canUpdate: true,
                        ),
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
                        const SizedBox(height: 20),
                        context.themedTextField(
                            controller: _emailController,
                            label: context.l10n.translate('email'),
                            prefixIcon: Icons.email_outlined,
                            read: true),
                        const SizedBox(height: 20),
                        Row(
                          children: [
                            Expanded(
                              flex: 2,
                              child: GestureDetector(
                                onTap: () => _selectDate(context),
                                child: AbsorbPointer(
                                  child: context.themedTextField(
                                    controller: _dobController,
                                    label: context.l10n.dateOfBirthLabel,
                                    prefixIcon: Icons.calendar_today_outlined,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: context.themedTextField(
                                controller: _ageController,
                                label: context.l10n.ageLabel,
                                keyboardType: TextInputType.number,
                              ),
                            ),
                          ],
                        ),
                        // const SizedBox(height: 20),
                        // DropdownButtonFormField<String>(
                        //   initialValue: _selectedModel,
                        //   style: context.textTheme.bodyLarge,
                        //   decoration: InputDecoration(
                        //     labelText: context.l10n.preferModelLabel,
                        //     labelStyle: context.textTheme.titleSmall,
                        //     prefixIcon: Icon(
                        //       Icons.psychology_outlined,
                        //       color: context.theme.colorScheme.primary
                        //           .withValues(alpha: 0.7),
                        //     ),
                        //     filled: true,
                        //     fillColor: context.isDark
                        //         ? AppColors.cardDark
                        //         : AppColors.cardLight,
                        //     border: OutlineInputBorder(
                        //       borderRadius: BorderRadius.circular(14),
                        //       borderSide: BorderSide(
                        //         color: context.isDark
                        //             ? AppColors.darkDivider
                        //             : AppColors.lightDivider,
                        //       ),
                        //     ),
                        //     enabledBorder: OutlineInputBorder(
                        //       borderRadius: BorderRadius.circular(14),
                        //       borderSide: BorderSide(
                        //         color: context.isDark
                        //             ? AppColors.darkDivider
                        //             : AppColors.lightDivider,
                        //       ),
                        //     ),
                        //     focusedBorder: OutlineInputBorder(
                        //       borderRadius: BorderRadius.circular(14),
                        //       borderSide: BorderSide(
                        //           color: context.theme.colorScheme.primary),
                        //     ),
                        //     errorBorder: OutlineInputBorder(
                        //       borderRadius: BorderRadius.circular(14),
                        //       borderSide:
                        //           const BorderSide(color: AppColors.error),
                        //     ),
                        //     focusedErrorBorder: OutlineInputBorder(
                        //       borderRadius: BorderRadius.circular(14),
                        //       borderSide:
                        //           const BorderSide(color: AppColors.error),
                        //     ),
                        //     contentPadding: const EdgeInsets.symmetric(
                        //       horizontal: 16,
                        //     ),
                        //   ),
                        //   items: [
                        //     DropdownMenuItem(
                        //       value: 'openai',
                        //       child: Text(
                        //         'ChatGPT',
                        //         style: context.textTheme.bodyLarge,
                        //       ),
                        //     ),
                        //     DropdownMenuItem(
                        //       value: 'gemini',
                        //       child: Text(
                        //         'Gemini',
                        //         style: context.textTheme.bodyLarge,
                        //       ),
                        //     ),
                        //     DropdownMenuItem(
                        //       value: 'claude',
                        //       child: Text(
                        //         'Claude',
                        //         style: context.textTheme.bodyLarge,
                        //       ),
                        //     ),
                        //   ],
                        //   onChanged: (value) {
                        //     if (value != null) {
                        //       setState(() {
                        //         _selectedModel = value;
                        //       });
                        //     }
                        //   },
                        // ),
                        const SizedBox(height: 32),
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
