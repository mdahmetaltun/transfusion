import 'package:uuid/uuid.dart';

enum EventType {
  caseCreated,
  vitalsUpdated,
  mtpActivated,
  mtpDeclined,
  mtpStopped,
  productAdded,
  productRemoved,
  alertFired,
  pocUpdated,
  caseClosed,
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
