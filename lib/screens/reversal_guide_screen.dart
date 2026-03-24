import 'package:flutter/material.dart';
import '../core/theme.dart';

class ReversalGuideScreen extends StatefulWidget {
  const ReversalGuideScreen({super.key});

  @override
  State<ReversalGuideScreen> createState() => _ReversalGuideScreenState();
}

class _ReversalGuideScreenState extends State<ReversalGuideScreen> {
  String _searchQuery = '';
  final _searchController = TextEditingController();

  final List<_DrugReversal> _drugs = const [
    _DrugReversal(
      drugName: 'Warfarin (Coumadin)',
      mechanism: 'Vitamin K antagonisti — K vitaminine bağımlı faktörleri inhibe eder (II, VII, IX, X)',
      reversalAgent: 'K Vitamini IV + 4-Faktör PCC (Beriplex)',
      dose: 'K vitamini: 5-10mg IV yavaş infüzyon\nBeriplex (4F-PCC): 25-50 IU/kg IV',
      monitoring: 'INR hedef <1.5. Her 6 saatte INR kontrolü.',
      notes: 'Acil durumlarda PCC tercih edilir (hızlı etki). K vitamini etkisi 6-24 saatte başlar. Anlamlı kanama varsa her ikisini birden verin.',
    ),
    _DrugReversal(
      drugName: 'Dabigatran (Pradaxa)',
      mechanism: 'Direkt trombin inhibitörü — trombini doğrudan bloke eder',
      reversalAgent: 'İdarucizumab (Praxbind)',
      dose: 'İdarucizumab: 5g IV (2x 2.5g ard arda)\nAlternatif: Aktif kömür 50g PO (son 2 saatte alındıysa)',
      monitoring: 'Trombokinin zamanı (dTT), hemram.',
      notes: 'Böbrek yetmezliğinde yarı ömrü uzar. Hemodiyalizle kısmi uzaklaştırılabilir. 4F-PCC 50 IU/kg alternatif olabilir.',
    ),
    _DrugReversal(
      drugName: 'Rivaroksaban (Xarelto)',
      mechanism: 'Direkt Faktör Xa inhibitörü',
      reversalAgent: 'Andeksanet alfa (Ondexxya) veya 4-Faktör PCC',
      dose: 'Andeksanet alfa: 400-800mg IV bolus (doza göre)\nAlternatif: 4-Faktör PCC: 50 IU/kg IV',
      monitoring: 'Anti-Xa aktivitesi, PT/INR.',
      notes: 'Aktif kömür son 8 saatte alındıysa yararlıdır. Andeksanet alfa trombotik risk taşır.',
    ),
    _DrugReversal(
      drugName: 'Apiksaban (Eliquis)',
      mechanism: 'Direkt Faktör Xa inhibitörü',
      reversalAgent: 'Andeksanet alfa (Ondexxya) veya 4-Faktör PCC',
      dose: 'Andeksanet alfa: 400mg IV bolus (düşük doz)\nAlternatif: 4-Faktör PCC: 50 IU/kg IV',
      monitoring: 'Anti-Xa aktivitesi, PT/INR.',
      notes: 'Düşük doz apiksabanda daha düşük andeksanet dozu yeterlidir. Aktif kömür son 6 saatte alındıysa ekleyin.',
    ),
    _DrugReversal(
      drugName: 'Heparin (UFH)',
      mechanism: 'Antitrombin III\'ü aktive eder — Faktör Xa ve IIa\'yı inhibe eder',
      reversalAgent: 'Protamin Sülfat',
      dose: '1mg protamin per 100 IU heparin (maksimum 50mg)\nYavaş IV infüzyon (10mg/dakika max)',
      monitoring: 'aPTT veya ACT.',
      notes: 'Son heparin dozundan >2 saat geçmişse yarı aPTT dozunu azaltın. Aşırı protamin heparinize benzer etki yapabilir.',
    ),
    _DrugReversal(
      drugName: 'DMAH - Enoksaparin (Clexane)',
      mechanism: 'Ağırlıklı olarak Faktör Xa inhibisyonu',
      reversalAgent: 'Protamin Sülfat',
      dose: 'Son dozdan <8 saat: 1mg protamin per 1mg enoksaparin\nSon dozdan 8-12 saat: 0.5mg protamin per 1mg enoksaparin',
      monitoring: 'Anti-Xa düzeyi.',
      notes: 'Protamin DMAH için tam antagonist değildir (~60-80% etkili). Çok yüksek dozlarda dikkat.',
    ),
    _DrugReversal(
      drugName: 'Klopidogrel (Plavix) / Aspirin',
      mechanism: 'P2Y12 reseptör blokajı (klopidogrel) / COX-1 inhibisyonu (aspirin) — geri dönüşümsüz trombosit agregasyon inhibisyonu',
      reversalAgent: 'Trombosit Transfüzyonu + Desmopresin (DDAVP)',
      dose: 'Trombosit konsantresi: 1 ünite per 10kg\nDDAVP: 0.3 mcg/kg IV yavaş infüzyon (30 dakika)',
      monitoring: 'Trombosit agregasyon testi, kanama.',
      notes: 'Reseptör etkisi geri dönüşümsüz olduğundan trombosit transfüzyonu gerekir. Platelet transfüzyonu klopidogrel alımından >4 saat sonra en iyi sonucu verir.',
    ),
  ];

  List<_DrugReversal> get _filtered {
    if (_searchQuery.isEmpty) return _drugs;
    final q = _searchQuery.toLowerCase();
    return _drugs
        .where((d) =>
            d.drugName.toLowerCase().contains(q) ||
            d.reversalAgent.toLowerCase().contains(q) ||
            d.mechanism.toLowerCase().contains(q))
        .toList();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filtered;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Antikoagülan Geri Dönüşüm Rehberi'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                labelText: 'İlaç veya antidot ara...',
                prefixIcon: const Icon(Icons.search),
                border: const OutlineInputBorder(),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
                        },
                      )
                    : null,
              ),
              onChanged: (v) => setState(() => _searchQuery = v),
            ),
          ),
          // Disclaimer
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppTheme.warningOrange.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppTheme.warningOrange.withValues(alpha: 0.4)),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline, color: AppTheme.warningOrange, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Not: Bu ekran referans amaçlıdır. Farmakolog veya hematoloji konsültasyonu alınız.',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppTheme.warningOrange.withValues(alpha: 0.9),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(8),
              itemCount: filtered.length,
              itemBuilder: (context, i) {
                return _DrugCard(drug: filtered[i]);
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _DrugCard extends StatefulWidget {
  final _DrugReversal drug;

  const _DrugCard({required this.drug});

  @override
  State<_DrugCard> createState() => _DrugCardState();
}

class _DrugCardState extends State<_DrugCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: AppTheme.primaryColor.withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        children: [
          ListTile(
            leading: CircleAvatar(
              backgroundColor: AppTheme.primaryColor.withValues(alpha: 0.12),
              child: const Icon(Icons.medication, color: AppTheme.primaryColor),
            ),
            title: Text(
              widget.drug.drugName,
              style: const TextStyle(
                  fontWeight: FontWeight.bold, fontSize: 14),
            ),
            subtitle: Text(
              widget.drug.reversalAgent,
              style: TextStyle(
                color: AppTheme.warningOrange,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
            trailing: Icon(
              _expanded ? Icons.expand_less : Icons.expand_more,
            ),
            onTap: () => setState(() => _expanded = !_expanded),
          ),
          if (_expanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Divider(),
                  _sectionBlock('Mekanizma', widget.drug.mechanism,
                      Icons.science_outlined, Colors.blue, isDark),
                  const SizedBox(height: 10),
                  _sectionBlock('Antidot / Geri Dönüşüm Ajanı',
                      widget.drug.reversalAgent,
                      Icons.medication_liquid, AppTheme.alertRed, isDark),
                  const SizedBox(height: 10),
                  _sectionBlock('Doz', widget.drug.dose,
                      Icons.calculate, AppTheme.warningOrange, isDark),
                  const SizedBox(height: 10),
                  _sectionBlock('İzlem', widget.drug.monitoring,
                      Icons.monitor_heart, AppTheme.okGreen, isDark),
                  const SizedBox(height: 10),
                  _sectionBlock('Notlar', widget.drug.notes,
                      Icons.notes, Colors.grey, isDark),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _sectionBlock(
    String title,
    String content,
    IconData icon,
    Color color,
    bool isDark,
  ) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: color, size: 18),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: color,
                  fontSize: 12,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 2),
              Text(content, style: const TextStyle(fontSize: 13)),
            ],
          ),
        ),
      ],
    );
  }
}

class _DrugReversal {
  final String drugName;
  final String mechanism;
  final String reversalAgent;
  final String dose;
  final String monitoring;
  final String notes;

  const _DrugReversal({
    required this.drugName,
    required this.mechanism,
    required this.reversalAgent,
    required this.dose,
    required this.monitoring,
    required this.notes,
  });
}
