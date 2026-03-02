import 'dart:developer' as developer;
import 'package:intl/intl.dart';

/// Module 7: Data Security and Background Logging
/// In a real app, this would write to a secure local DB or send encrypted JSON to an API.
/// For the prototype, it logs to the console with precise timestamps.
class AuditLogger {
  static void logEvent(String eventName, {Map<String, dynamic>? data}) {
    final now = DateTime.now();
    final timestamp = DateFormat('yyyy-MM-dd HH:mm:ss.SSS').format(now);

    // Simulate HIPAA/KVKK compliant logging removing raw names, using generic IDs
    // In our app, we don't even collect names to avoid PHI issues from the start.

    String logMessage = '[$timestamp] EVENT: $eventName';
    if (data != null) {
      logMessage += ' | DATA: $data';
    }

    // Print to debug console
    developer.log(logMessage, name: 'MTP_AUDIT');
    print(logMessage); // For easier viewing in simple terminals
  }
}
