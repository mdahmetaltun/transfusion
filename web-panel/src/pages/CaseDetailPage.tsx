import { useEffect, useState } from 'react';
import { useParams, useNavigate } from 'react-router-dom';
import {
  ArrowLeft, Trash2, MapPin, Calendar, User, FileText,
  FilePlus, AlertTriangle, Droplets, HeartPulse, Activity,
  ClipboardCheck, Bell, FlaskConical, XCircle, Minus,
} from 'lucide-react';
import { PageLayout } from '../components/layout/PageLayout';
import { Spinner } from '../components/ui/Spinner';
import { Badge } from '../components/ui/Badge';
import { Modal } from '../components/ui/Modal';
import { EmptyState } from '../components/ui/EmptyState';
import {
  getCase, getCaseEvents, getCaseBloodProducts, getCaseLethalTriad, deleteCase,
} from '../services/firestore.service';
import { useAuth } from '../context/AuthContext';
import type { Case } from '../types/case';
import type { Event } from '../types/event';
import type { BloodProductUnit } from '../types/bloodProduct';

type Tab = 'events' | 'blood' | 'triad';

function formatDate(ts: any): string {
  if (!ts) return '—';
  try {
    const date = typeof ts.toDate === 'function' ? ts.toDate() : new Date(ts);
    return date.toLocaleDateString('tr-TR', {
      day: '2-digit', month: '2-digit', year: 'numeric',
      hour: '2-digit', minute: '2-digit',
    });
  } catch { return '—'; }
}

// ─── Event config ─────────────────────────────────────────────────────────────
const EVENT_CONFIG: Record<string, { label: string; dot: string; iconBg: string; icon: React.ReactNode }> = {
  caseCreated:        { label: 'Vaka Oluşturuldu',          dot: 'bg-blue-500',    iconBg: 'bg-blue-100 dark:bg-blue-900/40 text-blue-600 dark:text-blue-400',    icon: <FilePlus size={13} /> },
  triageUpdated:      { label: 'Triyaj Güncellendi',        dot: 'bg-amber-500',   iconBg: 'bg-amber-100 dark:bg-amber-900/40 text-amber-600 dark:text-amber-400', icon: <HeartPulse size={13} /> },
  gestaltRecorded:    { label: 'Klinik Karar Kaydedildi',   dot: 'bg-violet-500',  iconBg: 'bg-violet-100 dark:bg-violet-900/40 text-violet-600 dark:text-violet-400', icon: <ClipboardCheck size={13} /> },
  mtpActivated:       { label: 'MTP Aktive Edildi',         dot: 'bg-red-500',     iconBg: 'bg-red-100 dark:bg-red-900/40 text-red-600 dark:text-red-400',        icon: <AlertTriangle size={13} /> },
  mtpNotActivated:    { label: 'MTP Aktive Edilmedi',       dot: 'bg-gray-400',    iconBg: 'bg-gray-100 dark:bg-gray-800 text-gray-500 dark:text-gray-400',        icon: <Minus size={13} /> },
  productAdded:       { label: 'Kan Ürünü Eklendi',         dot: 'bg-emerald-500', iconBg: 'bg-emerald-100 dark:bg-emerald-900/40 text-emerald-600 dark:text-emerald-400', icon: <Droplets size={13} /> },
  productRemoved:     { label: 'Kan Ürünü Çıkarıldı',       dot: 'bg-orange-500',  iconBg: 'bg-orange-100 dark:bg-orange-900/40 text-orange-600 dark:text-orange-400', icon: <Droplets size={13} /> },
  ratioStatusUpdated: { label: 'Oran Güncellendi',          dot: 'bg-sky-500',     iconBg: 'bg-sky-100 dark:bg-sky-900/40 text-sky-600 dark:text-sky-400',        icon: <Activity size={13} /> },
  alertFired:         { label: 'Uyarı Tetiklendi',          dot: 'bg-orange-500',  iconBg: 'bg-orange-100 dark:bg-orange-900/40 text-orange-600 dark:text-orange-400', icon: <Bell size={13} /> },
  pocResultRecorded:  { label: 'POC Sonucu Kaydedildi',     dot: 'bg-cyan-500',    iconBg: 'bg-cyan-100 dark:bg-cyan-900/40 text-cyan-600 dark:text-cyan-400',    icon: <FlaskConical size={13} /> },
  caseClosed:         { label: 'Vaka Kapatıldı',            dot: 'bg-slate-500',   iconBg: 'bg-slate-100 dark:bg-slate-800 text-slate-600 dark:text-slate-400',   icon: <XCircle size={13} /> },
  note:               { label: 'Not',                       dot: 'bg-gray-400',    iconBg: 'bg-gray-100 dark:bg-gray-800 text-gray-500 dark:text-gray-400',        icon: <FileText size={13} /> },
};

const DEFAULT_EVENT = { label: '', dot: 'bg-gray-400', iconBg: 'bg-gray-100 dark:bg-gray-800 text-gray-500', icon: <Activity size={13} /> };

function renderPayload(type: string, payload: Record<string, any>): string | null {
  if (!payload || Object.keys(payload).length === 0) return null;
  switch (type) {
    case 'caseCreated':
      return `Lokasyon: ${payload.location ?? '—'}  ·  Mekanizma: ${payload.mechanism ?? '—'}  ·  Travma: ${payload.isTrauma ? 'Evet' : 'Hayır'}`;
    case 'triageUpdated':
      return [
        payload.hr != null ? `KH: ${payload.hr}/dk` : null,
        payload.sbp != null ? `SKB: ${payload.sbp} mmHg` : null,
        payload.isFastPositive != null ? `FAST: ${payload.isFastPositive ? 'Pozitif' : 'Negatif'}` : null,
        payload.riskLevel ? `Risk: ${payload.riskLevel}` : null,
      ].filter(Boolean).join('  ·  ');
    case 'gestaltRecorded':  return `Karar: ${payload.decision ?? '—'}`;
    case 'productAdded':     return `+${payload.amount ?? 1} × ${payload.productType ?? '—'}`;
    case 'productRemoved':   return `−${payload.amount ?? 1} × ${payload.productType ?? '—'}`;
    case 'alertFired':       return `[${payload.severity ?? 'UYARI'}]  ${payload.message ?? payload.alertId ?? '—'}`;
    case 'pocResultRecorded':
      return [
        payload.extemCa5 != null ? `EXTEM CA5: ${payload.extemCa5}` : null,
        payload.ptInr != null ? `INR: ${payload.ptInr}` : null,
      ].filter(Boolean).join('  ·  ') || null;
    default: return null;
  }
}

const PRODUCT_STATUS_LABELS: Record<string, string> = {
  registered: 'Kayıt Edildi', received: 'Teslim Alındı',
  administered: 'Verildi', returned: 'İade Edildi', wasted: 'İsraf',
};

export function CaseDetailPage() {
  const { caseId } = useParams<{ caseId: string }>();
  const navigate = useNavigate();
  const { isSuperAdmin } = useAuth();

  const [caseData, setCaseData] = useState<Case | null>(null);
  const [events, setEvents] = useState<Event[]>([]);
  const [bloodProducts, setBloodProducts] = useState<BloodProductUnit[]>([]);
  const [lethalTriad, setLethalTriad] = useState<any[]>([]);
  const [activeTab, setActiveTab] = useState<Tab>('events');
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [showDeleteModal, setShowDeleteModal] = useState(false);
  const [deleting, setDeleting] = useState(false);

  useEffect(() => {
    if (!caseId) return;
    const load = async () => {
      try {
        const c = await getCase(caseId);
        if (!c) { setError('Vaka bulunamadı.'); setLoading(false); return; }
        setCaseData(c);
      } catch {
        setError('Vaka yüklenirken hata oluştu.'); setLoading(false); return;
      }
      setLoading(false);
      getCaseEvents(caseId).then(setEvents).catch(() => setEvents([]));
      getCaseBloodProducts(caseId).then(setBloodProducts).catch(() => setBloodProducts([]));
      getCaseLethalTriad(caseId).then(setLethalTriad).catch(() => setLethalTriad([]));
    };
    load();
  }, [caseId]);

  const handleDelete = async () => {
    if (!caseId) return;
    setDeleting(true);
    try { await deleteCase(caseId); navigate('/cases'); }
    catch { alert('Vaka silinirken hata oluştu.'); setDeleting(false); }
  };

  if (loading) return <PageLayout title="Vaka Detayı"><Spinner /></PageLayout>;
  if (error || !caseData) {
    return (
      <PageLayout title="Vaka Detayı">
        <div className="px-4 py-3 bg-red-50 dark:bg-red-900/20 border border-red-200 dark:border-red-800 rounded-xl text-red-700 dark:text-red-400 text-sm">
          {error || 'Vaka bulunamadı.'}
        </div>
      </PageLayout>
    );
  }

  const abc = caseData.abcSummary;
  const abcScore = abc?.score ?? 0;
  const isHighRisk = abcScore >= 2;

  const infoItems = [
    { icon: <MapPin size={16} />, label: 'Lokasyon', value: caseData.location || '—', color: 'text-blue-500' },
    { icon: <Calendar size={16} />, label: 'Açılış', value: formatDate(caseData.createdAt), color: 'text-violet-500' },
    ...(caseData.closedAt ? [{ icon: <Calendar size={16} />, label: 'Kapanış', value: formatDate(caseData.closedAt), color: 'text-slate-500' }] : []),
    { icon: <User size={16} />, label: 'Oluşturan', value: caseData.createdByUid || '—', color: 'text-amber-500', mono: true },
  ];

  const tabs = [
    { id: 'events' as Tab, label: 'Olaylar', count: events.length },
    { id: 'blood' as Tab, label: 'Kan Ürünleri', count: bloodProducts.length },
    { id: 'triad' as Tab, label: 'Ölümcül Triad', count: lethalTriad.length },
  ];

  return (
    <PageLayout title="Vaka Detayı">
      {/* Header row */}
      <div className="flex items-center justify-between mb-6">
        <button
          onClick={() => navigate(-1)}
          className="flex items-center gap-2 text-gray-500 dark:text-gray-400 hover:text-gray-900 dark:hover:text-white transition-colors text-sm font-medium"
        >
          <ArrowLeft size={16} /> Geri
        </button>
        {isSuperAdmin && (
          <button
            onClick={() => setShowDeleteModal(true)}
            className="flex items-center gap-2 px-4 py-2 bg-red-600 hover:bg-red-700 text-white text-sm font-medium rounded-xl transition-colors"
          >
            <Trash2 size={15} /> Vakayı Sil
          </button>
        )}
      </div>

      <div className="grid grid-cols-1 lg:grid-cols-3 gap-5 mb-5">
        {/* Main Info Card */}
        <div className="lg:col-span-2 bg-white dark:bg-gray-900 rounded-2xl border border-gray-200 dark:border-gray-800 p-6">
          <div className="flex items-start justify-between mb-5">
            <div>
              <h2 className="text-base font-semibold text-gray-900 dark:text-white mb-1">Vaka Bilgileri</h2>
              <p className="font-mono text-xs text-gray-400 dark:text-gray-500">{caseData.id}</p>
            </div>
            <Badge variant={caseData.status === 'ACTIVE' ? 'active' : 'closed'}>
              {caseData.status === 'ACTIVE' ? 'Aktif' : 'Kapalı'}
            </Badge>
          </div>

          <div className="grid grid-cols-1 sm:grid-cols-2 gap-3">
            {infoItems.map((item) => (
              <div key={item.label} className="flex items-center gap-3 p-3.5 bg-gray-50 dark:bg-gray-800/60 rounded-xl">
                <div className={`w-8 h-8 rounded-lg bg-white dark:bg-gray-700 flex items-center justify-center flex-shrink-0 shadow-sm ${item.color}`}>
                  {item.icon}
                </div>
                <div className="min-w-0">
                  <p className="text-xs text-gray-400 dark:text-gray-500">{item.label}</p>
                  <p className={`text-sm font-medium text-gray-900 dark:text-gray-100 truncate ${item.mono ? 'font-mono text-xs' : ''}`}>
                    {item.value}
                  </p>
                </div>
              </div>
            ))}
          </div>

          {/* Patient info */}
          {(abc?.patientWeightKg || abc?.patientBloodGroup) && (
            <div className="mt-4 pt-4 border-t border-gray-100 dark:border-gray-800 flex gap-4 flex-wrap">
              {abc?.patientWeightKg && (
                <div className="text-sm">
                  <span className="text-gray-400 dark:text-gray-500">Ağırlık </span>
                  <span className="font-semibold text-gray-800 dark:text-gray-200">{abc.patientWeightKg} kg</span>
                </div>
              )}
              {abc?.patientBloodGroup && (
                <div className="text-sm">
                  <span className="text-gray-400 dark:text-gray-500">Kan Grubu </span>
                  <span className="font-semibold text-gray-800 dark:text-gray-200">
                    {abc.patientBloodGroup}{abc.patientRhFactor === 'positive' ? ' Rh+' : abc.patientRhFactor === 'negative' ? ' Rh−' : ''}
                  </span>
                </div>
              )}
            </div>
          )}

          {/* Notes */}
          {caseData.notes && (
            <div className="mt-4 pt-4 border-t border-gray-100 dark:border-gray-800">
              <p className="text-xs font-semibold text-gray-400 dark:text-gray-500 uppercase tracking-wider mb-2">Notlar</p>
              <p className="text-sm text-gray-700 dark:text-gray-300 bg-gray-50 dark:bg-gray-800/60 p-3 rounded-xl leading-relaxed">
                {caseData.notes}
              </p>
            </div>
          )}
        </div>

        {/* ABC Score Card */}
        <div className={`rounded-2xl p-6 ${isHighRisk
          ? 'bg-gradient-to-br from-red-500 to-rose-600 text-white shadow-lg shadow-red-500/20'
          : 'bg-gradient-to-br from-emerald-500 to-emerald-600 text-white shadow-lg shadow-emerald-500/20'
        }`}>
          <div className="flex items-center justify-between mb-4">
            <h2 className="text-sm font-semibold text-white/90">ABC Skoru</h2>
            <div className="px-2.5 py-1 bg-white/20 rounded-full text-xs font-medium">
              {isHighRisk ? 'Yüksek Risk' : 'Düşük Risk'}
            </div>
          </div>

          {abc ? (
            <>
              {/* Score circle */}
              <div className="flex items-center justify-center my-5">
                <div className="w-24 h-24 rounded-full bg-white/20 border-4 border-white/30 flex items-center justify-center">
                  <span className="text-5xl font-bold">{abc.score ?? '—'}</span>
                </div>
              </div>
              <p className="text-center text-white/70 text-xs mb-5">
                {isHighRisk ? '≥2 puan — MTP endikasyonu' : '<2 puan — Düşük olasılık'}
              </p>

              <div className="space-y-2">
                {[
                  { label: 'Kalp Hızı', value: abc.heartRate ? `${abc.heartRate} /dk` : null, warn: (abc.heartRate ?? 0) >= 120 },
                  { label: 'Sistolik KB', value: abc.systolicBp ? `${abc.systolicBp} mmHg` : null, warn: (abc.systolicBp ?? 999) <= 90 },
                  { label: 'FAST', value: abc.isFastPositive !== undefined ? (abc.isFastPositive ? 'Pozitif' : 'Negatif') : null, warn: abc.isFastPositive === true },
                  { label: 'Mekanizma', value: abc.mechanism ?? null, warn: false },
                ].filter(r => r.value !== null).map((row) => (
                  <div key={row.label} className="flex items-center justify-between py-1.5 border-b border-white/10 last:border-0">
                    <span className="text-white/70 text-xs">{row.label}</span>
                    <span className={`text-xs font-semibold px-2 py-0.5 rounded-full ${row.warn ? 'bg-white/30 text-white' : 'bg-white/10 text-white/80'}`}>
                      {row.value}
                    </span>
                  </div>
                ))}
              </div>
            </>
          ) : (
            <div className="flex flex-col items-center justify-center py-10 text-white/50">
              <Activity size={32} className="mb-3 opacity-50" />
              <p className="text-sm">ABC skoru mevcut değil</p>
              <p className="text-xs mt-1 opacity-70">Vaka kapatıldığında hesaplanır</p>
            </div>
          )}
        </div>
      </div>

      {/* Tabs Section */}
      <div className="bg-white dark:bg-gray-900 rounded-2xl border border-gray-200 dark:border-gray-800">
        <div className="border-b border-gray-100 dark:border-gray-800 px-2">
          <div className="flex gap-1">
            {tabs.map((tab) => (
              <button
                key={tab.id}
                onClick={() => setActiveTab(tab.id)}
                className={`flex items-center gap-2 px-4 py-4 text-sm font-medium border-b-2 transition-all ${
                  activeTab === tab.id
                    ? 'border-red-500 text-red-600 dark:text-red-400'
                    : 'border-transparent text-gray-500 dark:text-gray-400 hover:text-gray-700 dark:hover:text-gray-200'
                }`}
              >
                {tab.label}
                <span className={`px-1.5 py-0.5 rounded-full text-xs font-semibold ${
                  activeTab === tab.id
                    ? 'bg-red-100 dark:bg-red-900/40 text-red-600 dark:text-red-400'
                    : 'bg-gray-100 dark:bg-gray-800 text-gray-500 dark:text-gray-400'
                }`}>
                  {tab.count}
                </span>
              </button>
            ))}
          </div>
        </div>

        <div className="p-6">
          {/* ── Events Tab ─────────────────────────────────────── */}
          {activeTab === 'events' && (
            events.length === 0
              ? <EmptyState title="Olay bulunamadı" description="Bu vaka için kayıtlı olay yok." />
              : (
                <div className="space-y-1">
                  {events.map((evt, idx) => {
                    const cfg = EVENT_CONFIG[evt.type] ?? { ...DEFAULT_EVENT, label: evt.type };
                    const summary = evt.payload ? renderPayload(evt.type, evt.payload) : null;
                    return (
                      <div key={evt.id} className="flex gap-4">
                        {/* Timeline line */}
                        <div className="flex flex-col items-center pt-2.5">
                          <div className={`w-2.5 h-2.5 rounded-full flex-shrink-0 ${cfg.dot}`} />
                          {idx < events.length - 1 && (
                            <div className="w-px flex-1 bg-gray-200 dark:bg-gray-700 mt-1.5 mb-0.5" />
                          )}
                        </div>
                        {/* Content */}
                        <div className={`flex-1 mb-3 p-3.5 rounded-xl border ${
                          activeTab === 'events'
                            ? 'bg-gray-50 dark:bg-gray-800/40 border-gray-100 dark:border-gray-800'
                            : ''
                        }`}>
                          <div className="flex items-center gap-2 flex-wrap">
                            <div className={`w-6 h-6 rounded-lg flex items-center justify-center flex-shrink-0 ${cfg.iconBg}`}>
                              {cfg.icon}
                            </div>
                            <span className="text-sm font-semibold text-gray-900 dark:text-gray-100">
                              {cfg.label || evt.type}
                            </span>
                            <span className="text-xs text-gray-400 dark:text-gray-500 ml-auto">
                              {formatDate(evt.timestamp)}
                            </span>
                          </div>
                          {summary && (
                            <p className="text-xs text-gray-500 dark:text-gray-400 mt-2 ml-8 leading-relaxed">
                              {summary}
                            </p>
                          )}
                        </div>
                      </div>
                    );
                  })}
                </div>
              )
          )}

          {/* ── Blood Products Tab ─────────────────────────────── */}
          {activeTab === 'blood' && (
            bloodProducts.length === 0
              ? <EmptyState title="Kan ürünü bulunamadı" description="Bu vaka için kayıtlı kan ürünü yok." />
              : (
                <div className="overflow-x-auto">
                  <table className="w-full text-sm">
                    <thead className="bg-gray-50 dark:bg-gray-800/60">
                      <tr>
                        {['Tür', 'Barkod', 'Kan Grubu', 'Durum', 'Kayıt Tarihi', 'Verilme Tarihi', 'Notlar'].map((h) => (
                          <th key={h} className="px-4 py-3 text-left text-xs font-semibold text-gray-500 dark:text-gray-400 uppercase tracking-wider">
                            {h}
                          </th>
                        ))}
                      </tr>
                    </thead>
                    <tbody className="divide-y divide-gray-100 dark:divide-gray-800">
                      {bloodProducts.map((bp) => (
                        <tr key={bp.id} className="hover:bg-gray-50 dark:hover:bg-gray-800/40 transition-colors">
                          <td className="px-4 py-3">
                            <span className="font-bold text-red-600 dark:text-red-400 bg-red-50 dark:bg-red-900/20 px-2.5 py-1 rounded-lg text-xs">
                              {bp.productType}
                            </span>
                          </td>
                          <td className="px-4 py-3 font-mono text-xs text-gray-400 dark:text-gray-500">{bp.barcode || '—'}</td>
                          <td className="px-4 py-3 text-xs text-gray-700 dark:text-gray-300">
                            {bp.bloodGroup
                              ? `${bp.bloodGroup}${bp.rhFactor === 'positive' ? ' Rh+' : bp.rhFactor === 'negative' ? ' Rh−' : ''}`
                              : '—'}
                          </td>
                          <td className="px-4 py-3">
                            <Badge variant={bp.status}>{PRODUCT_STATUS_LABELS[bp.status] || bp.status}</Badge>
                          </td>
                          <td className="px-4 py-3 text-xs text-gray-500 dark:text-gray-400">{formatDate(bp.registeredAt)}</td>
                          <td className="px-4 py-3 text-xs text-gray-500 dark:text-gray-400">{formatDate(bp.administeredAt)}</td>
                          <td className="px-4 py-3 text-xs text-gray-500 dark:text-gray-400">{bp.notes || '—'}</td>
                        </tr>
                      ))}
                    </tbody>
                  </table>
                </div>
              )
          )}

          {/* ── Lethal Triad Tab ───────────────────────────────── */}
          {activeTab === 'triad' && (
            lethalTriad.length === 0
              ? <EmptyState title="Ölümcül triad verisi bulunamadı" description="Bu vaka için kayıtlı ölümcül triad ölçümü yok." />
              : (
                <div className="overflow-x-auto">
                  <table className="w-full text-sm">
                    <thead className="bg-gray-50 dark:bg-gray-800/60">
                      <tr>
                        {['Zaman', 'pH', 'Sıcaklık (°C)', 'INR', 'Laktat'].map((h) => (
                          <th key={h} className="px-4 py-3 text-left text-xs font-semibold text-gray-500 dark:text-gray-400 uppercase tracking-wider">
                            {h}
                          </th>
                        ))}
                      </tr>
                    </thead>
                    <tbody className="divide-y divide-gray-100 dark:divide-gray-800">
                      {lethalTriad.map((row) => (
                        <tr key={row.id} className="hover:bg-gray-50 dark:hover:bg-gray-800/40 transition-colors">
                          <td className="px-4 py-3 text-xs text-gray-400 dark:text-gray-500">{formatDate(row.recordedAt)}</td>
                          {[
                            { val: row.ph,          warn: row.ph < 7.35 },
                            { val: row.temperature, warn: row.temperature < 35 },
                            { val: row.inr,         warn: row.inr > 1.5 },
                            { val: row.lactate,     warn: row.lactate > 2 },
                          ].map(({ val, warn }, i) => (
                            <td key={i} className="px-4 py-3">
                              <span className={`text-sm font-semibold px-2 py-0.5 rounded-lg ${
                                warn
                                  ? 'text-red-600 dark:text-red-400 bg-red-50 dark:bg-red-900/20'
                                  : 'text-gray-700 dark:text-gray-300'
                              }`}>
                                {val ?? '—'}
                              </span>
                            </td>
                          ))}
                        </tr>
                      ))}
                    </tbody>
                  </table>
                </div>
              )
          )}
        </div>
      </div>

      <Modal
        isOpen={showDeleteModal}
        onClose={() => setShowDeleteModal(false)}
        onConfirm={handleDelete}
        title="Vakayı Sil"
        confirmText={deleting ? 'Siliniyor...' : 'Evet, Sil'}
        confirmVariant="danger"
      >
        <p className="text-gray-600 dark:text-gray-300">
          Bu vakayı silmek istediğinizden emin misiniz?{' '}
          <strong className="text-gray-900 dark:text-white">Bu işlem geri alınamaz.</strong>
        </p>
      </Modal>
    </PageLayout>
  );
}
