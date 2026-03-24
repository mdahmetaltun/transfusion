import { useEffect, useState } from 'react';
import { Link } from 'react-router-dom';
import { Activity, CheckCircle, XCircle, Users, ArrowRight } from 'lucide-react';
import { PageLayout } from '../components/layout/PageLayout';
import { Spinner } from '../components/ui/Spinner';
import { Badge } from '../components/ui/Badge';
import { getDashboardStats, getCases } from '../services/firestore.service';
import type { Case } from '../types/case';

interface Stats { total: number; active: number; closed: number; users: number; }

function formatDate(ts: any): string {
  if (!ts) return '—';
  try {
    const date = typeof ts.toDate === 'function' ? ts.toDate() : new Date(ts);
    return date.toLocaleDateString('tr-TR', { day: '2-digit', month: '2-digit', year: 'numeric', hour: '2-digit', minute: '2-digit' });
  } catch { return '—'; }
}

const statCards = [
  {
    key: 'total' as const,
    label: 'Toplam Vaka',
    sub: 'Tüm kayıtlar',
    icon: <Activity size={20} />,
    gradient: 'from-blue-500 to-blue-600',
    glow: 'shadow-blue-500/25',
  },
  {
    key: 'active' as const,
    label: 'Aktif Vaka',
    sub: 'Devam ediyor',
    icon: <CheckCircle size={20} />,
    gradient: 'from-emerald-500 to-emerald-600',
    glow: 'shadow-emerald-500/25',
  },
  {
    key: 'closed' as const,
    label: 'Kapalı Vaka',
    sub: 'Tamamlandı',
    icon: <XCircle size={20} />,
    gradient: 'from-slate-500 to-slate-600',
    glow: 'shadow-slate-500/20',
  },
  {
    key: 'users' as const,
    label: 'Kullanıcı',
    sub: 'Kayıtlı hesap',
    icon: <Users size={20} />,
    gradient: 'from-violet-500 to-violet-600',
    glow: 'shadow-violet-500/25',
  },
];

export function DashboardPage() {
  const [stats, setStats] = useState<Stats | null>(null);
  const [recentCases, setRecentCases] = useState<Case[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    const load = async () => {
      try {
        const [s, cases] = await Promise.all([getDashboardStats(), getCases()]);
        setStats(s);
        setRecentCases(cases.slice(0, 10));
      } catch (err) {
        setError('Veriler yüklenirken hata oluştu.');
        console.error(err);
      } finally {
        setLoading(false);
      }
    };
    load();
  }, []);

  if (loading) return <PageLayout title="Dashboard"><Spinner /></PageLayout>;

  if (error) {
    return (
      <PageLayout title="Dashboard">
        <div className="px-4 py-3 bg-red-50 dark:bg-red-900/20 border border-red-200 dark:border-red-800 rounded-xl text-red-700 dark:text-red-400 text-sm">{error}</div>
      </PageLayout>
    );
  }

  return (
    <PageLayout title="Dashboard">
      {/* Stat Cards */}
      <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-4 mb-6">
        {statCards.map((card) => (
          <div
            key={card.key}
            className={`bg-gradient-to-br ${card.gradient} rounded-2xl p-5 text-white shadow-lg ${card.glow}`}
          >
            <div className="flex items-start justify-between mb-4">
              <div className="p-2 bg-white/20 rounded-xl">
                {card.icon}
              </div>
              <span className="text-white/60 text-xs font-medium">{card.sub}</span>
            </div>
            <p className="text-4xl font-bold mb-0.5">{stats?.[card.key] ?? 0}</p>
            <p className="text-white/70 text-sm">{card.label}</p>
          </div>
        ))}
      </div>

      {/* Recent Cases */}
      <div className="bg-white dark:bg-gray-900 rounded-2xl border border-gray-200 dark:border-gray-800">
        <div className="px-6 py-4 border-b border-gray-100 dark:border-gray-800 flex items-center justify-between">
          <div>
            <h2 className="font-semibold text-gray-900 dark:text-white">Son Vakalar</h2>
            <p className="text-xs text-gray-400 dark:text-gray-500 mt-0.5">Son 10 kayıt</p>
          </div>
          <Link
            to="/cases"
            className="flex items-center gap-1.5 text-sm text-red-600 dark:text-red-400 hover:text-red-700 font-medium transition-colors"
          >
            Tümünü Gör <ArrowRight size={14} />
          </Link>
        </div>
        <div className="overflow-x-auto">
          <table className="w-full text-sm">
            <thead className="bg-gray-50 dark:bg-gray-800/50 border-b border-gray-100 dark:border-gray-800">
              <tr>
                {['ID', 'Lokasyon', 'Durum', 'Tarih', 'İşlem'].map((h) => (
                  <th key={h} className="px-6 py-3 text-left text-xs font-semibold text-gray-500 dark:text-gray-400 uppercase tracking-wider">
                    {h}
                  </th>
                ))}
              </tr>
            </thead>
            <tbody className="divide-y divide-gray-50 dark:divide-gray-800">
              {recentCases.length === 0 ? (
                <tr>
                  <td colSpan={5} className="px-6 py-10 text-center text-gray-400 dark:text-gray-500">
                    Henüz vaka bulunmuyor
                  </td>
                </tr>
              ) : (
                recentCases.map((c) => (
                  <tr key={c.id} className="hover:bg-gray-50 dark:hover:bg-gray-800/40 transition-colors">
                    <td className="px-6 py-3.5">
                      <span className="font-mono text-xs text-gray-400 dark:text-gray-500">{c.id.slice(0, 12)}…</span>
                    </td>
                    <td className="px-6 py-3.5 font-medium text-gray-800 dark:text-gray-200">
                      {c.location || '—'}
                    </td>
                    <td className="px-6 py-3.5">
                      <Badge variant={c.status === 'ACTIVE' ? 'active' : 'closed'}>
                        {c.status === 'ACTIVE' ? 'Aktif' : 'Kapalı'}
                      </Badge>
                    </td>
                    <td className="px-6 py-3.5 text-gray-500 dark:text-gray-400 text-xs">
                      {formatDate(c.createdAt)}
                    </td>
                    <td className="px-6 py-3.5">
                      <Link
                        to={`/cases/${c.id}`}
                        className="inline-flex items-center gap-1 text-xs font-medium text-red-600 dark:text-red-400 hover:text-red-700 transition-colors"
                      >
                        Görüntüle <ArrowRight size={11} />
                      </Link>
                    </td>
                  </tr>
                ))
              )}
            </tbody>
          </table>
        </div>
      </div>
    </PageLayout>
  );
}
