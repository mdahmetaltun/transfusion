import { Sun, Moon, LogOut } from 'lucide-react';
import { useAuth } from '../../context/AuthContext';
import { useTheme } from '../../context/ThemeContext';
import { signOut } from '../../services/auth.service';

interface HeaderProps {
  title: string;
}

export function Header({ title }: HeaderProps) {
  const { currentUser } = useAuth();
  const { theme, toggleTheme } = useTheme();

  return (
    <header className="bg-white dark:bg-gray-900 border-b border-gray-200 dark:border-gray-800 px-6 py-3.5 flex items-center justify-between sticky top-0 z-10">
      <h1 className="text-lg font-semibold text-gray-900 dark:text-white">{title}</h1>

      <div className="flex items-center gap-2">
        {/* Theme toggle */}
        <button
          onClick={toggleTheme}
          className="w-9 h-9 flex items-center justify-center rounded-xl text-gray-500 dark:text-gray-400 hover:bg-gray-100 dark:hover:bg-gray-800 transition-colors"
          title={theme === 'dark' ? 'Açık mod' : 'Koyu mod'}
        >
          {theme === 'dark' ? <Sun size={17} /> : <Moon size={17} />}
        </button>

        {/* Divider */}
        <div className="w-px h-5 bg-gray-200 dark:bg-gray-700 mx-1" />

        {/* User info */}
        <div className="flex items-center gap-2.5">
          {currentUser?.photoURL ? (
            <img
              src={currentUser.photoURL}
              alt={currentUser.displayName || ''}
              className="w-8 h-8 rounded-full object-cover ring-2 ring-gray-200 dark:ring-gray-700"
            />
          ) : (
            <div className="w-8 h-8 rounded-full bg-gradient-to-br from-red-400 to-red-600 flex items-center justify-center ring-2 ring-gray-200 dark:ring-gray-700">
              <span className="text-white text-sm font-semibold">
                {(currentUser?.displayName || currentUser?.email || 'A').charAt(0).toUpperCase()}
              </span>
            </div>
          )}
          <div className="hidden sm:block">
            <p className="text-sm font-medium text-gray-900 dark:text-gray-100 leading-tight">
              {currentUser?.displayName || currentUser?.email}
            </p>
            {currentUser?.displayName && (
              <p className="text-xs text-gray-400 dark:text-gray-500 leading-tight">{currentUser.email}</p>
            )}
          </div>
        </div>

        {/* Sign out */}
        <button
          onClick={() => signOut()}
          className="w-9 h-9 flex items-center justify-center rounded-xl text-gray-400 dark:text-gray-500 hover:text-red-500 hover:bg-red-50 dark:hover:bg-red-900/20 transition-colors ml-1"
          title="Çıkış Yap"
        >
          <LogOut size={17} />
        </button>
      </div>
    </header>
  );
}
