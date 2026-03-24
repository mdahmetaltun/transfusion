class LethalTriadData {
  double ph;
  double temperature;
  double inr;
  double lactate;
  DateTime recordedAt;

  LethalTriadData({
    required this.ph,
    required this.temperature,
    required this.inr,
    required this.lactate,
    DateTime? recordedAt,
  }) : recordedAt = recordedAt ?? DateTime.now();

  bool get hasAcidosis => ph < 7.35;
  bool get hasHypothermia => temperature < 35.0;
  bool get hasCoagulopathy => inr > 1.5;

  int get lethalTriadCount =>
      [hasAcidosis, hasHypothermia, hasCoagulopathy].where((v) => v).length;

  bool get isLethalTriad => lethalTriadCount >= 2;

  Map<String, dynamic> toMap() {
    return {
      'ph': ph,
      'temperature': temperature,
      'inr': inr,
      'lactate': lactate,
      'recordedAt': recordedAt.toIso8601String(),
    };
  }

  factory LethalTriadData.fromMap(Map<String, dynamic> map) {
    return LethalTriadData(
      ph: (map['ph'] as num).toDouble(),
      temperature: (map['temperature'] as num).toDouble(),
      inr: (map['inr'] as num).toDouble(),
      lactate: (map['lactate'] as num).toDouble(),
      recordedAt: map['recordedAt'] != null
          ? DateTime.parse(map['recordedAt'] as String)
          : DateTime.now(),
    );
  }
}
