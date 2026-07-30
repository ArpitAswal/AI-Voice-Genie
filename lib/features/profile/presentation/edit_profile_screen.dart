import 'dart:io';
import 'package:ai_voice_genie/core/utils/loading_overlay.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/extensions/build_context_extensions.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/router/app_routes.dart';
import '../../../core/utils/status_message_utils.dart';
import '../../../core/utils/widget_utils.dart';
import '../../auth/presentation/auth_provider.dart';
import '../domain/profile_view_model.dart';
import 'widgets/profile_avatar.dart';

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
  late final TextEditingController _countryController;
  late final TextEditingController _stateController;

  DateTime? _selectedDob;
  String? _selectedGender;
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
    _countryController = TextEditingController(text: user?.country ?? '');
    _stateController = TextEditingController(text: user?.state ?? '');
    _selectedGender = user?.gender;

    _nameController.addListener(_onFormChanged);
    _emailController.addListener(_onFormChanged);
  }

  void _onFormChanged() {
    setState(() {});
  }

  @override
  void dispose() {
    _nameController.removeListener(_onFormChanged);
    _emailController.removeListener(_onFormChanged);
    _nameController.dispose();
    _emailController.dispose();
    _dobController.dispose();
    _ageController.dispose();
    _countryController.dispose();
    _stateController.dispose();
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
        // Automatically estimate age if empty
        final now = DateTime.now();
        int age = now.year - picked.year;
        if (now.month < picked.month ||
            (now.month == picked.month && now.day < picked.day)) {
          age--;
        }
        if (age >= 0 && _ageController.text.isEmpty) {
          _ageController.text = age.toString();
        }
      });
    }
  }

  Future<void> _saveProfile(ProfileViewModel viewModel) async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    LoadingOverlay.show(context, message: context.l10n.profileUpdating);

    final success = await viewModel.updateProfile(
      authProvider: context.read<AuthProvider>(),
      displayName: _nameController.text,
      photoUrl: context.read<AuthProvider>().currentUser?.photoUrl ?? "",
      dateOfBirth: _selectedDob,
      age: int.tryParse(_ageController.text),
      gender: _selectedGender,
      country: _countryController.text.trim().isEmpty
          ? null
          : _countryController.text.trim(),
      state: _stateController.text.trim().isEmpty
          ? null
          : _stateController.text.trim(),
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

  Widget _buildFieldLabel(String text, {bool isRequired = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, left: 4),
      child: Row(
        children: [
          Text(
            text,
            style: context.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w600,
              color: context.textTheme.bodyLarge?.color,
            ),
          ),
          if (isRequired)
            Text(
              ' *',
              style: context.textTheme.titleSmall?.copyWith(
                color: context.isDark ? AppColors.darkError : AppColors.lightError,
                fontWeight: FontWeight.bold,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildGenderSelector() {
    final options = [
      ('Male', context.l10n.genderMale, Icons.male_rounded),
      ('Female', context.l10n.genderFemale, Icons.female_rounded),
      ('Other', context.l10n.genderOther, Icons.transgender_rounded),
      (
        'Prefer not to say',
        context.l10n.genderPreferNotToSay,
        Icons.visibility_off_outlined
      ),
    ];

    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: options.map((opt) {
        final value = opt.$1;
        final label = opt.$2;
        final icon = opt.$3;
        final isSelected = _selectedGender == value;
        final theme = Theme.of(context);
        final primaryColor = theme.colorScheme.primary;

        return InkWell(
          onTap: () {
            setState(() {
              _selectedGender = isSelected ? null : value;
            });
          },
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: isSelected
                  ? primaryColor
                  : (context.isDark ? AppColors.cardDark : AppColors.cardLight),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected
                    ? Colors.white
                    : (context.isDark
                        ? AppColors.darkDivider
                        : AppColors.lightDivider),
                width: isSelected ? 1.5 : 1.0,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  icon,
                  size: theme.textTheme.titleLarge?.fontSize,
                  color: isSelected
                      ? Colors.white
                      : theme.textTheme.bodyMedium?.color,
                ),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight:
                        isSelected ? FontWeight.w600 : FontWeight.normal,
                    color: isSelected
                        ? Colors.white
                        : theme.textTheme.bodyLarge?.color,
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => ProfileViewModel(),
      child: Consumer<ProfileViewModel>(
        builder: (context, viewModel, _) {
          final isFormValid = _nameController.text.trim().isNotEmpty &&
              _emailController.text.trim().isNotEmpty;

          return Scaffold(
            appBar: AppBar(title: Text(context.l10n.editProfile)),
            body: SafeArea(
              child: ListView(
                padding: EdgeInsets.all(context.horizontalPadding),
                children: [
                  Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Center(
                          child: ProfileAvatar(
                            pickedFile: _pickedImageFile,
                            onImagePicked: (file) {
                              setState(() {
                                _pickedImageFile = file;
                              });
                            },
                            canUpdate: true,
                          ),
                        ),
                        const SizedBox(height: 28),

                        // Display Name (Required)
                        _buildFieldLabel(
                          context.l10n.translate('display_name'),
                          isRequired: true,
                        ),
                        context.themedTextField(
                          controller: _nameController,
                          hint: context.l10n.translate('fake_name'),
                          prefixIcon: Icons.person_4,
                          textCapitalization: TextCapitalization.words,
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return context.l10n.fieldRequired;
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 20),

                        // Email (Required / Read only)
                        _buildFieldLabel(
                          context.l10n.translate('email_address'),
                          isRequired: true,
                        ),
                        context.themedTextField(
                          controller: _emailController,
                          hint: context.l10n.translate('fake_email'),
                          prefixIcon: Icons.email_rounded,
                        ),
                        const SizedBox(height: 20),

                        // Date of Birth & Age (Optional)
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              flex: 3,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _buildFieldLabel(context.l10n.dateOfBirthLabel),
                                  GestureDetector(
                                    onTap: () => _selectDate(context),
                                    child: AbsorbPointer(
                                      child: context.themedTextField(
                                        controller: _dobController,
                                        hint: 'DD/MM/YYYY',
                                        prefixIcon:
                                            Icons.calendar_today_rounded,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              flex: 2,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _buildFieldLabel(context.l10n.ageLabel),
                                  context.themedTextField(
                                    controller: _ageController,
                                    hint: '0',
                                    prefixIcon: Icons.cake_rounded,
                                    keyboardType: TextInputType.number,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),

                        // Gender (Optional)
                        _buildFieldLabel(context.l10n.genderLabel),
                        _buildGenderSelector(),
                        const SizedBox(height: 20),

                        // Country & State (Optional)
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _buildFieldLabel(context.l10n.countryLabel),
                                  context.themedTextField(
                                    controller: _countryController,
                                    hint: context.l10n.countryLabel,
                                    prefixIcon: Icons.public_rounded,
                                    textCapitalization:
                                        TextCapitalization.words,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _buildFieldLabel(context.l10n.stateLabel),
                                  context.themedTextField(
                                    controller: _stateController,
                                    hint: context.l10n.stateLabel,
                                    prefixIcon: Icons.map_rounded,
                                    textCapitalization:
                                        TextCapitalization.words,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 32),

                        Center(
                          child: context.themedElevatedButton(
                            label: context.l10n.update.toUpperCase(),
                            onPressed: (viewModel.isSavingProfile || !isFormValid)
                                ? null
                                : () => _saveProfile(viewModel),
                          ),
                        ),
                        const SizedBox(height: 20),
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
