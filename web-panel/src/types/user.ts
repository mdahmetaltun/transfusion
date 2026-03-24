export type UserRole = 'NURSE' | 'DOCTOR' | 'BLOOD_BANK' | 'ADMIN';

export interface UserModel {
  id: string;
  uid?: string;
  email: string;
  displayName: string;
  photoUrl?: string;
  photoURL?: string;
  role: UserRole;
  facilityId?: string;
  createdAt?: any;
  lastLoginAt?: any;
}

export interface ApprovedAdmin {
  email: string;
  displayName: string;
  addedBy?: string;
  addedAt?: any;
}

export interface ApprovedUser {
  email: string;
  displayName: string;
  role: UserRole;
  facilityId: string;
  addedBy?: string;
  addedAt?: any;
}
