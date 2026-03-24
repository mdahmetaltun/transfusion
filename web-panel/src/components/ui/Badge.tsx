import React from 'react';

const variantClasses: Record<string, string> = {
  // Case status
  active: 'bg-emerald-100 text-emerald-700 dark:bg-emerald-900/30 dark:text-emerald-400',
  closed: 'bg-gray-100 text-gray-600 dark:bg-gray-800 dark:text-gray-400',
  // User roles
  DOCTOR: 'bg-blue-100 text-blue-700 dark:bg-blue-900/30 dark:text-blue-400',
  NURSE: 'bg-violet-100 text-violet-700 dark:bg-violet-900/30 dark:text-violet-400',
  BLOOD_BANK: 'bg-orange-100 text-orange-700 dark:bg-orange-900/30 dark:text-orange-400',
  ADMIN: 'bg-rose-100 text-rose-700 dark:bg-rose-900/30 dark:text-rose-400',
  // Blood product status
  registered: 'bg-sky-100 text-sky-700 dark:bg-sky-900/30 dark:text-sky-400',
  received: 'bg-blue-100 text-blue-700 dark:bg-blue-900/30 dark:text-blue-400',
  administered: 'bg-emerald-100 text-emerald-700 dark:bg-emerald-900/30 dark:text-emerald-400',
  returned: 'bg-amber-100 text-amber-700 dark:bg-amber-900/30 dark:text-amber-400',
  wasted: 'bg-red-100 text-red-700 dark:bg-red-900/30 dark:text-red-400',
};

const defaultClass = 'bg-gray-100 text-gray-600 dark:bg-gray-800 dark:text-gray-400';

interface BadgeProps {
  variant: string;
  children: React.ReactNode;
}

export function Badge({ variant, children }: BadgeProps) {
  const cls = variantClasses[variant] ?? defaultClass;
  return (
    <span className={`inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium ${cls}`}>
      {children}
    </span>
  );
}
