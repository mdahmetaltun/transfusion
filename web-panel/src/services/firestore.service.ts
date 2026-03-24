import {
  collection,
  doc,
  getDoc,
  getDocs,
  deleteDoc,
  updateDoc,
  addDoc,
  query,
  orderBy,
  setDoc,
  getCountFromServer,
  Timestamp,
} from 'firebase/firestore';
import { db } from '../firebase';
import type { Case } from '../types/case';
import type { Event } from '../types/event';
import type { BloodProductUnit } from '../types/bloodProduct';
import type { UserModel, ApprovedAdmin, ApprovedUser } from '../types/user';

function safeTimestamp(val: any): any {
  if (!val) return null;
  if (typeof val.toDate === 'function') return val;
  if (val instanceof Date) return val;
  return val;
}

// ─── Cases ───────────────────────────────────────────────────────────────────

export async function getCases(): Promise<Case[]> {
  const q = query(collection(db, 'cases'), orderBy('createdAt', 'desc'));
  const snap = await getDocs(q);
  return snap.docs.map((d) => ({
    id: d.id,
    ...d.data(),
    createdAt: safeTimestamp(d.data().createdAt),
    closedAt: safeTimestamp(d.data().closedAt),
  })) as Case[];
}

export async function getCase(id: string): Promise<Case | null> {
  const snap = await getDoc(doc(db, 'cases', id));
  if (!snap.exists()) return null;
  return {
    id: snap.id,
    ...snap.data(),
    createdAt: safeTimestamp(snap.data().createdAt),
    closedAt: safeTimestamp(snap.data().closedAt),
  } as Case;
}

export async function deleteCase(id: string): Promise<void> {
  await deleteDoc(doc(db, 'cases', id));
}

// ─── Case Sub-collections ─────────────────────────────────────────────────────

export async function getCaseEvents(caseId: string): Promise<Event[]> {
  let snap;
  try {
    const q = query(
      collection(db, 'cases', caseId, 'events'),
      orderBy('timestamp', 'asc')
    );
    snap = await getDocs(q);
  } catch {
    // orderBy might require a Firestore index — fall back to unordered
    snap = await getDocs(collection(db, 'cases', caseId, 'events'));
  }
  const docs = snap.docs.map((d) => ({ id: d.id, ...d.data() })) as Event[];
  // Sort client-side by timestamp string (ISO8601 sorts lexicographically)
  return docs.sort((a, b) => {
    if (!a.timestamp) return -1;
    if (!b.timestamp) return 1;
    return a.timestamp < b.timestamp ? -1 : 1;
  });
}

export async function getCaseBloodProducts(caseId: string): Promise<BloodProductUnit[]> {
  const q = query(collection(db, 'cases', caseId, 'blood_products'));
  const snap = await getDocs(q);
  return snap.docs.map((d) => ({
    id: d.id,
    ...d.data(),
  })) as BloodProductUnit[];
}

export async function getCaseLethalTriad(caseId: string): Promise<any[]> {
  try {
    const q = query(
      collection(db, 'cases', caseId, 'lethal_triad'),
      orderBy('recordedAt', 'asc')
    );
    const snap = await getDocs(q);
    if (!snap.empty) {
      return snap.docs.map((d) => ({ id: d.id, ...d.data() }));
    }
  } catch {
    // subcollection might not exist or have no index
  }
  return [];
}

// ─── Users ───────────────────────────────────────────────────────────────────

export async function getUsers(): Promise<UserModel[]> {
  const snap = await getDocs(collection(db, 'users'));
  return snap.docs.map((d) => ({
    id: d.id,
    ...d.data(),
    createdAt: safeTimestamp(d.data().createdAt),
    lastLoginAt: safeTimestamp(d.data().lastLoginAt),
  })) as UserModel[];
}

export async function updateUserRole(userId: string, role: string): Promise<void> {
  await updateDoc(doc(db, 'users', userId), { role });
}

export async function deleteUser(userId: string): Promise<void> {
  await deleteDoc(doc(db, 'users', userId));
}

// ─── Approved Admins ─────────────────────────────────────────────────────────

export async function getApprovedAdmins(): Promise<ApprovedAdmin[]> {
  const snap = await getDocs(collection(db, 'approved_admins'));
  return snap.docs.map((d) => ({
    email: d.id,
    displayName: d.data().displayName || d.data().name || '',
    addedBy: d.data().addedBy || '',
    addedAt: safeTimestamp(d.data().addedAt),
  })) as ApprovedAdmin[];
}

export async function addApprovedAdmin(
  email: string,
  displayName: string,
  addedBy?: string
): Promise<void> {
  await setDoc(doc(db, 'approved_admins', email), {
    displayName,
    addedBy: addedBy || '',
    addedAt: Timestamp.now(),
  });
}

export async function removeApprovedAdmin(email: string): Promise<void> {
  await deleteDoc(doc(db, 'approved_admins', email));
}

// ─── Approved Users ───────────────────────────────────────────────────────────

export async function getApprovedUsers(): Promise<ApprovedUser[]> {
  const snap = await getDocs(collection(db, 'approved_users'));
  return snap.docs.map((d) => ({
    email: d.id,
    displayName: d.data().displayName || '',
    role: d.data().role || 'NURSE',
    facilityId: d.data().facilityId || '',
    addedBy: d.data().addedBy || '',
    addedAt: safeTimestamp(d.data().addedAt),
  })) as ApprovedUser[];
}

export async function addApprovedUser(
  email: string,
  displayName: string,
  role: string,
  facilityId: string,
  addedBy?: string
): Promise<void> {
  await setDoc(doc(db, 'approved_users', email), {
    displayName,
    role,
    facilityId,
    addedBy: addedBy || '',
    addedAt: Timestamp.now(),
  });
}

export async function removeApprovedUser(email: string): Promise<void> {
  await deleteDoc(doc(db, 'approved_users', email));
}

// ─── Dashboard Stats ──────────────────────────────────────────────────────────

export async function getDashboardStats(): Promise<{
  total: number;
  active: number;
  closed: number;
  users: number;
}> {
  try {
    const [casesSnap, usersSnap] = await Promise.all([
      getCountFromServer(collection(db, 'cases')),
      getCountFromServer(collection(db, 'users')),
    ]);

    const cases = await getCases();
    const active = cases.filter((c) => c.status === 'ACTIVE').length;
    const closed = cases.filter((c) => c.status === 'CLOSED').length;

    return {
      total: casesSnap.data().count,
      active,
      closed,
      users: usersSnap.data().count,
    };
  } catch {
    const cases = await getCases();
    const users = await getUsers();
    return {
      total: cases.length,
      active: cases.filter((c) => c.status === 'ACTIVE').length,
      closed: cases.filter((c) => c.status === 'CLOSED').length,
      users: users.length,
    };
  }
}

// Keep addDoc import to avoid lint errors
export { addDoc };
