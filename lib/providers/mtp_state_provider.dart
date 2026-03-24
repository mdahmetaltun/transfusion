import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../models/patient_assessment.dart';
import '../models/event_model.dart';
import '../models/blood_product_unit.dart';
import '../models/lethal_triad_data.dart';
import '../services/firestore_service.dart';

class MtpStateProvider extends ChangeNotifier {
  final FirestoreService _firestoreService = FirestoreService();
  String? currentCaseId;
  String? caseLocation;
  List<MtpEvent> events = [];

  PatientAssessment currentPatient = PatientAssessment();
  bool mtpActivated = false;
  DateTime? mtpActivationTime;

  int prbcCount = 0;
  int ffpCount = 0;
  int pltCount = 0;
  int cryoCount = 0;

  double? rotumExTemCa5;
  double? ptInr;

  // POC text field state (persists across rebuilds)
  String pocExtemCa5Text = '';
  String pocPtInrText = '';

  List<String> activeWarnings = [];

  // Patient data
  double? patientWeightKg;
  BloodGroup patientBloodGroup = BloodGroup.unknown;
  RhFactor patientRhFactor = RhFactor.unknown;

  // Lethal triad
  LethalTriadData? latestLethalTriad;
  List<LethalTriadData> lethalTriadHistory = [];

  // Fibrinogen warning (from POC)
  double? fibrinogenLevel; // g/L — warn if < 1.5

  // TEG guidance
  String? tegGuidance;

  int get totalProductsGiven => prbcCount + ffpCount + pltCount + cryoCount;

  // Ratio display getter
  String get currentRatioDisplay {
    if (prbcCount == 0 && ffpCount == 0 && pltCount == 0) return 'Henüz ürün yok';
    return '$prbcCount:$ffpCount:$pltCount';
  }

  // Ratio compliance check
  bool isRatioCompliant(bool use211) {
    if (prbcCount == 0 && ffpCount == 0 && pltCount == 0) return true;
    if (use211) {
      // 2:1:1 — for every 2 ES, expect 1 TDP and 1 TSP (±1 unit tolerance)
      if (prbcCount == 0) return ffpCount == 0 && pltCount == 0;
      final expectedOther = prbcCount / 2.0;
      return (ffpCount - expectedOther).abs() <= 1.5 &&
          (pltCount - expectedOther).abs() <= 1.5;
    } else {
      // 1:1:1 — all three should be equal (±1 unit tolerance)
      return (prbcCount - ffpCount).abs() <= 1 &&
          (ffpCount - pltCount).abs() <= 1;
    }
  }

  // MTP duration since activation
  Duration get mtpDuration {
    if (mtpActivationTime == null) return Duration.zero;
    return DateTime.now().difference(mtpActivationTime!);
  }

  String get mtpDurationFormatted {
    final d = mtpDuration;
    final h = d.inHours;
    final m = d.inMinutes % 60;
    final s = d.inSeconds % 60;
    return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  // Fibrinogen warning
  bool get needsFibrinogen =>
      fibrinogenLevel != null && fibrinogenLevel! < 1.5;

  // Lethal triad status
  bool get hasLethalTriad => latestLethalTriad?.isLethalTriad ?? false;

  String? get lethalTriadWarning {
    if (latestLethalTriad == null) return null;
    final triad = latestLethalTriad!;
    if (triad.isLethalTriad) {
      final parts = <String>[];
      if (triad.hasAcidosis) parts.add('Asidoz');
      if (triad.hasHypothermia) parts.add('Hipotermi');
      if (triad.hasCoagulopathy) parts.add('Koagülopati');
      return 'ÖLÜMCÜL ÜÇGEN: ${parts.join(' + ')} tespit edildi!';
    }
    if (triad.lethalTriadCount == 1) {
      final parts = <String>[];
      if (triad.hasAcidosis) parts.add('Asidoz');
      if (triad.hasHypothermia) parts.add('Hipotermi');
      if (triad.hasCoagulopathy) parts.add('Koagülopati');
      return 'Uyarı: ${parts.join(', ')} tespit edildi.';
    }
    return null;
  }

  void _logEvent(EventType type, {EventPayload? payload}) {
    final event = MtpEvent.withPayload(
      id: const Uuid().v4(),
      caseId: currentCaseId ?? 'SYSTEM',
      type: type,
      timestamp: DateTime.now(),
      payload: payload,
    );
    events.add(event);
    if (currentCaseId != null) {
      _firestoreService.logEvent(currentCaseId!, event);
    }
  }

  void startNewCase(
    String location, {
    String uid = 'UNKNOWN',
    String facilityId = 'UNKNOWN',
  }) {
    currentCaseId =
        'TRM-${DateTime.now().year}-${const Uuid().v4().substring(0, 4).toUpperCase()}';
    caseLocation = location;
    events.clear();

    _firestoreService.createCase(
      caseId: currentCaseId!,
      location: location,
      uid: uid,
      facilityId: facilityId,
    );

    _logEvent(
      EventType.caseCreated,
      payload: CaseCreatedPayload(
        location: location,
        mechanism: 'Unknown',
        isTrauma: true,
        createdByUid: uid,
        facilityId: facilityId,
      ),
    );

    // Clear old state safely
    currentPatient = PatientAssessment();
    mtpActivated = false;
    mtpActivationTime = null;
    prbcCount = 0;
    ffpCount = 0;
    pltCount = 0;
    cryoCount = 0;
    rotumExTemCa5 = null;
    ptInr = null;
    pocExtemCa5Text = '';
    pocPtInrText = '';
    activeWarnings.clear();

    // Reset new fields
    patientWeightKg = null;
    patientBloodGroup = BloodGroup.unknown;
    patientRhFactor = RhFactor.unknown;
    latestLethalTriad = null;
    lethalTriadHistory.clear();
    fibrinogenLevel = null;
    tegGuidance = null;

    notifyListeners();
  }

  void closeCase(String notes) {
    if (currentCaseId != null) {
      _logEvent(
        EventType.caseClosed,
      );

      final hr = currentPatient.heartRate;
      final sbp = currentPatient.systolicBp;
      final hrPoint = hr >= 120 ? 1 : 0;
      final sbpPoint = sbp <= 90 ? 1 : 0;
      final penetratingPoint =
          currentPatient.mechanism == InjuryMechanism.penetrating ? 1 : 0;
      final fastPoint = currentPatient.isFastPositive ? 1 : 0;
      final score = currentPatient.calculateABCScore();

      _firestoreService.closeCase(
        caseId: currentCaseId!,
        notes: notes,
        totalProducts: totalProductsGiven,
        abcSummary: {
          'score': score,
          'riskLevel': currentPatient.calculateRisk().name,
          'heartRate': hr,
          'systolicBp': sbp,
          'isFastPositive': currentPatient.isFastPositive,
          'mechanism': currentPatient.mechanism.name,
          'criteriaPoints': {
            'heartRateGte120': hrPoint,
            'systolicBpLte90': sbpPoint,
            'penetratingMechanism': penetratingPoint,
            'fastPositive': fastPoint,
          },
          'patientWeightKg': patientWeightKg,
          'patientBloodGroup': patientBloodGroup.name,
          'patientRhFactor': patientRhFactor.name,
          'fibrinogenLevel': fibrinogenLevel,
          'hasLethalTriad': hasLethalTriad,
          'lethalTriadData': latestLethalTriad?.toMap(),
        },
      );
      currentCaseId = null;
      caseLocation = null;
      notifyListeners();
    }
  }

  // --- Assessment Updates ---
  /// Sadece lokal state'i günceller, Firestore'a yazmaz.
  /// Final triyaj snapshot'ı savePreDecision() içinde bir kez loglanır.
  void updateVitals({
    int? hr,
    int? sbp,
    bool? fastPositive,
    InjuryMechanism? mechanism,
    bool logUpdate = false, // artık kullanılmıyor, geriye dönük uyumluluk için tutuldu
  }) {
    if (hr != null) currentPatient.heartRate = hr;
    if (sbp != null) currentPatient.systolicBp = sbp;
    if (fastPositive != null) currentPatient.isFastPositive = fastPositive;
    if (mechanism != null) currentPatient.mechanism = mechanism;
    notifyListeners();
  }

  void saveFinalDecision(bool decision) {
    currentPatient.finalDecision = decision;
    mtpActivated = decision;

    if (decision) {
      mtpActivationTime = DateTime.now();
      _logEvent(EventType.mtpActivated);
    } else {
      _logEvent(EventType.mtpNotActivated);
    }
    notifyListeners();
  }

  // --- Resuscitation Tracker ---
  void addProduct(String type) {
    if (type == 'ES') prbcCount++;
    if (type == 'TDP') ffpCount++;
    if (type == 'TSP') pltCount++;
    if (type == 'KRİYO') cryoCount++;

    _logEvent(
      EventType.productAdded,
      payload: ProductPayload(productType: type, amount: 1),
    );
    notifyListeners();
  }

  void removeProduct(String type) {
    if (type == 'ES' && prbcCount > 0) prbcCount--;
    if (type == 'TDP' && ffpCount > 0) ffpCount--;
    if (type == 'TSP' && pltCount > 0) pltCount--;
    if (type == 'KRİYO' && cryoCount > 0) cryoCount--;

    _logEvent(
      EventType.productRemoved,
      payload: ProductPayload(productType: type, amount: 1),
    );
    notifyListeners();
  }

  // Rule engine helpers
  bool needsCalcium(int threshold) {
    return totalProductsGiven > 0 && totalProductsGiven % threshold == 0;
  }

  void logAlertFired(String alertName) {
    _logEvent(
      EventType.alertFired,
      payload: AlertPayload(
        alertId: alertName,
        message: alertName,
        severity: 'WARNING',
      ),
    );
  }

  void logChecklistCompletion({
    required String productType,
    required int completedSteps,
    required int totalSteps,
  }) {
    _logEvent(
      EventType.checklistItemToggled,
      payload: ChecklistPayload(
        productType: productType,
        completedSteps: completedSteps,
        totalSteps: totalSteps,
        status: completedSteps >= totalSteps ? 'COMPLETED' : 'INCOMPLETE',
      ),
    );
  }

  // --- POC Updates ---
  void updatePOC(double? teg, double? inr) {
    rotumExTemCa5 = teg;
    ptInr = inr;
    tegGuidance = computeTegGuidance();
    _logEvent(EventType.pocResultRecorded);
    notifyListeners();
  }

  void updatePOCText({String? extemCa5, String? ptInr}) {
    if (extemCa5 != null) pocExtemCa5Text = extemCa5;
    if (ptInr != null) pocPtInrText = ptInr;
    notifyListeners();
  }

  void savePreDecision(bool decision) {
    currentPatient.preDecision = decision;

    // Triyaj verilerinin tek ve kesin snapshot'ı burada loglanır.
    _logEvent(
      EventType.triageUpdated,
      payload: TriageUpdatedPayload(
        hr: currentPatient.heartRate,
        sbp: currentPatient.systolicBp,
        isFastPositive: currentPatient.isFastPositive,
        riskLevel: currentPatient.calculateRisk().name,
        riskReason: currentPatient.mechanism.name,
      ),
    );

    _logEvent(
      EventType.gestaltRecorded,
      payload: GestaltRecordedPayload(
        decision: decision ? "Aktifleştir" : "Aktifleştirme",
      ),
    );
    notifyListeners();
  }

  void startNewAssessment() {
    startNewCase("ACİL (Varsayılan)");
  }

  // --- Patient Info ---
  void updatePatientInfo({
    double? weight,
    BloodGroup? bloodGroup,
    RhFactor? rhFactor,
  }) {
    if (weight != null) patientWeightKg = weight;
    if (bloodGroup != null) patientBloodGroup = bloodGroup;
    if (rhFactor != null) patientRhFactor = rhFactor;
    notifyListeners();
  }

  // --- Lethal Triad ---
  void updateLethalTriad(LethalTriadData data) {
    latestLethalTriad = data;
    lethalTriadHistory.insert(0, data);
    // Keep only last 10 records
    if (lethalTriadHistory.length > 10) {
      lethalTriadHistory = lethalTriadHistory.take(10).toList();
    }
    if (currentCaseId != null) {
      _firestoreService.saveLethalTriad(currentCaseId!, data);
    }
    notifyListeners();
  }

  // --- Fibrinogen ---
  void updateFibrinogen(double level) {
    fibrinogenLevel = level;
    notifyListeners();
  }

  // Dosing calculator helper
  Map<String, double> calculateDoses() {
    if (patientWeightKg == null) return {};
    final weight = patientWeightKg!;
    // Blood volume estimation
    final bloodVolumeMl = weight >= 15 ? weight * 70 : weight * 80;

    return {
      'ES_mL': weight * 10,
      'ES_units': (weight * 10 / 300).ceilToDouble(),
      'TDP_mL_low': weight * 10,
      'TDP_mL_high': weight * 15,
      'TDP_units_low': (weight * 10 / 225).ceilToDouble(),
      'TDP_units_high': (weight * 15 / 225).ceilToDouble(),
      'TSP_units': (weight / 10).ceilToDouble(),
      'KRIYO_units': (weight / 5).ceilToDouble(),
      'bloodVolumeMl': bloodVolumeMl,
    };
  }

  // TEG/ROTEM guidance
  String computeTegGuidance() {
    final ca5 = rotumExTemCa5;
    final inr = ptInr;

    if (ca5 == null && inr == null) {
      return 'TEG/ROTEM verisi girilmedi.';
    }

    if (ca5 != null && inr != null) {
      if (ca5 < 35 && inr > 1.5) {
        return 'Hem fibrinojen hem TDP (FFP) gerekli.';
      }
      if (ca5 < 35) {
        return 'EXTEM CA5 < 35mm: Kriyopresipitat/Fibrinojen konsantratı düşünün.';
      }
      if (inr > 1.5) {
        return 'INR > 1.5: TDP (FFP) verin — hedef INR < 1.5.';
      }
      return 'TEG parametreleri normal — mevcut protokole devam.';
    }

    if (ca5 != null) {
      if (ca5 < 35) {
        return 'EXTEM CA5 < 35mm: Kriyopresipitat/Fibrinojen konsantratı düşünün.';
      }
      return 'EXTEM CA5 normal (≥35mm).';
    }

    if (inr != null && inr > 1.5) {
      return 'INR > 1.5: TDP\'yi artırın, hedef INR < 1.5.';
    }
    return 'TEG parametreleri normal — mevcut protokole devam.';
  }

  // --- Futility & Over-activation warnings ---
  String? checkWarnings() {
    // Over-activation (Module 6): Non-bleeding shock
    if (currentPatient.calculateABCScore() >= 2 &&
        currentPatient.mechanism == InjuryMechanism.nonTrauma) {
      return "DİKKAT: Yüksek skor fakat travma öyküsü YOK. Medikal şok (sepsis/kardiyojenik vb.) açısından değerlendirin. MTP aktivasyonu uygun mu?";
    }

    // Futility: After 3 hours + massive products but still going?
    if (mtpActivationTime != null) {
      final elapsedMinutes = DateTime.now()
          .difference(mtpActivationTime!)
          .inMinutes;
      if (elapsedMinutes > 240 && totalProductsGiven > 20) {
        return "FÜTİLİTE (FAYDASIZLIK) UYARISI: >4 saat süren ve >20 üniteyi aşan masif transfüzyon. REBOA, acil cerrahi veya sonlandırma (STOP kriterleri) düşünün.";
      }
    }

    // Lethal triad warning
    if (hasLethalTriad) {
      return lethalTriadWarning;
    }

    return null;
  }
}
