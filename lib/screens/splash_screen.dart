import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/theme.dart';
import '../models/user_model.dart';
import '../services/auth_service.dart';

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Medical icon instead of Flutter logo
                Center(
                  child: Container(
                    width: 84,
                    height: 84,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: AppTheme.alertRed,
                        width: 3,
                      ),
                      color: AppTheme.alertRed.withValues(alpha: 0.08),
                    ),
                    child: const Icon(
                      Icons.bloodtype,
                      size: 48,
                      color: AppTheme.alertRed,
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  'Masif Transfüzyon Protokolü\n(MTP) Karar Destek Sistemi',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: theme.textTheme.headlineMedium?.color,
                  ),
                ),
                // User greeting
                Consumer<AuthService>(
                  builder: (context, auth, _) {
                    final profile = auth.currentUserProfile;
                    if (profile == null) return const SizedBox.shrink();
                    final roleLabel = _roleDisplayName(profile.role);
                    return Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: Text(
                        'Hoş geldiniz, ${profile.displayName} ($roleLabel)',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 14,
                          color: theme.textTheme.bodyMedium?.color,
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 36),
                Card(
                  color: isDark
                      ? Colors.black45
                      : AppTheme.lightSurfaceAltColor,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(
                      color: isDark
                          ? Colors.transparent
                          : theme.colorScheme.outline,
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      children: [
                        const Icon(
                          Icons.warning_amber_rounded,
                          color: AppTheme.warningOrange,
                          size: 40,
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'DİKKAT VE YASAL UYARI',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                            color: AppTheme.warningOrange,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Bu uygulama bir klinik karar destek aracıdır ve tek başına klinik karar verdirmek amacıyla kullanılamaz. Son karar her zaman hekime ve klinik gestalt değerlendirmesine aittir.\n\nSisteme hasta adı veya TC kimlik numarası (PHI) girmeyiniz.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 16,
                            height: 1.35,
                            color: theme.textTheme.bodyLarge?.color,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 40),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    padding: const EdgeInsets.symmetric(vertical: 20),
                  ),
                  onPressed: () {
                    Navigator.pushReplacementNamed(context, '/assessment');
                  },
                  child: const Text(
                    'OKUDUM, KABUL EDİYORUM',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(height: 20),
                Wrap(
                  alignment: WrapAlignment.end,
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    TextButton.icon(
                      onPressed: () {
                        Navigator.pushNamed(context, '/profile');
                      },
                      icon: Icon(
                        Icons.person,
                        color: theme.textTheme.bodyMedium?.color,
                      ),
                      label: Text(
                        'Profilim',
                        style: TextStyle(
                          color: theme.textTheme.bodyMedium?.color,
                        ),
                      ),
                    ),
                    TextButton.icon(
                      onPressed: () {
                        Navigator.pushNamed(context, '/history');
                      },
                      icon: Icon(
                        Icons.history,
                        color: theme.textTheme.bodyMedium?.color,
                      ),
                      label: Text(
                        'MTP Kayıtları',
                        style: TextStyle(
                          color: theme.textTheme.bodyMedium?.color,
                        ),
                      ),
                    ),
                    TextButton.icon(
                      onPressed: () {
                        final authService = Provider.of<AuthService>(
                          context,
                          listen: false,
                        );
                        if (authService.currentUserProfile?.role ==
                            UserRole.ADMIN) {
                          Navigator.pushNamed(context, '/admin');
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Bu alana sadece ADMIN yetkisine sahip kullanıcılar erişebilir.',
                                style: TextStyle(color: Colors.white),
                              ),
                              backgroundColor: AppTheme.alertRed,
                            ),
                          );
                        }
                      },
                      icon: Icon(
                        Icons.settings,
                        color: theme.textTheme.bodyMedium?.color,
                      ),
                      label: Text(
                        'Kurum Ayarları',
                        style: TextStyle(
                          color: theme.textTheme.bodyMedium?.color,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _roleDisplayName(UserRole role) {
    switch (role) {
      case UserRole.DOCTOR:
        return 'Hekim';
      case UserRole.NURSE:
        return 'Hemşire';
      case UserRole.ADMIN:
        return 'Admin';
      case UserRole.BLOOD_BANK:
        return 'Kan Bankası';
    }
  }
}
