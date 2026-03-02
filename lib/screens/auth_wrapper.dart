import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import 'login_screen.dart';
import 'facility_select_screen.dart';
import 'splash_screen.dart';

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

    // Oturum var ama Rol/Profil eksik -> Profil Kurulum
    if (authService.currentUserProfile == null) {
      return const FacilitySelectScreen();
    }

    // Tamamlandı -> Normal Akış/Splash
    return const SplashScreen();
  }
}
