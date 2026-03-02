import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/event_model.dart';

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
      if (kDebugMode) print("Error creating case in Firestore: \$e");
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
      if (kDebugMode) print("Error logging event to Firestore: \$e");
    }
  }

  /// Closes the case, updating status and duration
  Future<void> closeCase({
    required String caseId,
    required String notes,
    required int totalProducts,
  }) async {
    try {
      await _db.collection('cases').doc(caseId).update({
        'status': 'CLOSED',
        'closedAt': FieldValue.serverTimestamp(),
        'notes': notes,
        'totalProducts': totalProducts,
      });
    } catch (e) {
      if (kDebugMode) print("Error closing case: \$e");
    }
  }
}
