import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/user_model.dart';
import '../services/auth_service.dart';
import '../core/theme.dart';

class ProfileSetupScreen extends StatefulWidget {
  const ProfileSetupScreen({super.key});

  @override
  State<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends State<ProfileSetupScreen> {
  UserRole _selectedRole = UserRole.NURSE;
  final TextEditingController _facilityController = TextEditingController(
    text: "HOSP-01",
  );
  bool _isLoading = false;

  @override
  void dispose() {
    _facilityController.dispose();
    super.dispose();
  }

  Future<void> _saveProfile() async {
    setState(() => _isLoading = true);
    final authService = Provider.of<AuthService>(context, listen: false);
    final firebaseUser = authService.currentFirebaseUser;

    if (firebaseUser != null) {
      final newUser = UserModel(
        uid: firebaseUser.uid,
        displayName: firebaseUser.displayName ?? 'İsimsiz Kullanıcı',
        email: firebaseUser.email ?? 'Mail Yok',
        role: _selectedRole,
        facilityId: _facilityController.text.trim(),
      );

      try {
        await authService.createUserProfile(newUser);
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Profil oluşturulamadı. Yetki hatası olabilir: $e'),
              backgroundColor: AppTheme.alertRed,
            ),
          );
        }
      }
    }
    if (mounted) setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Profil Kurulumu"),
        automaticallyImplyLeading: false,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              "Sisteme ilk kez giriş yaptınız. Kayıtları sağlıklı tutabilmek için lütfen rolünüzü ve kurumunuzu belirleyin.",
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 24),
            DropdownButtonFormField<UserRole>(
              value: _selectedRole,
              decoration: const InputDecoration(
                labelText: "Klinik Göreviniz (Rol)",
                border: OutlineInputBorder(),
              ),
              items: UserRole.values.map((role) {
                return DropdownMenuItem(
                  value: role,
                  child: Text(role.toString().split('.').last),
                );
              }).toList(),
              onChanged: (val) {
                setState(() => _selectedRole = val!);
              },
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _facilityController,
              decoration: const InputDecoration(
                labelText: "Kurum/Hastane Kodu",
                border: OutlineInputBorder(),
              ),
            ),
            const Spacer(),
            if (_isLoading)
              const Center(child: CircularProgressIndicator())
            else
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                onPressed: _saveProfile,
                child: const Text("PROFİLİ KAYDET VE BAŞLA"),
              ),
          ],
        ),
      ),
    );
  }
}
