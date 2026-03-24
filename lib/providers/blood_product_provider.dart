import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../models/blood_product_unit.dart';
import '../services/firestore_service.dart';

class BloodProductProvider extends ChangeNotifier {
  List<BloodProductUnit> units = [];

  // Pending operations queue for offline support
  final List<Map<String, dynamic>> _pendingOps = [];

  void registerUnit(BloodProductUnit unit) {
    units.add(unit);
    notifyListeners();
    _saveToFirestore(unit);
    _checkExpirySoon();
  }

  void markReceived(String unitId) {
    final idx = units.indexWhere((u) => u.id == unitId);
    if (idx == -1) return;
    units[idx].status = ProductStatus.received;
    units[idx].receivedAt = DateTime.now();
    notifyListeners();
    _updateStatusInFirestore(unitId, {
      'status': ProductStatus.received.name,
      'receivedAt': units[idx].receivedAt!.toIso8601String(),
    });
  }

  void markAdministered(String unitId) {
    final idx = units.indexWhere((u) => u.id == unitId);
    if (idx == -1) return;
    units[idx].status = ProductStatus.administered;
    units[idx].administeredAt = DateTime.now();
    notifyListeners();
    _updateStatusInFirestore(unitId, {
      'status': ProductStatus.administered.name,
      'administeredAt': units[idx].administeredAt!.toIso8601String(),
    });
    _checkExpirySoon();
  }

  void markWasted(String unitId, String reason) {
    final idx = units.indexWhere((u) => u.id == unitId);
    if (idx == -1) return;
    units[idx].status = ProductStatus.wasted;
    units[idx].notes = (units[idx].notes != null)
        ? '${units[idx].notes}\nİmha nedeni: $reason'
        : 'İmha nedeni: $reason';
    notifyListeners();
    _updateStatusInFirestore(unitId, {
      'status': ProductStatus.wasted.name,
      'notes': units[idx].notes,
    });
  }

  int get esCount => units
      .where((u) =>
          u.productType == BloodProductType.ES &&
          u.status == ProductStatus.administered)
      .length;

  int get ffpCount => units
      .where((u) =>
          u.productType == BloodProductType.TDP &&
          u.status == ProductStatus.administered)
      .length;

  int get pltCount => units
      .where((u) =>
          u.productType == BloodProductType.TSP &&
          u.status == ProductStatus.administered)
      .length;

  int get cryoCount => units
      .where((u) =>
          u.productType == BloodProductType.KRIYO &&
          u.status == ProductStatus.administered)
      .length;

  List<BloodProductUnit> get expiringSoon => units
      .where((u) =>
          (u.status == ProductStatus.registered ||
              u.status == ProductStatus.received) &&
          u.isExpiringSoon)
      .toList();

  List<BloodProductUnit> get expiredNotAdministered => units
      .where((u) =>
          (u.status == ProductStatus.registered ||
              u.status == ProductStatus.received) &&
          u.isExpired)
      .toList();

  void clearForNewCase() {
    units.clear();
    _pendingOps.clear();
    notifyListeners();
  }

  Future<void> loadForCase(String caseId, FirestoreService fs) async {
    try {
      final docs = await fs.fetchBloodProducts(caseId);
      units = docs.map((d) => BloodProductUnit.fromMap(d)).toList();
      notifyListeners();
    } catch (e) {
      if (kDebugMode) print('BloodProductProvider.loadForCase error: $e');
    }
  }

  void _checkExpirySoon() {
    if (expiringSoon.isNotEmpty || expiredNotAdministered.isNotEmpty) {
      HapticFeedback.vibrate();
    }
  }

  String? _currentCaseId;

  void setCaseId(String caseId) {
    _currentCaseId = caseId;
  }

  FirestoreService? _firestoreService;

  void setFirestoreService(FirestoreService fs) {
    _firestoreService = fs;
  }

  Future<void> _saveToFirestore(BloodProductUnit unit) async {
    if (_currentCaseId == null || _firestoreService == null) {
      _pendingOps.add({'type': 'save', 'unit': unit.toMap()});
      return;
    }
    try {
      await _firestoreService!.saveBloodProduct(_currentCaseId!, unit);
      await _retryPendingOps();
    } catch (e) {
      if (kDebugMode) print('_saveToFirestore error: $e');
      _pendingOps.add({'type': 'save', 'unitId': unit.id, 'data': unit.toMap()});
    }
  }

  Future<void> _updateStatusInFirestore(
      String unitId, Map<String, dynamic> updates) async {
    if (_currentCaseId == null || _firestoreService == null) {
      _pendingOps.add({
        'type': 'update',
        'unitId': unitId,
        'updates': updates,
      });
      return;
    }
    try {
      await _firestoreService!
          .updateBloodProductStatus(_currentCaseId!, unitId, updates);
      await _retryPendingOps();
    } catch (e) {
      if (kDebugMode) print('_updateStatusInFirestore error: $e');
      _pendingOps.add({
        'type': 'update',
        'unitId': unitId,
        'updates': updates,
      });
    }
  }

  Future<void> _retryPendingOps() async {
    if (_pendingOps.isEmpty) return;
    if (_currentCaseId == null || _firestoreService == null) return;

    final toRetry = List<Map<String, dynamic>>.from(_pendingOps);
    _pendingOps.clear();

    for (final op in toRetry) {
      try {
        if (op['type'] == 'save') {
          final unit = BloodProductUnit.fromMap(
              Map<String, dynamic>.from(op['data'] as Map));
          await _firestoreService!.saveBloodProduct(_currentCaseId!, unit);
        } else if (op['type'] == 'update') {
          await _firestoreService!.updateBloodProductStatus(
            _currentCaseId!,
            op['unitId'] as String,
            Map<String, dynamic>.from(op['updates'] as Map),
          );
        }
      } catch (e) {
        if (kDebugMode) print('Retry pending op error: $e');
        _pendingOps.add(op);
      }
    }
  }
}
