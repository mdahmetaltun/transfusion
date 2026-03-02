import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../core/theme.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context);
    final userProfile = authService.currentUserProfile;
    final firebaseUser = authService.currentFirebaseUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profilim'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Icon(
                Icons.account_circle,
                size: 100,
                color: Colors.white70,
              ),
              const SizedBox(height: 24),
              if (userProfile != null) ...[
                _buildInfoTile('İsim', userProfile.displayName),
                _buildInfoTile('Email', userProfile.email),
                _buildInfoTile('Rol', userProfile.role.name),
                _buildInfoTile('Kurum Kodu', userProfile.facilityId),
              ] else if (firebaseUser != null) ...[
                _buildInfoTile('Email', firebaseUser.email ?? 'Bilinmiyor'),
                const Padding(
                  padding: EdgeInsets.only(top: 16.0),
                  child: Text(
                    'Klinik rol profiliniz henüz tamamlanmamış.',
                    style: TextStyle(color: AppTheme.warningOrange),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
              const Spacer(),
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

  Widget _buildInfoTile(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white12,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: const TextStyle(color: Colors.white70, fontSize: 16),
            ),
            Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ],
        ),
      ),
    );
  }
}
