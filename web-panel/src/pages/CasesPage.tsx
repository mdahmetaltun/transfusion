import { useEffect, useState, useMemo } from 'react';
import { Link } from 'react-router-dom';
import { Trash2, Eye } from 'lucide-react';
import { PageLayout } from '../components/layout/PageLayout';
import { Spinner } from '../components/ui/Spinner';
import { Badge } from '../components/ui/Badge';
import { Modal } from '../components/ui/Modal';
import { EmptyState } from '../components/ui/EmptyState';
import { DataTable } from '../components/tables/DataTable';
import { getCases, deleteCase, getUsers } from '../services/firestore.service';
import type { Case, CaseStatus } from '../types/case';
import type { UserModel } from '../types/user';
import type { ColumnDef } from '@tanstack/react-table';

type Filter = 'all' | CaseStatus;

function formatDate(ts: any): string {
  if (!ts) return '—';
  try {
    const date = typeof ts.toDate === 'function' ? ts.toDate() : new Date(ts);
    return date.toLocaleDateString('tr-TR', {
      day: '2-digit',
      month: '2-digit',
      year: 'numeric',
      hour: '2-digit',
      minute: '2-digit',
    });
  } catch {
    return '—';
  }
}

export function CasesPage() {
  const [cases, setCases] = useState<Case[]>([]);
  const [userMap, setUserMap] = useState<Record<string, UserModel>>({});
  const [filter, setFilter] = useState<Filter>('all');
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [deleteTarget, setDeleteTarget] = useState<Case | null>(null);
  const [deleting, setDeleting] = useState(false);

  useEffect(() => {
    load();
  }, []);

  const load = async () => {
    setLoading(true);
    try {
      const [data, users] = await Promise.all([getCases(), getUsers()]);
      setCases(data);
      const map: Record<string, UserModel> = {};
      users.forEach((u) => { map[u.id] = u; });
      setUserMap(map);
    } catch {
      setError('Vakalar yüklenirken hata oluştu.');
    } finally {
      setLoading(false);
    }
  };

  const filteredCases = cases.filter((c) => {
    if (filter === 'all') return true;
    return c.status === filter;
  });

  const handleDelete = async () => {
    if (!deleteTarget) return;
    setDeleting(true);
    try {
      await deleteCase(deleteTarget.id);
      setCases((prev) => prev.filter((c) => c.id !== deleteTarget.id));
      setDeleteTarget(null);
    } catch {
      alert('Vaka silinirken hata oluştu.');
    } finally {
      setDeleting(false);
    }
  };

  const columns: ColumnDef<Case, any>[] = useMemo(() => [
    {
      header: 'Vaka ID',
      accessorKey: 'id',
      cell: ({ getValue }) => (
        <span className="font-mono text-xs text-gray-500">{getValue<string>().slice(0, 8)}...</span>
      ),
    },
    {
      header: 'Lokasyon',
      accessorKey: 'location',
      cell: ({ getValue }) => getValue<string>() || '—',
    },
    {
      header: 'Durum',
      accessorKey: 'status',
      cell: ({ getValue }) => {
        const status = getValue<CaseStatus>();
        return (
          <Badge variant={status === 'ACTIVE' ? 'active' : 'closed'}>
            {status === 'ACTIVE' ? 'Aktif' : 'Kapalı'}
          </Badge>
        );
      },
    },
    {
      header: 'Oluşturan',
      accessorKey: 'createdByUid',
      cell: ({ getValue }) => {
        const uid = getValue<string>();
        const user = uid ? userMap[uid] : null;
        if (!user) return <span className="text-xs text-gray-400">—</span>;
        return (
          <div>
            <p className="text-sm font-medium text-gray-900 dark:text-white">{user.displayName}</p>
            <p className="text-xs text-gray-400">{user.facilityId}</p>
          </div>
        );
      },
    },
    {
      header: 'Tarih',
      accessorKey: 'createdAt',
      cell: ({ getValue }) => (
        <span className="text-xs text-gray-500">{formatDate(getValue())}</span>
      ),
    },
    {
      header: 'İşlemler',
      id: 'actions',
      cell: ({ row }) => (
        <div className="flex items-center gap-2">
          <Link
            to={`/cases/${row.original.id}`}
            className="p-1.5 text-blue-600 hover:bg-blue-50 rounded-lg transition-colors"
            title="Görüntüle"
          >
            <Eye size={16} />
          </Link>
          <button
            onClick={() => setDeleteTarget(row.original)}
            className="p-1.5 text-red-600 hover:bg-red-50 rounded-lg transition-colors"
            title="Sil"
          >
            <Trash2 size={16} />
          </button>
        </div>
      ),
    },
  // eslint-disable-next-line react-hooks/exhaustive-deps
  ], [userMap]);

  return (
    <PageLayout title="Vakalar">
      {/* Filter buttons */}
      <div className="flex gap-2 mb-6">
        {(['all', 'ACTIVE', 'CLOSED'] as const).map((f) => (
          <button
            key={f}
            onClick={() => setFilter(f)}
            className={`px-4 py-2 rounded-lg text-sm font-medium transition-colors ${
              filter === f
                ? 'bg-red-600 text-white'
                : 'bg-white text-gray-600 border border-gray-200 hover:bg-gray-50'
            }`}
          >
            {f === 'all' ? 'Tümü' : f === 'ACTIVE' ? 'Aktif' : 'Kapalı'}
            <span className={`ml-2 text-xs px-1.5 py-0.5 rounded-full ${
              filter === f ? 'bg-red-500' : 'bg-gray-100 text-gray-500'
            }`}>
              {f === 'all' ? cases.length : cases.filter((c) => c.status === f).length}
            </span>
          </button>
        ))}
      </div>

      {loading ? (
        <Spinner />
      ) : error ? (
        <div className="text-red-600 bg-red-50 px-4 py-3 rounded-lg">{error}</div>
      ) : filteredCases.length === 0 ? (
        <EmptyState
          title="Vaka bulunamadı"
          description="Seçilen filtreye uygun vaka yok."
        />
      ) : (
        <div className="bg-white dark:bg-gray-900 rounded-xl border border-gray-200 dark:border-gray-800 p-4">
          <DataTable columns={columns} data={filteredCases} />
        </div>
      )}

      <Modal
        isOpen={!!deleteTarget}
        onClose={() => setDeleteTarget(null)}
        onConfirm={handleDelete}
        title="Vakayı Sil"
        confirmText={deleting ? 'Siliniyor...' : 'Evet, Sil'}
        confirmVariant="danger"
      >
        <p>
          <strong>{deleteTarget?.id.slice(0, 8)}...</strong> ID'li vakayı silmek istediğinizden
          emin misiniz? Bu işlem geri alınamaz.
        </p>
      </Modal>
    </PageLayout>
  );
}
