import { initializeApp } from 'firebase/app';
import { getAuth } from 'firebase/auth';
import { getFirestore } from 'firebase/firestore';

const firebaseConfig = {
  apiKey: 'AIzaSyCR8smHR1i20yyCMikTYsQBt0HkAF0Tab8',
  authDomain: 'transfusion-c725d.firebaseapp.com',
  projectId: 'transfusion-c725d',
  storageBucket: 'transfusion-c725d.firebasestorage.app',
  messagingSenderId: '692767944401',
  appId: '1:692767944401:web:d02510d28570e8ec97dff0',
};

const app = initializeApp(firebaseConfig);
export const auth = getAuth(app);
export const db = getFirestore(app);
export default app;
