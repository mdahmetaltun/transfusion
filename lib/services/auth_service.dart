import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';
import 'package:flutter/foundation.dart';

class AuthService extends ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  bool _googleSignInInitialized = false;

  static const String superAdminEmail = 'md.ahmetaltun.38@gmail.com';

  UserModel? currentUserProfile;
  bool isLoading = true;

  bool get isSuperAdmin => currentFirebaseUser?.email == superAdminEmail;
  bool get isAdmin =>
      currentUserProfile?.role == UserRole.ADMIN || isSuperAdmin;

  AuthService() {
    _auth.authStateChanges().listen((User? user) async {
      isLoading = true;
      notifyListeners();

      if (user != null) {
        currentUserProfile = await _fetchUserProfile(user.uid);

        if (currentUserProfile == null) {
          final email = user.email ?? '';
          // approved_admins listesindeyse admin profili oluştur
          final isAdmin = await _isApprovedAdmin(email);
          if (isAdmin) {
            currentUserProfile = await _bootstrapAdminProfile(user);
          } else {
            // approved_users listesindeyse belirtilen rol/kurum ile profil oluştur
            final approvedData = await _getApprovedUserData(email);
            if (approvedData != null) {
              currentUserProfile = await _bootstrapUserProfile(user, approvedData);
            }
          }
        }
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
      if (kIsWeb) {
        // Web: Firebase popup ile doğrudan giriş
        final GoogleAuthProvider googleProvider = GoogleAuthProvider();
        googleProvider.addScope('email');
        await _auth.signInWithPopup(googleProvider);
      } else {
        // Mobil: google_sign_in paketi
        if (!_googleSignInInitialized) {
          await GoogleSignIn.instance.initialize();
          _googleSignInInitialized = true;
        }

        final GoogleSignInAccount googleUser =
            await GoogleSignIn.instance.authenticate();

        final GoogleSignInAuthentication googleAuth =
            googleUser.authentication;
        final authz =
            await googleUser.authorizationClient.authorizationForScopes(
          ['email'],
        );

        final AuthCredential credential = GoogleAuthProvider.credential(
          accessToken: authz?.accessToken,
          idToken: googleAuth.idToken,
        );

        await _auth.signInWithCredential(credential);
      }
    } on GoogleSignInException catch (e) {
      if (kDebugMode) print("Google Login Canceled/Error: $e");
    } catch (e) {
      if (kDebugMode) print("Google Login Error: $e");
      rethrow;
    }
  }

  Future<void> signInWithEmailPassword(String email, String password) async {
    try {
      await _auth.signInWithEmailAndPassword(email: email, password: password);
    } catch (e) {
      if (kDebugMode) print("Email Login Error: $e");
      rethrow;
    }
  }

  Future<void> registerWithEmailPassword(String email, String password) async {
    try {
      await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
    } catch (e) {
      if (kDebugMode) print("Registration Error: $e");
      rethrow;
    }
  }

  Future<void> signOut() async {
    if (!kIsWeb) {
      if (!_googleSignInInitialized) {
        await GoogleSignIn.instance.initialize();
        _googleSignInInitialized = true;
      }
      await GoogleSignIn.instance.signOut();
    }
    await _auth.signOut();
  }

  Future<UserModel?> _fetchUserProfile(String uid) async {
    try {
      final doc = await _firestore.collection('users').doc(uid).get();
      if (doc.exists && doc.data() != null) {
        return UserModel.fromMap(doc.data()!, doc.id);
      }
      return null;
    } catch (e) {
      if (kDebugMode) print("Fetch Profile Error: $e");
      return null;
    }
  }

  Future<bool> _isApprovedAdmin(String email) async {
    if (email.isEmpty) return false;
    if (email == superAdminEmail) return true;
    try {
      final doc =
          await _firestore.collection('approved_admins').doc(email).get();
      return doc.exists;
    } catch (e) {
      return false;
    }
  }

  Future<Map<String, dynamic>?> _getApprovedUserData(String email) async {
    if (email.isEmpty) return null;
    try {
      final doc =
          await _firestore.collection('approved_users').doc(email).get();
      return doc.exists ? doc.data() : null;
    } catch (e) {
      return null;
    }
  }

  Future<UserModel> _bootstrapAdminProfile(User user) async {
    final profile = UserModel(
      uid: user.uid,
      displayName: user.displayName ?? user.email!.split('@')[0],
      email: user.email!,
      role: UserRole.ADMIN,
      facilityId: 'DFLT-001',
      photoUrl: user.photoURL,
    );
    await _firestore.collection('users').doc(user.uid).set(profile.toMap());
    return profile;
  }

  Future<UserModel> _bootstrapUserProfile(
      User user, Map<String, dynamic> approvedData) async {
    final roleStr = approvedData['role'];
    final role = (roleStr != null && roleStr.toString().isNotEmpty)
        ? UserRole.values.firstWhere(
            (e) => e.toString().split('.').last == roleStr,
            orElse: () => UserRole.NURSE,
          )
        : UserRole.NURSE;
    final profile = UserModel(
      uid: user.uid,
      // Panelden ad girilmişse onu al, yoksa Google hesabındaki adı kullan
      displayName: (approvedData['displayName'] ?? '').toString().isNotEmpty
          ? approvedData['displayName']
          : (user.displayName ?? user.email!.split('@')[0]),
      email: user.email!,
      role: role,
      facilityId: (approvedData['facilityId'] ?? '').toString().isNotEmpty
          ? approvedData['facilityId']
          : 'DFLT-001',
      photoUrl: user.photoURL,
    );
    await _firestore.collection('users').doc(user.uid).set(profile.toMap());
    // Davet kaydını temizle — artık gerçek profili var
    await _firestore.collection('approved_users').doc(user.email).delete();
    return profile;
  }

  Future<void> createUserProfile(UserModel user) async {
    await _firestore.collection('users').doc(user.uid).set(user.toMap());
    currentUserProfile = user;
    notifyListeners();
  }

  // --- Admin Kullanıcı Yönetimi ---

  Future<List<Map<String, dynamic>>> getApprovedAdmins() async {
    final snapshot =
        await _firestore.collection('approved_admins').orderBy('addedAt').get();
    return snapshot.docs.map((d) => {'id': d.id, ...d.data()}).toList();
  }

  Future<void> addApprovedAdmin(String email, String displayName) async {
    await _firestore.collection('approved_admins').doc(email).set({
      'email': email,
      'displayName': displayName,
      'addedBy': currentFirebaseUser?.email ?? '',
      'addedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> removeApprovedAdmin(String email) async {
    await _firestore.collection('approved_admins').doc(email).delete();
    // Eğer kullanıcı Firestore'da mevcutsa ADMIN rolünü geri al
    final q = await _firestore
        .collection('users')
        .where('email', isEqualTo: email)
        .get();
    for (final doc in q.docs) {
      await doc.reference.update({'role': 'NURSE'});
    }
  }

  Future<void> updateUserProfilePhoto(String photoUrl) async {
    if (currentUserProfile == null) return;

    await _firestore.collection('users').doc(currentUserProfile!.uid).update({
      'photoUrl': photoUrl,
    });

    currentUserProfile = UserModel(
      uid: currentUserProfile!.uid,
      displayName: currentUserProfile!.displayName,
      email: currentUserProfile!.email,
      role: currentUserProfile!.role,
      facilityId: currentUserProfile!.facilityId,
      photoUrl: photoUrl,
    );
    notifyListeners();
  }

  Future<void> updateUserProfile({
    required String displayName,
    required UserRole role,
    required String facilityId,
  }) async {
    if (currentUserProfile == null) return;

    final trimmedName = displayName.trim();
    final trimmedFacility = facilityId.trim();

    if (trimmedName.isEmpty || trimmedFacility.isEmpty) {
      throw ArgumentError('Display name and facility cannot be empty');
    }

    final updates = <String, dynamic>{
      'displayName': trimmedName,
      'role': role.toString().split('.').last,
      'facilityId': trimmedFacility,
    };

    await _firestore
        .collection('users')
        .doc(currentUserProfile!.uid)
        .update(updates);

    await _auth.currentUser?.updateDisplayName(trimmedName);

    currentUserProfile = UserModel(
      uid: currentUserProfile!.uid,
      displayName: trimmedName,
      email: currentUserProfile!.email,
      role: role,
      facilityId: trimmedFacility,
      photoUrl: currentUserProfile!.photoUrl,
    );
    notifyListeners();
  }
}
