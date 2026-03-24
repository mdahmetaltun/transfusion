import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/event_model.dart';
import '../models/blood_product_unit.dart';
import '../models/lethal_triad_data.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// Creates a primary document for an MTP Case in `cases/` root collection.
  Future<void> createCase({
    required String caseId,
    required String location,
    required String uid,
    required String facilityId,
  }) async {
    try {
      await _db.collection('cases').doc(caseId).set({
        'caseId': caseId,
        'location': location,
        'createdByUid': uid,
        'facilityId': facilityId,
        'status': 'ACTIVE',
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      if (kDebugMode) print("Error creating case in Firestore: $e");
    }
  }

  /// Appends an event log to the subcollection `cases/{caseId}/events/`
  Future<void> logEvent(String caseId, MtpEvent event) async {
    try {
      await _db
          .collection('cases')
          .doc(caseId)
          .collection('events')
          .doc(event.id)
          .set({
        'type': event.type.toString().split('.').last,
        'timestamp': event.timestamp.toIso8601String(),
        'payload': event.payload,
      });
    } catch (e) {
      if (kDebugMode) print("Error logging event to Firestore: $e");
    }
  }

  /// Closes the case, updating status and duration
  Future<void> closeCase({
    required String caseId,
    required String notes,
    required int totalProducts,
    Map<String, dynamic>? abcSummary,
  }) async {
    try {
      final updates = <String, dynamic>{
        'status': 'CLOSED',
        'closedAt': FieldValue.serverTimestamp(),
        'notes': notes,
        'totalProducts': totalProducts,
      };
      if (abcSummary != null) {
        updates['abcSummary'] = abcSummary;
      }

      await _db.collection('cases').doc(caseId).update(updates);
    } catch (e) {
      if (kDebugMode) print("Error closing case: $e");
    }
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> watchCases() {
    return _db
        .collection('cases')
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> watchCasesByCreator(
    String creatorUid,
  ) {
    return _db
        .collection('cases')
        .where('createdByUid', isEqualTo: creatorUid)
        .snapshots();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> watchCaseEvents(String caseId) {
    return _db
        .collection('cases')
        .doc(caseId)
        .collection('events')
        .orderBy('timestamp', descending: true)
        .snapshots();
  }

  // Blood products subcollection: cases/{caseId}/blood_products/{unitId}
  Future<void> saveBloodProduct(String caseId, BloodProductUnit unit) async {
    try {
      await _db
          .collection('cases')
          .doc(caseId)
          .collection('blood_products')
          .doc(unit.id)
          .set(unit.toMap());
    } catch (e) {
      if (kDebugMode) print("Error saving blood product: $e");
      rethrow;
    }
  }

  Future<void> updateBloodProductStatus(
    String caseId,
    String unitId,
    Map<String, dynamic> updates,
  ) async {
    try {
      await _db
          .collection('cases')
          .doc(caseId)
          .collection('blood_products')
          .doc(unitId)
          .update(updates);
    } catch (e) {
      if (kDebugMode) print("Error updating blood product status: $e");
      rethrow;
    }
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> watchBloodProducts(
      String caseId) {
    return _db
        .collection('cases')
        .doc(caseId)
        .collection('blood_products')
        .snapshots();
  }

  Future<List<Map<String, dynamic>>> fetchBloodProducts(String caseId) async {
    try {
      final snapshot = await _db
          .collection('cases')
          .doc(caseId)
          .collection('blood_products')
          .get();
      return snapshot.docs.map((d) => d.data()).toList();
    } catch (e) {
      if (kDebugMode) print("Error fetching blood products: $e");
      return [];
    }
  }

  Future<void> saveLethalTriad(String caseId, LethalTriadData data) async {
    try {
      await _db
          .collection('cases')
          .doc(caseId)
          .collection('lethal_triad')
          .add(data.toMap());
    } catch (e) {
      if (kDebugMode) print("Error saving lethal triad: $e");
    }
  }
}
