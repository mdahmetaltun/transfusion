import 'package:uuid/uuid.dart';

enum EventType {
  // Case
  caseCreated,
  caseUpdated,
  caseClosed,

  // Triage/Decision
  triageUpdated,
  gestaltRecorded,
  scoreComputed, // v1
  finalDecisionRecorded, // v1
  // MTP
  mtpActivated,
  mtpNotActivated,

  // Products
  productAdded,
  productRemoved,
  ratioStatusUpdated,

  // Vitals/Labs
  vitalsRecorded,
  labsRecorded,

  // Alerts
  alertFired,
  alertAcknowledged,
  alertDismissed,

  // Checklist
  checklistItemToggled,

  // Actions
  contactAction,
  exportDone,

  // v2
  mlPredictionComputed,
  pocResultRecorded,
  futilityAlertFired,
  syncStatusChanged,
}

abstract class EventPayload {
  Map<String, dynamic> toJson();
}

class CaseCreatedPayload implements EventPayload {
  final String location;
  final String mechanism;
  final bool isTrauma;
  final String createdByUid;
  final String facilityId;

  CaseCreatedPayload({
    required this.location,
    required this.mechanism,
    required this.isTrauma,
    required this.createdByUid,
    required this.facilityId,
  });

  @override
  Map<String, dynamic> toJson() => {
    'location': location,
    'mechanism': mechanism,
    'isTrauma': isTrauma,
    'createdByUid': createdByUid,
    'facilityId': facilityId,
  };
}

class TriageUpdatedPayload implements EventPayload {
  final int? hr;
  final int? sbp;
  final double? baseDeficit;
  final double? temp;
  final bool? isFastPositive;
  final bool? isPenetrating;
  final String riskLevel;
  final String riskReason;

  TriageUpdatedPayload({
    this.hr,
    this.sbp,
    this.baseDeficit,
    this.temp,
    this.isFastPositive,
    this.isPenetrating,
    required this.riskLevel,
    required this.riskReason,
  });

  @override
  Map<String, dynamic> toJson() => {
    if (hr != null) 'hr': hr,
    if (sbp != null) 'sbp': sbp,
    if (baseDeficit != null) 'baseDeficit': baseDeficit,
    if (temp != null) 'temp': temp,
    if (isFastPositive != null) 'isFastPositive': isFastPositive,
    if (isPenetrating != null) 'isPenetrating': isPenetrating,
    'riskLevel': riskLevel,
    'riskReason': riskReason,
  };
}

class GestaltRecordedPayload implements EventPayload {
  final String decision; // 'Aktive ederim', 'Şüpheli', 'Etmem'

  GestaltRecordedPayload({required this.decision});

  @override
  Map<String, dynamic> toJson() => {'decision': decision};
}

class ProductPayload implements EventPayload {
  final String productType; // RBC, FFP, PLT, Cryo
  final int amount;

  ProductPayload({required this.productType, required this.amount});

  @override
  Map<String, dynamic> toJson() => {
    'productType': productType,
    'amount': amount,
  };
}

class ChecklistPayload implements EventPayload {
  final String productType;
  final int completedSteps;
  final int totalSteps;
  final String status;

  ChecklistPayload({
    required this.productType,
    required this.completedSteps,
    required this.totalSteps,
    required this.status,
  });

  @override
  Map<String, dynamic> toJson() => {
    'productType': productType,
    'completedSteps': completedSteps,
    'totalSteps': totalSteps,
    'status': status,
  };
}

class AlertPayload implements EventPayload {
  final String alertId;
  final String message;
  final String severity; // WARNING, CRITICAL

  AlertPayload({
    required this.alertId,
    required this.message,
    required this.severity,
  });

  @override
  Map<String, dynamic> toJson() => {
    'alertId': alertId,
    'message': message,
    'severity': severity,
  };
}

class MtpEvent {
  final String id;
  final String caseId;
  final EventType type;
  final DateTime timestamp;
  final Map<String, dynamic>? payload;

  MtpEvent({
    String? id,
    required this.caseId,
    required this.type,
    DateTime? timestamp,
    this.payload,
  }) : id = id ?? const Uuid().v4(),
       timestamp = timestamp ?? DateTime.now();

  factory MtpEvent.withPayload({
    String? id,
    required String caseId,
    required EventType type,
    DateTime? timestamp,
    EventPayload? payload,
  }) {
    return MtpEvent(
      id: id,
      caseId: caseId,
      type: type,
      timestamp: timestamp,
      payload: payload?.toJson(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'caseId': caseId,
      'type': type.name,
      'timestamp': timestamp.toIso8601String(),
      'payload': payload,
    };
  }

  @override
  String toString() {
    return '[$timestamp] $type - Payload: $payload';
  }
}
