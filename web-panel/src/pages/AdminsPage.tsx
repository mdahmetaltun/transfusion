import { useEffect, useState, type FormEvent } from 'react';
import { UserPlus, Trash2, Shield } from 'lucide-react';
import { PageLayout } from '../components/layout/PageLayout';
import { Spinner } from '../components/ui/Spinner';
import { Modal } from '../components/ui/Modal';
import { EmptyState } from '../components/ui/EmptyState';
import { getApprovedAdmins, addApprovedAdmin, removeApprovedAdmin } from '../services/firestore.service';
import type { ApprovedAdmin } from '../types/user';

function formatDate(ts: any): string {
  if (!ts) return '—';
  try {
    const date = typeof ts.toDate === 'function' ? ts.toDate() : new Date(ts);
    return date.toLocaleDateString('tr-TR', {
      day: '2-digit',
      month: '2-digit',
      year: 'numeric',
    });
  } catch {
    return '—';
  }
}

export function AdminsPage() {
  const [admins, setAdmins] = useState<ApprovedAdmin[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [removeTarget, setRemoveTarget] = useState<ApprovedAdmin | null>(null);
  const [removing, setRemoving] = useState(false);

  // Form
  const [newEmail, setNewEmail] = useState('');
  const [newDisplayName, setNewDisplayName] = useState('');
  const [adding, setAdding] = useState(false);
  const [addError, setAddError] = useState<string | null>(null);
  const [addSuccess, setAddSuccess] = useState(false);

  useEffect(() => {
    load();
  }, []);

  const load = async () => {
    setLoading(true);
    try {
      const data = await getApprovedAdmins();
      setAdmins(data);
    } catch {
      setError('Adminler yüklenirken hata oluştu.');
    } finally {
      setLoading(false);
    }
  };

  const handleAdd = async (e: FormEvent) => {
    e.preventDefault();
    setAddError(null);
    setAddSuccess(false);

    const email = newEmail.trim().toLowerCase();
    const displayName = newDisplayName.trim();

    if (!email) { setAddError('E-posta adresi gereklidir.'); return; }
    if (!email.includes('@')) { setAddError('Geçerli bir e-posta adresi girin.'); return; }
    if (!displayName) { setAddError('Ad gereklidir.'); return; }

    if (admins.some((a) => a.email === email)) {
      setAddError('Bu e-posta zaten admin listesinde mevcut.');
      return;
    }

    setAdding(true);
    try {
      await addApprovedAdmin(email, displayName);
      setAdmins((prev) => [...prev, { email, displayName, addedAt: new Date() }]);
      setNewEmail('');
      setNewDisplayName('');
      setAddSuccess(true);
      setTimeout(() => setAddSuccess(false), 3000);
    } catch (err: any) {
      console.error('Admin eklenemedi:', err);
      setAddError(`Admin eklenirken hata oluştu: ${err?.message || err?.code || 'Bilinmeyen hata'}`);
    } finally {
      setAdding(false);
    }
  };

  const handleRemove = async () => {
    if (!removeTarget) return;
    setRemoving(true);
    try {
      await removeApprovedAdmin(removeTarget.email);
      setAdmins((prev) => prev.filter((a) => a.email !== removeTarget.email));
      setRemoveTarget(null);
    } catch {
      alert('Admin kaldırılırken hata oluştu.');
    } finally {
      setRemoving(false);
    }
  };

  return (
    <PageLayout title="Admin Yönetimi">
      <div className="grid grid-cols-1 lg:grid-cols-3 gap-6">
        {/* Add Admin Form */}
        <div className="lg:col-span-1">
          <div className="bg-white dark:bg-gray-900 rounded-xl border border-gray-200 dark:border-gray-800 p-6">
            <div className="flex items-center gap-2 mb-5">
              <UserPlus size={20} className="text-red-600" />
              <h2 className="font-semibold text-gray-900 dark:text-white">Yeni Admin Ekle</h2>
            </div>

            <form onSubmit={handleAdd} className="space-y-4">
              <div>
                <label className="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-1">
                  E-posta Adresi
                </label>
                <input
                  type="email"
                  value={newEmail}
                  onChange={(e) => setNewEmail(e.target.value)}
                  placeholder="admin@ornek.com"
                  className="w-full px-3 py-2 border border-gray-200 dark:border-gray-700 rounded-lg bg-white dark:bg-gray-800 text-gray-900 dark:text-gray-100 text-sm focus:outline-none focus:ring-2 focus:ring-red-500 focus:border-transparent"
                  disabled={adding}
                />
              </div>

              <div>
                <label className="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-1">
                  Ad Soyad
                </label>
                <input
                  type="text"
                  value={newDisplayName}
                  onChange={(e) => setNewDisplayName(e.target.value)}
                  placeholder="Ahmet Yılmaz"
                  className="w-full px-3 py-2 border border-gray-200 dark:border-gray-700 rounded-lg bg-white dark:bg-gray-800 text-gray-900 dark:text-gray-100 text-sm focus:outline-none focus:ring-2 focus:ring-red-500 focus:border-transparent"
                  disabled={adding}
                />
              </div>

              {addError && (
                <div className="px-3 py-2 bg-red-50 border border-red-200 rounded-lg text-red-700 text-xs">
                  {addError}
                </div>
              )}

              {addSuccess && (
                <div className="px-3 py-2 bg-green-50 border border-green-200 rounded-lg text-green-700 text-xs">
                  Admin başarıyla eklendi!
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
                {adding ? 'Ekleniyor...' : 'Admin Ekle'}
              </button>
            </form>
          </div>
        </div>

        {/* Admins List */}
        <div className="lg:col-span-2">
          <div className="bg-white dark:bg-gray-900 rounded-xl border border-gray-200 dark:border-gray-800">
            <div className="px-6 py-4 border-b border-gray-100">
              <div className="flex items-center gap-2">
                <Shield size={18} className="text-red-600" />
                <h2 className="font-semibold text-gray-900 dark:text-white">Mevcut Adminler</h2>
                <span className="ml-auto text-xs text-gray-400 dark:text-gray-500">{admins.length} admin</span>
              </div>
            </div>

            {loading ? (
              <div className="p-6">
                <Spinner />
              </div>
            ) : error ? (
              <div className="p-6">
                <div className="text-red-600 bg-red-50 px-4 py-3 rounded-lg text-sm">{error}</div>
              </div>
            ) : admins.length === 0 ? (
              <div className="p-6">
                <EmptyState
                  title="Admin bulunamadı"
                  description="Henüz onaylı admin bulunmuyor."
                />
              </div>
            ) : (
              <div className="divide-y divide-gray-100 dark:divide-gray-800">
                {admins.map((admin) => (
                  <div key={admin.email} className="px-6 py-4 flex items-center justify-between hover:bg-gray-50 dark:hover:bg-gray-800/40 transition-colors">
                    <div className="flex items-center gap-3">
                      <div className="w-9 h-9 rounded-full bg-red-100 flex items-center justify-center">
                        <span className="text-red-700 text-sm font-semibold">
                          {(admin.displayName || admin.email).charAt(0).toUpperCase()}
                        </span>
                      </div>
                      <div>
                        <p className="text-sm font-medium text-gray-900 dark:text-white">{admin.displayName || '—'}</p>
                        <p className="text-xs text-gray-400 dark:text-gray-500">{admin.email}</p>
                        {admin.addedAt && (
                          <p className="text-xs text-gray-300">Eklenme: {formatDate(admin.addedAt)}</p>
                        )}
                      </div>
                    </div>

                    <button
                      onClick={() => setRemoveTarget(admin)}
                      className="p-2 text-red-500 hover:bg-red-50 rounded-lg transition-colors"
                      title="Kaldır"
                    >
                      <Trash2 size={16} />
                    </button>
                  </div>
                ))}
              </div>
            )}
          </div>
        </div>
      </div>

      <Modal
        isOpen={!!removeTarget}
        onClose={() => setRemoveTarget(null)}
        onConfirm={handleRemove}
        title="Admini Kaldır"
        confirmText={removing ? 'Kaldırılıyor...' : 'Evet, Kaldır'}
        confirmVariant="danger"
      >
        <p>
          <strong>{removeTarget?.displayName || removeTarget?.email}</strong> kullanıcısının admin
          yetkisini kaldırmak istediğinizden emin misiniz?
        </p>
      </Modal>
    </PageLayout>
  );
}
