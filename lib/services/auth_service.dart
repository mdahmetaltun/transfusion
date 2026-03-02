import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';
import 'package:flutter/foundation.dart';

class AuthService extends ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  bool _googleSignInInitialized = false;

  UserModel? currentUserProfile;
  bool isLoading = true;

  AuthService() {
    _auth.authStateChanges().listen((User? user) async {
      isLoading = true;
      notifyListeners();

      if (user != null) {
        currentUserProfile = await _fetchUserProfile(user.uid);
      } else {
        currentUserProfile = null;
      }

      isLoading = false;
      notifyListeners();
    });
  }

  User? get currentFirebaseUser => _auth.currentUser;

  Future<void> signInWithGoogle() async {
    try {
      if (!_googleSignInInitialized) {
        await GoogleSignIn.instance.initialize();
        _googleSignInInitialized = true;
      }

      final GoogleSignInAccount googleUser = await GoogleSignIn.instance
          .authenticate();

      final GoogleSignInAuthentication googleAuth = googleUser.authentication;
      final authz = await googleUser.authorizationClient.authorizationForScopes(
        ['email'],
      );

      final AuthCredential credential = GoogleAuthProvider.credential(
        accessToken: authz?.accessToken,
        idToken: googleAuth.idToken,
      );

      await _auth.signInWithCredential(credential);
    } on GoogleSignInException catch (e) {
      if (kDebugMode) print("Google Login Canceled/Error: $e");
      // Kullanıcı iptal ettiğinde rethrow yapmıyoruz
    } catch (e) {
      if (kDebugMode) print("Google Login Error: $e");
      rethrow;
    }
  }

  Future<void> signOut() async {
    if (!_googleSignInInitialized) {
      await GoogleSignIn.instance.initialize();
      _googleSignInInitialized = true;
    }
    await GoogleSignIn.instance.signOut();
    await _auth.signOut();
  }

  Future<UserModel?> _fetchUserProfile(String uid) async {
    try {
      final doc = await _firestore.collection('users').doc(uid).get();
      if (doc.exists && doc.data() != null) {
        return UserModel.fromMap(doc.data()!, doc.id);
      }
      return null; // Kullanıcı var ama profili yok (İlk giriş)
    } catch (e) {
      if (kDebugMode) print("Fetch Profile Error: \$e");
      return null;
    }
  }

  Future<void> createUserProfile(UserModel user) async {
    await _firestore.collection('users').doc(user.uid).set(user.toMap());
    currentUserProfile = user;
    notifyListeners();
  }
}
