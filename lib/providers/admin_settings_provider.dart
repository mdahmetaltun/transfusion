import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsModel {
  String bloodBankPhone;
  bool use211Ratio; // False = 1:1:1, True = 2:1:1
  int calciumUnitThreshold; // Default 4
  int txaWindowHours; // Default 3

  SettingsModel({
    this.bloodBankPhone = '1122',
    this.use211Ratio = false, // 1:1:1 is the standard for MTP usually
    this.calciumUnitThreshold = 4,
    this.txaWindowHours = 3,
  });
}

class AdminSettingsProvider extends ChangeNotifier {
  SettingsModel _settings = SettingsModel();
  SettingsModel get settings => _settings;

  AdminSettingsProvider() {
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    _settings = SettingsModel(
      bloodBankPhone: prefs.getString('bloodBankPhone') ?? '1122',
      use211Ratio: prefs.getBool('use211Ratio') ?? false,
      calciumUnitThreshold: prefs.getInt('calciumUnitThreshold') ?? 4,
      txaWindowHours: prefs.getInt('txaWindowHours') ?? 3,
    );
    notifyListeners();
  }

  Future<void> updateSettings({
    String? phone,
    bool? use211,
    int? calciumThreshold,
    int? txaHours,
  }) async {
    final prefs = await SharedPreferences.getInstance();

    if (phone != null) {
      _settings.bloodBankPhone = phone;
      await prefs.setString('bloodBankPhone', phone);
    }
    if (use211 != null) {
      _settings.use211Ratio = use211;
      await prefs.setBool('use211Ratio', use211);
    }
    if (calciumThreshold != null) {
      _settings.calciumUnitThreshold = calciumThreshold;
      await prefs.setInt('calciumUnitThreshold', calciumThreshold);
    }
    if (txaHours != null) {
      _settings.txaWindowHours = txaHours;
      await prefs.setInt('txaWindowHours', txaHours);
    }

    notifyListeners();
  }
}
