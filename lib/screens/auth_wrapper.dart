import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import 'login_screen.dart';
import 'facility_select_screen.dart';
import 'splash_screen.dart';
import 'access_denied_screen.dart';

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context);

    // Oturum yok -> Login Ekranı
    if (authService.currentFirebaseUser == null) {
      return const LoginScreen();
    }

    // Firestore sorgusu sürüyor
    if (authService.isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    // --- WEB: Sadece admin erişimi ---
    if (kIsWeb) {
      // Profil yok ve onaylı admin değil -> Erişim Reddedildi
      if (authService.currentUserProfile == null) {
        return const AccessDeniedScreen();
      }
      // Profil var ama ADMIN değil -> Erişim Reddedildi
      if (!authService.isAdmin) {
        return const AccessDeniedScreen();
      }
      // Admin -> Uygulamaya al
      return const SplashScreen();
    }

    // --- MOBİL: Mevcut akış ---
    if (authService.currentUserProfile == null) {
      return const FacilitySelectScreen();
    }

    return const SplashScreen();
  }
}
