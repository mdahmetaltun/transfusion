import React from 'react';
import { NavLink } from 'react-router-dom';
import { LayoutDashboard, ClipboardList, Users, Shield } from 'lucide-react';
import { useAuth } from '../../context/AuthContext';

interface NavItem {
  label: string;
  path: string;
  icon: React.ReactNode;
  iconBg: string;
  superAdminOnly?: boolean;
}

const navItems: NavItem[] = [
  {
    label: 'Dashboard',
    path: '/',
    icon: <LayoutDashboard size={16} />,
    iconBg: 'bg-blue-500/20 text-blue-400',
  },
  {
    label: 'Vakalar',
    path: '/cases',
    icon: <ClipboardList size={16} />,
    iconBg: 'bg-amber-500/20 text-amber-400',
  },
  {
    label: 'Kullanıcılar',
    path: '/users',
    icon: <Users size={16} />,
    iconBg: 'bg-violet-500/20 text-violet-400',
  },
  {
    label: 'Adminler',
    path: '/admins',
    icon: <Shield size={16} />,
    iconBg: 'bg-rose-500/20 text-rose-400',
    superAdminOnly: true,
  },
];

export function Sidebar() {
  const { isSuperAdmin } = useAuth();

  return (
    <aside className="w-60 bg-slate-950 flex flex-col h-screen sticky top-0 border-r border-slate-800/60">
      {/* Logo */}
      <div className="px-5 py-5 border-b border-slate-800/60">
        <div className="flex items-center gap-3">
          <div className="w-9 h-9 bg-gradient-to-br from-red-500 to-red-700 rounded-xl flex items-center justify-center shadow-lg shadow-red-900/40 flex-shrink-0">
            <span className="text-white font-bold text-xs tracking-widest">MTP</span>
          </div>
          <div>
            <p className="font-semibold text-white text-sm leading-tight">Admin Panel</p>
            <p className="text-xs text-slate-500 leading-tight mt-0.5">Massive Transfusion</p>
          </div>
        </div>
      </div>

      {/* Navigation */}
      <nav className="flex-1 px-3 py-4 space-y-0.5 overflow-y-auto">
        <p className="text-xs font-semibold text-slate-600 uppercase tracking-widest px-3 mb-2">Menü</p>
        {navItems
          .filter((item) => !item.superAdminOnly || isSuperAdmin)
          .map((item) => (
            <NavLink
              key={item.path}
              to={item.path}
              end={item.path === '/'}
              className={({ isActive }) =>
                `flex items-center gap-3 px-3 py-2.5 rounded-xl text-sm font-medium transition-all duration-150 ${
                  isActive
                    ? 'bg-white/10 text-white shadow-sm'
                    : 'text-slate-400 hover:bg-white/5 hover:text-slate-200'
                }`
              }
            >
              {({ isActive }) => (
                <>
                  <div
                    className={`w-7 h-7 rounded-lg flex items-center justify-center flex-shrink-0 transition-all ${
                      isActive ? item.iconBg + ' opacity-100' : item.iconBg + ' opacity-70'
                    }`}
                  >
                    {item.icon}
                  </div>
                  {item.label}
                </>
              )}
            </NavLink>
          ))}
      </nav>

      {/* Footer */}
      <div className="px-5 py-4 border-t border-slate-800/60">
        <div className="flex items-center gap-2">
          <div className="w-1.5 h-1.5 rounded-full bg-emerald-500 animate-pulse" />
          <p className="text-xs text-slate-600">v1.0.0 · Çevrimiçi</p>
        </div>
      </div>
    </aside>
  );
}
