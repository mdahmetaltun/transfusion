import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../models/patient_assessment.dart';
import '../models/event_model.dart';
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

  DateTime? mtpStartTime;

  double? rotumExTemCa5;
  double? ptInr;

  List<String> activeWarnings = [];

  int get totalProductsGiven => prbcCount + ffpCount + pltCount + cryoCount;

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
    mtpStartTime = null;
    rotumExTemCa5 = null;
    ptInr = null;
    activeWarnings.clear();
    notifyListeners();
  }

  void closeCase(String notes) {
    if (currentCaseId != null) {
      _logEvent(
        EventType.caseClosed,
      ); // no payload needed for basic close, or add payload later
      _firestoreService.closeCase(
        caseId: currentCaseId!,
        notes: notes,
        totalProducts: totalProductsGiven,
      );
      currentCaseId = null;
      caseLocation = null;
      notifyListeners();
    }
  }

  // --- Assessment Updates ---
  void updateVitals({
    int? hr,
    int? sbp,
    bool? fastPositive,
    InjuryMechanism? mechanism,
  }) {
    if (hr != null) currentPatient.heartRate = hr;
    if (sbp != null) currentPatient.systolicBp = sbp;
    if (fastPositive != null) currentPatient.isFastPositive = fastPositive;
    if (mechanism != null) currentPatient.mechanism = mechanism;

    _logEvent(
      EventType.triageUpdated,
      payload: TriageUpdatedPayload(
        hr: currentPatient.heartRate,
        sbp: currentPatient.systolicBp,
        isFastPositive: currentPatient.isFastPositive,
        riskLevel: currentPatient.calculateRisk().name,
        riskReason: mechanism?.name ?? 'Unknown',
      ),
    );
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

  // --- POC Updates ---
  void updatePOC(double? teg, double? inr) {
    rotumExTemCa5 = teg;
    ptInr = inr;
    _logEvent(EventType.pocResultRecorded);
    notifyListeners();
  }

  void savePreDecision(bool decision) {
    currentPatient.preDecision = decision;

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
    return null;
  }
}
