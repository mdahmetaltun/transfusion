import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/auth_service.dart';
import '../models/user_model.dart';
import '../core/theme.dart';

class FacilitySelectScreen extends StatefulWidget {
  const FacilitySelectScreen({super.key});

  @override
  State<FacilitySelectScreen> createState() => _FacilitySelectScreenState();
}

class _FacilitySelectScreenState extends State<FacilitySelectScreen> {
  final _formKey = GlobalKey<FormState>();
  UserRole _selectedRole = UserRole.NURSE;
  String _displayName = '';
  String _facilityId = 'DFLT-001';
  bool _isLoading = false;

  void _saveProfile(AuthService authService, User user) async {
    if (!_formKey.currentState!.validate()) return;
    _formKey.currentState!.save();

    setState(() {
      _isLoading = true;
    });

    final newUser = UserModel(
      uid: user.uid,
      email: user.email ?? 'Bilinmiyor',
      displayName: _displayName,
      role: _selectedRole,
      facilityId: _facilityId,
    );

    try {
      await authService.createUserProfile(newUser);
      if (mounted) {
        Navigator.pushReplacementNamed(context, '/splash');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Profil kaydedilemedi: $e',
              style: const TextStyle(color: Colors.white),
            ),
            backgroundColor: AppTheme.alertRed,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context);
    final user = authService.currentFirebaseUser;

    if (user == null) {
      // Should not happen if AuthWrapper works correctly
      return const Scaffold(
        body: Center(child: Text("Hata: Kullanıcı oturumu bulunamadı.")),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Kurum ve Profil Kurulumu'),
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Sistemi kullanmaya başlamadan önce lütfen profilinizi ve çalıştığınız kurumu tanımlayın.',
                  style: TextStyle(fontSize: 16, color: Colors.white70),
                ),
                const SizedBox(height: 32),

                TextFormField(
                  decoration: const InputDecoration(
                    labelText: 'Ad Soyad',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.person),
                  ),
                  validator: (value) => value == null || value.isEmpty
                      ? 'Lütfen adınızı girin'
                      : null,
                  onSaved: (value) => _displayName = value!,
                ),
                const SizedBox(height: 16),

                DropdownButtonFormField<UserRole>(
                  value: _selectedRole,
                  decoration: const InputDecoration(
                    labelText: 'Klinik Rol',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.badge),
                  ),
                  items: UserRole.values.map((role) {
                    return DropdownMenuItem(
                      value: role,
                      child: Text(role.name),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setState(() {
                      if (value != null) _selectedRole = value;
                    });
                  },
                ),
                const SizedBox(height: 16),

                TextFormField(
                  initialValue: _facilityId,
                  decoration: const InputDecoration(
                    labelText: 'Kurum Kodu (Opsiyonel)',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.local_hospital),
                    helperText:
                        'Standart giriş için DFLT-001 kullanabilirsiniz.',
                  ),
                  onSaved: (value) => _facilityId = value?.isNotEmpty == true
                      ? value!
                      : 'DFLT-001',
                ),
                const SizedBox(height: 32),

                if (_isLoading)
                  const Center(child: CircularProgressIndicator())
                else
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.okGreen,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    onPressed: () => _saveProfile(authService, user),
                    child: const Text(
                      'KAYDET VE BAŞLA',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
                  ),

                const SizedBox(height: 24),
                TextButton(
                  onPressed: () async {
                    await authService.signOut();
                  },
                  child: const Text(
                    'Çıkış Yap',
                    style: TextStyle(color: Colors.white54),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
