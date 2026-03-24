import { ShieldX } from 'lucide-react';
import { signOut } from '../services/auth.service';

export function AccessDeniedPage() {
  const handleSignOut = async () => {
    await signOut();
  };

  return (
    <div className="min-h-screen bg-gray-50 flex items-center justify-center p-4">
      <div className="bg-white rounded-2xl shadow-xl w-full max-w-md p-8 text-center">
        <div className="flex justify-center mb-6">
          <div className="w-16 h-16 bg-red-100 rounded-2xl flex items-center justify-center">
            <ShieldX size={32} className="text-red-600" />
          </div>
        </div>

        <h1 className="text-2xl font-bold text-gray-900 mb-3">Erişim Reddedildi</h1>
        <p className="text-gray-500 text-sm mb-6">
          Bu panele erişmek için admin yetkisine sahip bir hesap kullanmanız gerekmektedir.
          Kullandığınız hesabın gerekli yetkilere sahip olmadığı görünüyor.
        </p>

        <div className="space-y-3">
          <button
            onClick={handleSignOut}
            className="w-full px-4 py-3 bg-red-600 hover:bg-red-700 text-white font-medium rounded-xl transition-colors"
          >
            Çıkış Yap ve Farklı Hesapla Dene
          </button>
          <p className="text-xs text-gray-400">
            Erişim talebi için sistem yöneticinizle iletişime geçin.
          </p>
        </div>
      </div>
    </div>
  );
}
