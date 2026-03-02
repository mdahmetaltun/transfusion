enum InjuryMechanism { penetrating, blunt, nonTrauma }

/// AI / Algorithm Prediction Risk Levels based on ABC Score
enum RiskLevel {
  low,
  high,
} // ABC is usually binary: <2 is low, >=2 is high risk for MTP

/// Patient Vitals and History for MTP decision using ABC Score
class PatientAssessment {
  int heartRate;
  int systolicBp;
  bool isFastPositive; // Replaced base deficit with FAST USG for ABC Score
  InjuryMechanism mechanism;

  // Clinical Gestalt
  bool? preDecision; // Doctor's gut feeling before AI (True = Activate MTP)

  // Final Decision
  bool? finalDecision; // Doctor's actual final call after seeing AI

  PatientAssessment({
    this.heartRate = 80,
    this.systolicBp = 120,
    this.isFastPositive = false,
    this.mechanism = InjuryMechanism.blunt,
  });

  /// Calculates ABC Score (Assessment of Blood Consumption)
  /// >= 2 points indicates high likelihood of needing Massive Transfusion
  int calculateABCScore() {
    int score = 0;

    // ABC Score criteria:
    if (mechanism == InjuryMechanism.penetrating) score += 1;
    if (systolicBp <= 90) score += 1;
    if (heartRate >= 120) score += 1;
    if (isFastPositive) score += 1;

    return score;
  }

  RiskLevel calculateRisk() {
    int score = calculateABCScore();
    if (score >= 2) {
      return RiskLevel.high;
    }
    return RiskLevel.low;
  }
}
