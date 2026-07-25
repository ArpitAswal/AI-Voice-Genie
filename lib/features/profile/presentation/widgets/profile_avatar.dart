import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/extensions/build_context_extensions.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/widgets/app_alert_dialog.dart';
import '../../../auth/presentation/auth_provider.dart';

class ProfileAvatar extends StatefulWidget {
  final File? pickedFile;
  final Function(File)? onImagePicked;
  final String? displayName;
  final String? photoUrl;
  final double? size;
  final bool? canUpdate;

  const ProfileAvatar(
      {super.key,
      this.pickedFile,
      this.onImagePicked,
      this.displayName,
      this.photoUrl,
      this.size,
      this.canUpdate});

  @override
  State<ProfileAvatar> createState() => _ProfileAvatarState();
}

class _ProfileAvatarState extends State<ProfileAvatar> {
  final ImagePicker _picker = ImagePicker();

  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? image = await _picker.pickImage(
        source: source,
        imageQuality: 70,
        maxWidth: 512,
        maxHeight: 512,
      );
      if (image != null) {
        debugPrint('📸 Image picked: ${image.path}');
        widget.onImagePicked?.call(File(image.path));
      } else {
        debugPrint('📸 Image picking cancelled or failed.');
      }
    } catch (e) {
      debugPrint('📸 Image picking error: $e');
      if (mounted) {
        _showPermissionDeniedDialog(source);
      }
    }
  }

  void _showPermissionDeniedDialog(ImageSource source) {
    final isCamera = source == ImageSource.camera;
    showDialog(
      context: context,
      builder: (context) => AppAlertDialog(
        title: Text(context.l10n.permissionDenied),
        content: Text(isCamera
            ? context.l10n.cameraDeniedMessage
            : context.l10n.galleryDeniedMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(context.l10n.cancel),
          ),
          TextButton(
            onPressed: () {
              // Note: Using image_picker doesn't provide a direct "Open Settings"
              // but we can suggest it or use another package if strict requirement.
              // For now, following plan's instruction.
              Navigator.pop(context);
            },
            child: Text(context.l10n.ok),
          ),
        ],
      ),
    );
  }

  void _showPickerOptions() {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: Text(context.l10n.camera),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: Text(context.l10n.gallery),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.gallery);
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().currentUser;
    final displayName =
        widget.displayName ?? user?.displayName ?? context.l10n.user;
    final photoUrl = widget.photoUrl ?? user?.photoUrl ?? '';
    final size = widget.size ?? (context.isTablet ? 140.0 : 116.0);

    return Center(
      child: Stack(
        children: [
          Container(
            width: size,
            height: size,
            padding: const EdgeInsets.all(5),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [
                  context.isDark
                      ? AppColors.primaryLight
                      : AppColors.primaryDark,
                  AppColors.tealAccent,
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [
                BoxShadow(
                  color: context.primaryColor.withValues(alpha: 0.28),
                  blurRadius: 28,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: CircleAvatar(
              backgroundColor:
                  context.isDark ? AppColors.cardDark : AppColors.cardLight,
              child: ClipOval(
                child: widget.pickedFile != null
                    ? Image.file(
                        widget.pickedFile!,
                        width: size,
                        height: size,
                        fit: BoxFit.cover,
                      )
                    : _buildAvatarImage(photoUrl, displayName, size),
              ),
            ),
          ),
          if (widget.canUpdate == true)
            Positioned(
              bottom: 0,
              right: 0,
              child: GestureDetector(
                onTap: _showPickerOptions,
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: context.isDark
                        ? context.theme.colorScheme.onPrimary
                        : context.theme.colorScheme.primary,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: context.isDark
                          ? context.theme.colorScheme.primary
                          : context.theme.colorScheme.onPrimary,
                      width: 3,
                    ),
                  ),
                  child: Icon(
                    Icons.camera_alt,
                    color: context.isDark
                        ? context.theme.colorScheme.primary
                        : context.theme.colorScheme.onPrimary,
                    size: 20,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildAvatarImage(String photoUrl, String displayName, double size) {
    if (photoUrl.isEmpty) {
      return _InitialsAvatar(displayName: displayName);
    }

    // Handle Base64 Data URI
    if (photoUrl.startsWith('data:image')) {
      try {
        final base64Content = photoUrl.split(',').last;
        final bytes = base64Decode(base64Content);
        return Image.memory(
          bytes,
          width: size,
          height: size,
          fit: BoxFit.cover,
        );
      } catch (e) {
        return _InitialsAvatar(displayName: displayName);
      }
    }

    // Handle Local File Path
    if (!photoUrl.startsWith('http')) {
      final file = File(photoUrl);
      if (file.existsSync()) {
        return Image.file(
          file,
          width: size,
          height: size,
          fit: BoxFit.cover,
        );
      }
    }

    // Handle Network URL
    return Image.network(
      photoUrl,
      width: size,
      height: size,
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => _InitialsAvatar(displayName: displayName),
    );
  }
}

class _InitialsAvatar extends StatelessWidget {
  final String displayName;

  const _InitialsAvatar({required this.displayName});

  @override
  Widget build(BuildContext context) {
    return Container(
      alignment: Alignment.center,
      decoration: BoxDecoration(
        gradient: context.isDark
            ? AppColors.darkVoiceGradient
            : AppColors.lightVoiceGradient,
      ),
      child: Text(
        _initials(displayName),
        style: context.textTheme.displayMedium?.copyWith(
          color: AppColors.white,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return 'U';
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
  }
}
