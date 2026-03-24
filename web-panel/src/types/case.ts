export type CaseStatus = 'ACTIVE' | 'CLOSED';

export interface AbcSummary {
  score?: number;
  riskLevel?: string;
  heartRate?: number;
  systolicBp?: number;
  isFastPositive?: boolean;
  mechanism?: string;
  patientWeightKg?: number;
  patientBloodGroup?: string;
  patientRhFactor?: string;
  fibrinogenLevel?: number;
  hasLethalTriad?: boolean;
  criteriaPoints?: Record<string, any>;
}

export interface Case {
  id: string;
  location?: string;
  status: CaseStatus;
  createdByUid?: string;
  facilityId?: string;
  createdAt?: any;
  closedAt?: any;
  notes?: string;
  totalProducts?: number;
  abcSummary?: AbcSummary;
}
