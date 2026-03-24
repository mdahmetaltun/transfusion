import { useEffect, useState, type FormEvent } from 'react';
import { UserPlus, Trash2, Save, Users, Mail } from 'lucide-react';
import { PageLayout } from '../components/layout/PageLayout';
import { Spinner } from '../components/ui/Spinner';
import { Badge } from '../components/ui/Badge';
import { Modal } from '../components/ui/Modal';
import { EmptyState } from '../components/ui/EmptyState';
import { DataTable } from '../components/tables/DataTable';
import {
  getUsers,
  updateUserRole,
  deleteUser,
  getApprovedUsers,
  addApprovedUser,
  removeApprovedUser,
} from '../services/firestore.service';
import type { UserModel, UserRole, ApprovedUser } from '../types/user';
import type { ColumnDef } from '@tanstack/react-table';

const ROLE_LABELS: Record<UserRole, string> = {
  DOCTOR: 'Doktor',
  NURSE: 'Hemşire',
  BLOOD_BANK: 'Kan Bankası',
  ADMIN: 'Admin',
};

function formatDate(ts: any): string {
  if (!ts) return '—';
  try {
    const date = typeof ts.toDate === 'function' ? ts.toDate() : new Date(ts);
    return date.toLocaleDateString('tr-TR', { day: '2-digit', month: '2-digit', year: 'numeric' });
  } catch {
    return '—';
  }
}

export function UsersPage() {
  const [tab, setTab] = useState<'registered' | 'invited'>('registered');

  // Registered users
  const [users, setUsers] = useState<UserModel[]>([]);
  const [usersLoading, setUsersLoading] = useState(true);
  const [usersError, setUsersError] = useState<string | null>(null);
  const [deleteTarget, setDeleteTarget] = useState<UserModel | null>(null);
  const [deleting, setDeleting] = useState(false);
  const [pendingRoles, setPendingRoles] = useState<Record<string, UserRole>>({});
  const [savingRoles, setSavingRoles] = useState<Record<string, boolean>>({});

  // Invited users
  const [invited, setInvited] = useState<ApprovedUser[]>([]);
  const [invitedLoading, setInvitedLoading] = useState(true);
  const [revokeTarget, setRevokeTarget] = useState<ApprovedUser | null>(null);
  const [revoking, setRevoking] = useState(false);

  // Add form
  const [newEmail, setNewEmail] = useState('');
  const [newDisplayName, setNewDisplayName] = useState('');
  const [newRole, setNewRole] = useState<UserRole>('NURSE');
  const [newFacilityId, setNewFacilityId] = useState('');
  const [adding, setAdding] = useState(false);
  const [addError, setAddError] = useState<string | null>(null);
  const [addSuccess, setAddSuccess] = useState(false);

  useEffect(() => {
    loadUsers();
    loadInvited();
  }, []);

  const loadUsers = async () => {
    setUsersLoading(true);
    try {
      setUsers(await getUsers());
    } catch {
      setUsersError('Kullanıcılar yüklenirken hata oluştu.');
    } finally {
      setUsersLoading(false);
    }
  };

  const loadInvited = async () => {
    setInvitedLoading(true);
    try {
      setInvited(await getApprovedUsers());
    } finally {
      setInvitedLoading(false);
    }
  };

  const handleAdd = async (e: FormEvent) => {
    e.preventDefault();
    setAddError(null);
    setAddSuccess(false);

    const email = newEmail.trim().toLowerCase();
    const displayName = newDisplayName.trim();
    const facilityId = newFacilityId.trim();

    if (!email || !email.includes('@')) { setAddError('Geçerli bir e-posta adresi girin.'); return; }

    if (
      invited.some((u) => u.email === email) ||
      users.some((u) => u.email === email)
    ) {
      setAddError('Bu e-posta zaten kayıtlı veya davetli.');
      return;
    }

    setAdding(true);
    try {
      await addApprovedUser(email, displayName, newRole, facilityId);
      setInvited((prev) => [...prev, { email, displayName, role: newRole, facilityId, addedAt: new Date() }]);
      setNewEmail('');
      setNewDisplayName('');
      setNewFacilityId('');
      setNewRole('NURSE');
      setAddSuccess(true);
      setTimeout(() => setAddSuccess(false), 3000);
    } catch (err: any) {
      setAddError(`Hata: ${err?.message || err?.code || 'Bilinmeyen hata'}`);
    } finally {
      setAdding(false);
    }
  };

  const handleRoleChange = (userId: string, role: UserRole) =>
    setPendingRoles((prev) => ({ ...prev, [userId]: role }));

  const handleSaveRole = async (userId: string) => {
    const newRole = pendingRoles[userId];
    if (!newRole) return;
    setSavingRoles((prev) => ({ ...prev, [userId]: true }));
    try {
      await updateUserRole(userId, newRole);
      setUsers((prev) => prev.map((u) => (u.id === userId ? { ...u, role: newRole } : u)));
      setPendingRoles((prev) => { const next = { ...prev }; delete next[userId]; return next; });
    } catch {
      alert('Rol güncellenirken hata oluştu.');
    } finally {
      setSavingRoles((prev) => ({ ...prev, [userId]: false }));
    }
  };

  const handleDelete = async () => {
    if (!deleteTarget) return;
    setDeleting(true);
    try {
      await deleteUser(deleteTarget.id);
      setUsers((prev) => prev.filter((u) => u.id !== deleteTarget.id));
      setDeleteTarget(null);
    } catch {
      alert('Kullanıcı silinirken hata oluştu.');
    } finally {
      setDeleting(false);
    }
  };

  const handleRevoke = async () => {
    if (!revokeTarget) return;
    setRevoking(true);
    try {
      await removeApprovedUser(revokeTarget.email);
      setInvited((prev) => prev.filter((u) => u.email !== revokeTarget.email));
      setRevokeTarget(null);
    } catch {
      alert('Davet iptal edilirken hata oluştu.');
    } finally {
      setRevoking(false);
    }
  };

  const userColumns: ColumnDef<UserModel, any>[] = [
    {
      header: 'Ad',
      accessorKey: 'displayName',
      cell: ({ row }) => (
        <div className="flex items-center gap-3">
          {row.original.photoURL ? (
            <img src={row.original.photoURL} alt="" className="w-8 h-8 rounded-full object-cover" />
          ) : (
            <div className="w-8 h-8 rounded-full bg-gray-200 dark:bg-gray-700 flex items-center justify-center text-sm font-semibold text-gray-600 dark:text-gray-300">
              {(row.original.displayName || row.original.email || 'U').charAt(0).toUpperCase()}
            </div>
          )}
          <div>
            <p className="font-medium text-gray-900 dark:text-white text-sm">{row.original.displayName || '—'}</p>
            <p className="text-xs text-gray-400">{row.original.email}</p>
          </div>
        </div>
      ),
    },
    {
      header: 'Rol',
      accessorKey: 'role',
      cell: ({ row }) => {
        const userId = row.original.id;
        const currentRole = row.original.role;
        const pending = pendingRoles[userId];
        const displayRole = pending || currentRole;
        const hasChange = !!pending && pending !== currentRole;
        return (
          <div className="flex items-center gap-2">
            <Badge variant={displayRole as any}>{ROLE_LABELS[displayRole] || displayRole}</Badge>
            <select
              value={displayRole}
              onChange={(e) => handleRoleChange(userId, e.target.value as UserRole)}
              className="text-xs border border-gray-200 dark:border-gray-700 rounded-lg px-2 py-1 text-gray-700 dark:text-gray-300 bg-white dark:bg-gray-800 focus:outline-none focus:ring-2 focus:ring-red-500"
            >
              {Object.entries(ROLE_LABELS).map(([val, label]) => (
                <option key={val} value={val}>{label}</option>
              ))}
            </select>
            {hasChange && (
              <button
                onClick={() => handleSaveRole(userId)}
                disabled={savingRoles[userId]}
                className="p-1.5 bg-green-600 hover:bg-green-700 text-white rounded-lg transition-colors disabled:opacity-50"
                title="Kaydet"
              >
                <Save size={14} />
              </button>
            )}
          </div>
        );
      },
    },
    {
      header: 'Kurum',
      accessorKey: 'facilityId',
      cell: ({ getValue }) => <span className="text-xs text-gray-500">{getValue<string>() || '—'}</span>,
    },
    {
      header: 'İşlemler',
      id: 'actions',
      cell: ({ row }) => (
        <button
          onClick={() => setDeleteTarget(row.original)}
          className="p-1.5 text-red-600 hover:bg-red-50 dark:hover:bg-red-900/20 rounded-lg transition-colors"
          title="Sil"
        >
          <Trash2 size={16} />
        </button>
      ),
    },
  ];

  return (
    <PageLayout title="Kullanıcılar">
      <div className="grid grid-cols-1 lg:grid-cols-3 gap-6">
        {/* Add Form */}
        <div className="lg:col-span-1">
          <div className="bg-white dark:bg-gray-900 rounded-xl border border-gray-200 dark:border-gray-800 p-6">
            <div className="flex items-center gap-2 mb-5">
              <UserPlus size={20} className="text-red-600" />
              <h2 className="font-semibold text-gray-900 dark:text-white">Kullanıcı Ekle</h2>
            </div>
            <p className="text-xs text-gray-500 dark:text-gray-400 mb-4">
              Eklediğiniz e-posta adresi ile Google hesabına giriş yapan kullanıcı sisteme otomatik dahil edilir.
            </p>

            <form onSubmit={handleAdd} className="space-y-4">
              <div>
                <label className="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-1">E-posta</label>
                <input
                  type="email"
                  value={newEmail}
                  onChange={(e) => setNewEmail(e.target.value)}
                  placeholder="kullanici@ornek.com"
                  className="w-full px-3 py-2 border border-gray-200 dark:border-gray-700 rounded-lg bg-white dark:bg-gray-800 text-gray-900 dark:text-gray-100 text-sm focus:outline-none focus:ring-2 focus:ring-red-500"
                  disabled={adding}
                />
              </div>

              <div>
                <label className="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-1">
                  Ad Soyad <span className="text-gray-400 font-normal">(opsiyonel)</span>
                </label>
                <input
                  type="text"
                  value={newDisplayName}
                  onChange={(e) => setNewDisplayName(e.target.value)}
                  placeholder="Ahmet Yılmaz"
                  className="w-full px-3 py-2 border border-gray-200 dark:border-gray-700 rounded-lg bg-white dark:bg-gray-800 text-gray-900 dark:text-gray-100 text-sm focus:outline-none focus:ring-2 focus:ring-red-500"
                  disabled={adding}
                />
              </div>

              <div>
                <label className="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-1">
                  Rol <span className="text-gray-400 font-normal">(opsiyonel)</span>
                </label>
                <select
                  value={newRole}
                  onChange={(e) => setNewRole(e.target.value as UserRole)}
                  className="w-full px-3 py-2 border border-gray-200 dark:border-gray-700 rounded-lg bg-white dark:bg-gray-800 text-gray-900 dark:text-gray-100 text-sm focus:outline-none focus:ring-2 focus:ring-red-500"
                  disabled={adding}
                >
                  {Object.entries(ROLE_LABELS).map(([val, label]) => (
                    <option key={val} value={val}>{label}</option>
                  ))}
                </select>
              </div>

              <div>
                <label className="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-1">
                  Kurum Kodu <span className="text-gray-400 font-normal">(opsiyonel)</span>
                </label>
                <input
                  type="text"
                  value={newFacilityId}
                  onChange={(e) => setNewFacilityId(e.target.value)}
                  placeholder="HASTANE-001"
                  className="w-full px-3 py-2 border border-gray-200 dark:border-gray-700 rounded-lg bg-white dark:bg-gray-800 text-gray-900 dark:text-gray-100 text-sm focus:outline-none focus:ring-2 focus:ring-red-500"
                  disabled={adding}
                />
              </div>

              {addError && (
                <div className="px-3 py-2 bg-red-50 border border-red-200 rounded-lg text-red-700 text-xs">{addError}</div>
              )}
              {addSuccess && (
                <div className="px-3 py-2 bg-green-50 border border-green-200 rounded-lg text-green-700 text-xs">
                  Kullanıcı başarıyla eklendi!
                </div>
              )}

              <button
                type="submit"
                disabled={adding}
                className="w-full px-4 py-2.5 bg-red-600 hover:bg-red-700 text-white text-sm font-medium rounded-lg transition-colors disabled:opacity-50 flex items-center justify-center gap-2"
              >
                {adding ? (
                  <div className="w-4 h-4 border-2 border-white/40 border-t-white rounded-full animate-spin" />
                ) : (
                  <UserPlus size={16} />
                )}
                {adding ? 'Ekleniyor...' : 'Kullanıcı Ekle'}
              </button>
            </form>
          </div>
        </div>

        {/* Users List */}
        <div className="lg:col-span-2">
          <div className="bg-white dark:bg-gray-900 rounded-xl border border-gray-200 dark:border-gray-800">
            {/* Tabs */}
            <div className="px-6 pt-4 border-b border-gray-100 dark:border-gray-800 flex gap-4">
              <button
                onClick={() => setTab('registered')}
                className={`flex items-center gap-2 pb-3 text-sm font-medium border-b-2 transition-colors ${
                  tab === 'registered'
                    ? 'border-red-600 text-red-600'
                    : 'border-transparent text-gray-500 hover:text-gray-700 dark:hover:text-gray-300'
                }`}
              >
                <Users size={15} />
                Kayıtlı
                <span className="text-xs bg-gray-100 dark:bg-gray-800 text-gray-500 px-1.5 py-0.5 rounded-full">
                  {users.length}
                </span>
              </button>
              <button
                onClick={() => setTab('invited')}
                className={`flex items-center gap-2 pb-3 text-sm font-medium border-b-2 transition-colors ${
                  tab === 'invited'
                    ? 'border-red-600 text-red-600'
                    : 'border-transparent text-gray-500 hover:text-gray-700 dark:hover:text-gray-300'
                }`}
              >
                <Mail size={15} />
                Davetli
                <span className="text-xs bg-gray-100 dark:bg-gray-800 text-gray-500 px-1.5 py-0.5 rounded-full">
                  {invited.length}
                </span>
              </button>
            </div>

            {/* Registered tab */}
            {tab === 'registered' && (
              <div className="p-4">
                {usersLoading ? (
                  <Spinner />
                ) : usersError ? (
                  <div className="text-red-600 bg-red-50 px-4 py-3 rounded-lg text-sm">{usersError}</div>
                ) : users.length === 0 ? (
                  <EmptyState title="Kullanıcı bulunamadı" description="Henüz giriş yapmış kullanıcı yok." />
                ) : (
                  <DataTable columns={userColumns} data={users} />
                )}
              </div>
            )}

            {/* Invited tab */}
            {tab === 'invited' && (
              <div>
                {invitedLoading ? (
                  <div className="p-6"><Spinner /></div>
                ) : invited.length === 0 ? (
                  <div className="p-6">
                    <EmptyState title="Davetli bulunamadı" description="Henüz davet edilmiş kullanıcı yok." />
                  </div>
                ) : (
                  <div className="divide-y divide-gray-100 dark:divide-gray-800">
                    {invited.map((u) => (
                      <div key={u.email} className="px-6 py-4 flex items-center justify-between hover:bg-gray-50 dark:hover:bg-gray-800/40 transition-colors">
                        <div className="flex items-center gap-3">
                          <div className="w-9 h-9 rounded-full bg-blue-100 dark:bg-blue-900/30 flex items-center justify-center">
                            <span className="text-blue-700 dark:text-blue-400 text-sm font-semibold">
                              {(u.displayName || u.email).charAt(0).toUpperCase()}
                            </span>
                          </div>
                          <div>
                            <p className="text-sm font-medium text-gray-900 dark:text-white">{u.displayName}</p>
                            <p className="text-xs text-gray-400">{u.email}</p>
                            <div className="flex items-center gap-2 mt-0.5">
                              <Badge variant={u.role as any}>{ROLE_LABELS[u.role] || u.role}</Badge>
                              <span className="text-xs text-gray-400">{u.facilityId}</span>
                            </div>
                          </div>
                        </div>
                        <div className="flex items-center gap-3">
                          {u.addedAt && (
                            <span className="text-xs text-gray-300 dark:text-gray-600">{formatDate(u.addedAt)}</span>
                          )}
                          <button
                            onClick={() => setRevokeTarget(u)}
                            className="p-2 text-red-500 hover:bg-red-50 dark:hover:bg-red-900/20 rounded-lg transition-colors"
                            title="İptal Et"
                          >
                            <Trash2 size={16} />
                          </button>
                        </div>
                      </div>
                    ))}
                  </div>
                )}
              </div>
            )}
          </div>
        </div>
      </div>

      {/* Delete user modal */}
      <Modal
        isOpen={!!deleteTarget}
        onClose={() => setDeleteTarget(null)}
        onConfirm={handleDelete}
        title="Kullanıcıyı Sil"
        confirmText={deleting ? 'Siliniyor...' : 'Evet, Sil'}
        confirmVariant="danger"
      >
        <p>
          <strong>{deleteTarget?.displayName || deleteTarget?.email}</strong> kullanıcısını silmek
          istediğinizden emin misiniz? Bu işlem geri alınamaz.
        </p>
      </Modal>

      {/* Revoke invite modal */}
      <Modal
        isOpen={!!revokeTarget}
        onClose={() => setRevokeTarget(null)}
        onConfirm={handleRevoke}
        title="Daveti İptal Et"
        confirmText={revoking ? 'İptal ediliyor...' : 'Evet, İptal Et'}
        confirmVariant="danger"
      >
        <p>
          <strong>{revokeTarget?.displayName || revokeTarget?.email}</strong> için gönderilen
          daveti iptal etmek istediğinizden emin misiniz?
        </p>
      </Modal>
    </PageLayout>
  );
}
