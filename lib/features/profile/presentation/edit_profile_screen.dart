import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/extensions/build_context_extensions.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/router/app_routes.dart';
import '../../../core/utils/app_validators.dart';
import '../../../core/utils/loading_overlay.dart';
import '../../../core/utils/status_message_utils.dart';
import '../../../core/utils/widget_utils.dart';
import '../../auth/presentation/auth_provider.dart';
import 'profile_view_model.dart';
import 'widgets/profile_avatar.dart';

/// Screen allowing users to update their profile information and avatar.
/// Uses a unified, centered, single-column adaptive layout across phone and tablet
/// to keep the editing experience focused, consistent, and uncluttered.
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
    // Pre-populate fields from the current authenticated user session
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
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _dobController.dispose();
    _ageController.dispose();
    _countryController.dispose();
    _stateController.dispose();
    super.dispose();
  }

  /// Opens the native Material date picker and auto-calculates approximate age.
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

        // Auto-fill age field if empty
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

  /// Validates the form and dispatches profile updates via [ProfileViewModel].
  Future<void> _saveProfile(ProfileViewModel viewModel) async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    LoadingOverlay.show(context, message: context.l10n.profileUpdating);

    final success = await viewModel.updateProfile(
      authProvider: context.read<AuthProvider>(),
      displayName: _nameController.text.trim(),
      photoUrl: context.read<AuthProvider>().currentUser?.photoUrl ?? '',
      email: _emailController.text.trim(),
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
      final errorKey = viewModel.errorMessage ??
          context.read<AuthProvider>().authError ??
          'profile_update_failed';
      context.showError(context.l10n.translate(errorKey));
      viewModel.clearErrorMessage();
      context.read<AuthProvider>().clearAuthError();
    }
  }

  // ── BUILD ENTRYPOINT ────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => ProfileViewModel(),
      child: Consumer<ProfileViewModel>(
        builder: (context, viewModel, _) {
          return Scaffold(
            appBar: AppBar(title: Text(context.l10n.editProfile)),
            body: SafeArea(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final width = constraints.maxWidth;
                  final height = constraints.maxHeight;

                  // ── Adaptive Responsive Measurements ────────────────────────
                  // Height constraint <= 550 protects landscape phones from vertical crushing.
                  final bool isShortHeight = height <= 550.0;
                  final bool isWide = width >= 600.0;

                  // Proportional avatar sizing matching device context
                  final double avatarSize =
                      isShortHeight ? 64.0 : (isWide ? 100.0 : 80.0);
                  // Top padding: slightly more generous on tablet portrait for visual balance
                  final double verticalPadding = isShortHeight
                      ? 12.0
                      : (isWide ? 28.0 : context.verticalSpacing);
                  final double avatarSpacing =
                      isShortHeight ? 14.0 : (isWide ? 30.0 : 22.0);
                  final double buttonSpacing =
                      isShortHeight ? 20.0 : (isWide ? 36.0 : 28.0);

                  // Keyboard-aware bottom padding:
                  // Automatically expands when native on-screen keyboard appears
                  final double bottomPadding =
                      context.viewInsets.bottom + (isWide ? 48.0 : 36.0);

                  // Aligns the form to the top-center of the screen.
                  // Alignment.topCenter prevents vertical dead space on tall tablet portrait screens
                  // while keeping the form horizontally centered within readable bounds.
                  return Align(
                    alignment: Alignment.topCenter,
                    child: ConstrainedBox(
                      // Enforces a maximum readable form width on tablet landscape and desktop
                      // to prevent text fields from unnaturally stretching edge-to-edge.
                      constraints: const BoxConstraints(maxWidth: 580.0),
                      child: SingleChildScrollView(
                        physics: const ClampingScrollPhysics(),
                        padding: EdgeInsets.only(
                          left: context.horizontalPadding,
                          right: context.horizontalPadding,
                          top: verticalPadding,
                          bottom: bottomPadding,
                        ),
                        child: Form(
                          key: _formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Centered Avatar with docked camera badge
                              _buildAvatar(avatarSize),
                              SizedBox(height: avatarSpacing),

                              // Form input fields (with adaptive spacing for tablet vs mobile)
                              ..._buildFormFields(context, isWide: isWide),
                              SizedBox(height: buttonSpacing),

                              // Primary submission button
                              _buildUpdateButton(context, viewModel),
                              const SizedBox(height: 16.0),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          );
        },
      ),
    );
  }

  // ── REUSABLE COMPONENT BUILDERS ─────────────────────────────────────────────

  /// Renders the profile avatar with camera action badge.
  Widget _buildAvatar(double size) {
    return Center(
      child: ProfileAvatar(
        pickedFile: _pickedImageFile,
        onImagePicked: (file) {
          setState(() {
            _pickedImageFile = file;
          });
        },
        size: size,
        canUpdate: true,
      ),
    );
  }

  /// Builds the collection of form inputs with responsive row arrangement.
  List<Widget> _buildFormFields(
    BuildContext context, {
    required bool isWide,
  }) {
    // ── Responsive Spacing Tokens ─────────────────────────────────────────────
    // Tablet (isWide): 24dp vertical spacing between field groups gives open,
    // uncluttered breathing room without feeling sparse.
    // Mobile (!isWide): 16dp compact spacing preserves precious screen estate.
    final double fieldSpacing = isWide ? 24.0 : 16.0;
    final double horizontalSpacing = isWide ? 18.0 : 14.0;
    final double labelSpacing = isWide ? 8.0 : 6.0;

    return [
      // Display Name (Required)
      _FormFieldWrapper(
        label: context.l10n.displayName,
        isRequired: true,
        labelSpacing: labelSpacing,
        child: context.themedTextField(
          controller: _nameController,
          hint: context.l10n.fakeName,
          prefixIcon: Icons.person_outline_rounded,
          textCapitalization: TextCapitalization.words,
          validator: (value) =>
              Validators.validateRequired(value, context: context),
        ),
      ),
      SizedBox(height: fieldSpacing),

      // Email Address (Required)
      _FormFieldWrapper(
        label: context.l10n.emailAddress,
        isRequired: true,
        labelSpacing: labelSpacing,
        child: context.themedTextField(
          controller: _emailController,
          hint: context.l10n.fakeEmail,
          prefixIcon: Icons.mail_outline_rounded,
          keyboardType: TextInputType.emailAddress,
          validator: (value) =>
              Validators.validateEmail(value, context: context),
        ),
      ),
      SizedBox(height: fieldSpacing),

      // Date of Birth & Age Row
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 3,
            child: _FormFieldWrapper(
              label: context.l10n.dateOfBirthLabel,
              labelSpacing: labelSpacing,
              child: GestureDetector(
                onTap: () => _selectDate(context),
                child: AbsorbPointer(
                  child: context.themedTextField(
                    controller: _dobController,
                    hint: 'DD/MM/YYYY',
                    prefixIcon: Icons.calendar_today_rounded,
                  ),
                ),
              ),
            ),
          ),
          SizedBox(width: horizontalSpacing),
          Expanded(
            flex: 2,
            child: _FormFieldWrapper(
              label: context.l10n.ageLabel,
              labelSpacing: labelSpacing,
              child: context.themedTextField(
                controller: _ageController,
                hint: '0',
                prefixIcon: Icons.cake_outlined,
                keyboardType: TextInputType.number,
              ),
            ),
          ),
        ],
      ),
      SizedBox(height: fieldSpacing),

      // Gender Selector (Tonal segmented pills)
      _FormFieldWrapper(
        label: context.l10n.genderLabel,
        labelSpacing: labelSpacing,
        child: _buildGenderSelector(context, isWide: isWide),
      ),
      SizedBox(height: fieldSpacing),

      // Country & State (2-column row on wide screens, stacked vertically on phone portrait)
      if (isWide)
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _FormFieldWrapper(
                label: context.l10n.countryLabel,
                labelSpacing: labelSpacing,
                child: context.themedTextField(
                  controller: _countryController,
                  hint: context.l10n.countryLabel,
                  prefixIcon: Icons.public_rounded,
                  textCapitalization: TextCapitalization.words,
                ),
              ),
            ),
            SizedBox(width: horizontalSpacing),
            Expanded(
              child: _FormFieldWrapper(
                label: context.l10n.stateLabel,
                labelSpacing: labelSpacing,
                child: context.themedTextField(
                  controller: _stateController,
                  hint: context.l10n.stateLabel,
                  prefixIcon: Icons.map_outlined,
                  textCapitalization: TextCapitalization.words,
                ),
              ),
            ),
          ],
        )
      else ...[
        _FormFieldWrapper(
          label: context.l10n.countryLabel,
          labelSpacing: labelSpacing,
          child: context.themedTextField(
            controller: _countryController,
            hint: context.l10n.countryLabel,
            prefixIcon: Icons.public_rounded,
            textCapitalization: TextCapitalization.words,
          ),
        ),
        SizedBox(height: fieldSpacing),
        _FormFieldWrapper(
          label: context.l10n.stateLabel,
          labelSpacing: labelSpacing,
          child: context.themedTextField(
            controller: _stateController,
            hint: context.l10n.stateLabel,
            prefixIcon: Icons.map_outlined,
            textCapitalization: TextCapitalization.words,
          ),
        ),
      ],
    ];
  }

  /// Builds a cohesive, tonal gender selector chip row.
  /// Uses a soft primary tonal background with primary border when selected.
  Widget _buildGenderSelector(BuildContext context, {required bool isWide}) {
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

    final primaryColor = context.primaryColor;

    return Wrap(
      spacing: isWide ? 10.0 : 8.0,
      runSpacing: isWide ? 10.0 : 8.0,
      children: options.map((opt) {
        final value = opt.$1;
        final label = opt.$2;
        final icon = opt.$3;
        final isSelected = _selectedGender == value;

        return InkWell(
          onTap: () {
            setState(() {
              _selectedGender = isSelected ? null : value;
            });
          },
          borderRadius: BorderRadius.circular(12),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: EdgeInsets.symmetric(
              horizontal: isWide ? 16.0 : 14.0,
              vertical: isWide ? 11.0 : 10.0,
            ),
            decoration: BoxDecoration(
              // Selected: soft tonal tint matching project selection standard
              // Unselected: standard card surface
              color: isSelected
                  ? primaryColor.withValues(alpha: context.isDark ? 0.25 : 0.12)
                  : (context.isDark ? AppColors.cardDark : AppColors.cardLight),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected
                    ? primaryColor
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
                  size: 18.0,
                  color: isSelected
                      ? primaryColor
                      : context.textTheme.bodyMedium?.color
                          ?.withValues(alpha: 0.7),
                ),
                const SizedBox(width: 6.0),
                Text(
                  label,
                  style: context.textTheme.bodyMedium?.copyWith(
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                    color: isSelected
                        ? primaryColor
                        : context.textTheme.bodyMedium?.color,
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  /// Builds the update submission button.
  /// Observes controller text values efficiently via [AnimatedBuilder] to avoid full-screen rebuilds.
  Widget _buildUpdateButton(
    BuildContext context,
    ProfileViewModel viewModel,
  ) {
    return AnimatedBuilder(
      animation: Listenable.merge([_nameController, _emailController]),
      builder: (context, _) {
        final isFormValid = _nameController.text.trim().isNotEmpty &&
            _emailController.text.trim().isNotEmpty;

        return Center(
          child: context.themedElevatedButton(
            label: context.l10n.update.toUpperCase(),
            textStyle: context.isCompact
                ? context.textTheme.titleMedium
                : context.textTheme.titleLarge,
            foreground: Colors.white,
            onPressed: (viewModel.isSavingProfile || !isFormValid)
                ? null
                : () => _saveProfile(viewModel),
          ),
        );
      },
    );
  }
}

/// Reusable field wrapper pairing an input label and an optional required indicator
/// with the child form field, reducing repetitive layout boilerplate.
class _FormFieldWrapper extends StatelessWidget {
  final String label;
  final bool isRequired;
  final Widget child;
  final double labelSpacing;

  const _FormFieldWrapper({
    required this.label,
    this.isRequired = false,
    required this.child,
    this.labelSpacing = 6.0,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: EdgeInsets.only(bottom: labelSpacing, left: 2.0),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: context.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: context.textTheme.bodyLarge?.color,
                ),
              ),
              if (isRequired)
                Text(
                  ' *',
                  style: context.textTheme.titleSmall?.copyWith(
                    color: context.isDark
                        ? AppColors.darkError
                        : AppColors.lightError,
                    fontWeight: FontWeight.bold,
                  ),
                ),
            ],
          ),
        ),
        child,
      ],
    );
  }
}
