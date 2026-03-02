import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/theme.dart';
import '../models/user_model.dart';
import '../services/auth_service.dart';

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Icon(
                  Icons.medical_services_outlined,
                  size: 80,
                  color: AppTheme.alertRed,
                ),
                const SizedBox(height: 24),
                const Text(
                  'Masif Transfüzyon Protokolü\n(MTP) Karar Destek Sistemi',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 48),

                const Card(
                  color: Colors.black45,
                  child: Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Column(
                      children: [
                        Icon(
                          Icons.warning_amber_rounded,
                          color: AppTheme.warningOrange,
                          size: 40,
                        ),
                        SizedBox(height: 16),
                        Text(
                          "DİKKAT VE YASAL UYARI",
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                            color: AppTheme.warningOrange,
                          ),
                        ),
                        SizedBox(height: 12),
                        Text(
                          "Bu uygulama bir klinik karar destek aracıdır ve tek başına klinik karar verdirmek amacıyla kullanılamaz. Son karar her zaman hekime ve klinik gestalt değerlendirmesine aittir.\n\nSisteme hasta adı veya TC kimlik numarası (PHI) girmeyiniz.",
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 16),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 48),

                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    padding: const EdgeInsets.symmetric(vertical: 20),
                  ),
                  onPressed: () {
                    Navigator.pushReplacementNamed(
                      context,
                      '/assessment',
                    ); // Go to assessment
                  },
                  child: const Text(
                    "OKUDUM, KABUL EDİYORUM",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),

                const SizedBox(height: 24),
                // Hidden/Subtle Admin button
                Align(
                  alignment: Alignment.bottomRight,
                  child: TextButton.icon(
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
                          SnackBar(
                            content: const Text(
                              'Bu alana sadece ADMIN yetkisine sahip kullanıcılar erişebilir.',
                              style: TextStyle(color: Colors.white),
                            ),
                            backgroundColor: AppTheme.alertRed,
                          ),
                        );
                      }
                    },
                    icon: const Icon(Icons.settings, color: Colors.grey),
                    label: const Text(
                      "Kurum Ayarları",
                      style: TextStyle(color: Colors.grey),
                    ),
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
