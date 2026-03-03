import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/theme.dart';
import '../providers/admin_settings_provider.dart';

class AdminScreen extends StatefulWidget {
  const AdminScreen({super.key});

  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> {
  final _phoneController = TextEditingController();
  final _calciumController = TextEditingController();
  final _txaController = TextEditingController();
  bool _use211 = false;

  @override
  void initState() {
    super.initState();
    // Load current settings into controllers
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final settings = Provider.of<AdminSettingsProvider>(
        context,
        listen: false,
      ).settings;
      setState(() {
        _phoneController.text = settings.bloodBankPhone;
        _calciumController.text = settings.calciumUnitThreshold.toString();
        _txaController.text = settings.txaWindowHours.toString();
        _use211 = settings.use211Ratio;
      });
    });
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _calciumController.dispose();
    _txaController.dispose();
    super.dispose();
  }

  void _saveSettings() {
    final provider = Provider.of<AdminSettingsProvider>(context, listen: false);

    provider.updateSettings(
      phone: _phoneController.text.trim(),
      use211: _use211,
      calciumThreshold: int.tryParse(_calciumController.text) ?? 4,
      txaHours: int.tryParse(_txaController.text) ?? 3,
    );

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Ayarlar başarıyla kaydedildi.',
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: AppTheme.okGreen,
      ),
    );
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Kurum Ayarları (Admin)'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          const Text(
            'Temel MTP Ayarları',
            style: TextStyle(
              color: AppTheme.primaryColor,
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _phoneController,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(
              labelText: 'Kan Bankası Çağrı Numarası',
              helperText: 'Örn: 1122, 05551234567 vb.',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Hedef Kan Ürünü Oranı',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: theme.textTheme.bodyLarge?.color,
            ),
          ),
          SwitchListTile(
            title: Text(
              _use211
                  ? '2:1:1 (Travma/Askeri Standart)'
                  : '1:1:1 (Genel MTP Standardı)',
            ),
            subtitle: const Text('Dashboard hesaplamaları buna göre yapılacaktır'),
            value: _use211,
            activeColor: AppTheme.primaryColor,
            onChanged: (val) {
              setState(() => _use211 = val);
            },
          ),
          Divider(height: 48, color: theme.dividerTheme.color),
          const Text(
            'Protokol Eşikleri & Uyarılar',
            style: TextStyle(
              color: AppTheme.primaryColor,
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _calciumController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Kalsiyum Uyarı Eşiği (Ünite)',
              helperText:
                  'Kaç ünite kanda bir kalsiyum uyarısı verilsin? (Varsayılan: 4)',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _txaController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'TXA Altın Pencere Süresi (Saat)',
              helperText: 'Sayaç kaç saatten geriye saysın? (Varsayılan: 3)',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 48),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              backgroundColor: AppTheme.okGreen,
              foregroundColor: Colors.white,
            ),
            icon: const Icon(Icons.save),
            label: const Text(
              'AYARLARI KAYDET',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            onPressed: _saveSettings,
          ),
        ],
      ),
    );
  }
}
