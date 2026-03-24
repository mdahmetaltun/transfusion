import 'dart:io';

import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../core/theme.dart';
import '../models/user_model.dart';
import '../providers/theme_provider.dart';
import '../services/auth_service.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _isUploading = false;
  bool _isEditMode = false;
  bool _isSavingProfile = false;

  final _editFormKey = GlobalKey<FormState>();
  String _editedName = '';
  String _editedFacility = '';
  UserRole _selectedRole = UserRole.NURSE;
  String? _loadedProfileUid;

  void _syncEditFields(UserModel? userProfile) {
    if (userProfile == null) return;

    final shouldRefresh =
        _loadedProfileUid != userProfile.uid ||
        (!_isEditMode &&
            (_editedName != userProfile.displayName ||
                _editedFacility != userProfile.facilityId ||
                _selectedRole != userProfile.role));

    if (!shouldRefresh) return;

    _loadedProfileUid = userProfile.uid;
    _editedName = userProfile.displayName;
    _editedFacility = userProfile.facilityId;
    _selectedRole = userProfile.role;
  }

  void _startEdit(UserModel userProfile) {
    setState(() {
      _isEditMode = true;
      _editedName = userProfile.displayName;
      _editedFacility = userProfile.facilityId;
      _selectedRole = userProfile.role;
    });
  }

  void _cancelEdit(UserModel userProfile) {
    setState(() {
      _isEditMode = false;
      _isSavingProfile = false;
      _editedName = userProfile.displayName;
      _editedFacility = userProfile.facilityId;
      _selectedRole = userProfile.role;
    });
  }

  Future<void> _saveProfile(
    AuthService authService,
    UserModel userProfile,
  ) async {
    if (!_editFormKey.currentState!.validate()) return;

    setState(() {
      _isSavingProfile = true;
    });

    try {
      await authService.updateUserProfile(
        displayName: _editedName,
        role: _selectedRole,
        facilityId: _editedFacility,
      );

      if (!mounted) return;
      setState(() {
        _isEditMode = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profil başarıyla güncellendi.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Profil güncellenemedi: $e'),
          backgroundColor: AppTheme.alertRed,
        ),
      );
      _cancelEdit(userProfile);
    } finally {
      if (mounted) {
        setState(() {
          _isSavingProfile = false;
        });
      }
    }
  }

  Future<void> _pickAndUploadImage(AuthService authService) async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 512,
      maxHeight: 512,
      imageQuality: 75,
    );

    if (pickedFile == null) return;

    setState(() {
      _isUploading = true;
    });

    try {
      final user = authService.currentUserProfile;
      if (user == null) return;

      final storageRef = FirebaseStorage.instance
          .ref()
          .child('user_photos')
          .child('${user.uid}.jpg');

      await storageRef.putFile(File(pickedFile.path));
      final downloadUrl = await storageRef.getDownloadURL();
      await authService.updateUserProfilePhoto(downloadUrl);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profil fotoğrafı güncellendi.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Fotoğraf yüklenemedi: $e'),
            backgroundColor: AppTheme.alertRed,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isUploading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context);
    final themeProvider = Provider.of<ThemeProvider>(context);
    final userProfile = authService.currentUserProfile;
    final firebaseUser = authService.currentFirebaseUser;

    _syncEditFields(userProfile);

    final displayPhotoUrl = userProfile?.photoUrl ?? firebaseUser?.photoURL;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profilim'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: Icon(
              themeProvider.isDarkMode ? Icons.light_mode : Icons.dark_mode,
            ),
            onPressed: themeProvider.toggleTheme,
            tooltip: 'Temayı Değiştir',
          ),
        ],
      ),
      body: SafeArea(
        child: Form(
          key: _editFormKey,
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              _buildProfileHeaderCard(
                displayName: userProfile?.displayName ?? 'Kullanıcı',
                email:
                    userProfile?.email ?? firebaseUser?.email ?? 'Bilinmiyor',
                role: userProfile?.role,
                photoUrl: displayPhotoUrl,
                onPhotoTap: _isUploading
                    ? null
                    : () => _pickAndUploadImage(authService),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Hesap Bilgileri',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  if (userProfile != null && !_isEditMode)
                    OutlinedButton.icon(
                      onPressed: () => _startEdit(userProfile),
                      icon: const Icon(Icons.edit_outlined),
                      label: const Text('Düzenle'),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              if (userProfile != null && _isEditMode)
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _isSavingProfile
                            ? null
                            : () => _cancelEdit(userProfile),
                        child: const Text('İptal'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _isSavingProfile
                            ? null
                            : () => _saveProfile(authService, userProfile),
                        icon: _isSavingProfile
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.save_outlined),
                        label: const Text('Kaydet'),
                      ),
                    ),
                  ],
                ),
              if (userProfile != null && _isEditMode)
                const SizedBox(height: 10),
              if (userProfile != null) ...[
                if (_isEditMode)
                  _buildEditableTextField(
                    fieldKey: ValueKey('name-${userProfile.uid}'),
                    initialValue: _editedName,
                    label: 'Ad Soyad',
                    icon: Icons.person_outline,
                    onChanged: (value) => _editedName = value,
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Ad soyad boş bırakılamaz';
                      }
                      return null;
                    },
                  )
                else
                  _buildInfoTile(
                    context,
                    icon: Icons.person_outline,
                    label: 'İsim',
                    value: userProfile.displayName,
                  ),
                _buildInfoTile(
                  context,
                  icon: Icons.email_outlined,
                  label: 'Email',
                  value: userProfile.email,
                ),
                if (_isEditMode)
                  _buildEditableRoleField()
                else
                  _buildInfoTile(
                    context,
                    icon: Icons.badge_outlined,
                    label: 'Rol',
                    value: _roleLabel(userProfile.role),
                  ),
                if (_isEditMode)
                  _buildEditableTextField(
                    fieldKey: ValueKey('facility-${userProfile.uid}'),
                    initialValue: _editedFacility,
                    label: 'Kurum Kodu',
                    icon: Icons.local_hospital_outlined,
                    onChanged: (value) => _editedFacility = value,
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Kurum kodu boş bırakılamaz';
                      }
                      return null;
                    },
                  )
                else
                  _buildInfoTile(
                    context,
                    icon: Icons.local_hospital_outlined,
                    label: 'Kurum Kodu',
                    value: userProfile.facilityId,
                  ),
              ] else
                _buildIncompleteProfileCard(),
              const SizedBox(height: 28),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.alertRed,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                onPressed: () async {
                  await authService.signOut();
                  if (context.mounted) {
                    Navigator.pushNamedAndRemoveUntil(
                      context,
                      '/auth',
                      (route) => false,
                    );
                  }
                },
                icon: const Icon(Icons.logout, color: Colors.white),
                label: const Text(
                  'Sistemden Çıkış Yap',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProfileHeaderCard({
    required String displayName,
    required String email,
    required UserRole? role,
    required String? photoUrl,
    required VoidCallback? onPhotoTap,
  }) {
    final subtitle = role != null ? _roleLabel(role) : 'Rol atanmamış';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFD32F2F), Color(0xFFB71C1C)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Stack(
            children: [
              CircleAvatar(
                radius: 42,
                backgroundColor: Colors.white.withValues(alpha: 0.2),
                backgroundImage: photoUrl != null
                    ? NetworkImage(photoUrl)
                    : null,
                child: photoUrl == null
                    ? const Icon(Icons.person, size: 46, color: Colors.white)
                    : null,
              ),
              if (_isUploading)
                const Positioned.fill(
                  child: Center(
                    child: SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.6,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              Positioned(
                bottom: -2,
                right: -2,
                child: InkWell(
                  onTap: onPhotoTap,
                  borderRadius: BorderRadius.circular(14),
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(
                      Icons.camera_alt,
                      size: 16,
                      color: AppTheme.primaryColor,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  displayName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 19,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  email,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white70, fontSize: 13),
                ),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    subtitle,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEditableTextField({
    required ValueKey<String> fieldKey,
    required String initialValue,
    required String label,
    required IconData icon,
    required ValueChanged<String> onChanged,
    required String? Function(String?) validator,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextFormField(
        key: fieldKey,
        initialValue: initialValue,
        decoration: InputDecoration(labelText: label, prefixIcon: Icon(icon)),
        onChanged: onChanged,
        validator: validator,
      ),
    );
  }

  Widget _buildEditableRoleField() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: DropdownButtonFormField<UserRole>(
        initialValue: _selectedRole,
        decoration: const InputDecoration(
          labelText: 'Klinik Rol',
          prefixIcon: Icon(Icons.badge_outlined),
        ),
        items: UserRole.values
            .map(
              (role) => DropdownMenuItem<UserRole>(
                value: role,
                child: Text(_roleLabel(role)),
              ),
            )
            .toList(),
        onChanged: (value) {
          if (value == null) return;
          setState(() {
            _selectedRole = value;
          });
        },
      ),
    );
  }

  Widget _buildInfoTile(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: Theme.of(context).dividerColor.withValues(alpha: 0.3),
          ),
        ),
        child: Row(
          children: [
            Icon(icon, color: AppTheme.primaryColor),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      color: Theme.of(
                        context,
                      ).textTheme.bodyMedium?.color?.withValues(alpha: 0.8),
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    value,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                      color: Theme.of(context).textTheme.bodyLarge?.color,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIncompleteProfileCard() {
    return Card(
      color: AppTheme.warningOrange.withValues(alpha: 0.12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Klinik rol profiliniz henüz tamamlanmamış.',
              style: TextStyle(
                color: AppTheme.warningOrange,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: () {
                Navigator.pushNamedAndRemoveUntil(
                  context,
                  '/auth',
                  (route) => false,
                );
              },
              icon: const Icon(Icons.assignment_ind_outlined),
              label: const Text('Profil Kurulumuna Dön'),
            ),
          ],
        ),
      ),
    );
  }

  static String _roleLabel(UserRole role) {
    switch (role) {
      case UserRole.NURSE:
        return 'Hemşire';
      case UserRole.DOCTOR:
        return 'Doktor';
      case UserRole.BLOOD_BANK:
        return 'Kan Bankası';
      case UserRole.ADMIN:
        return 'Admin';
    }
  }
}
