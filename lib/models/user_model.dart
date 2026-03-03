// ignore_for_file: constant_identifier_names

enum UserRole { NURSE, DOCTOR, BLOOD_BANK, ADMIN }

class UserModel {
  final String uid;
  final String displayName;
  final String email;
  final UserRole role;
  final String facilityId;
  final String? photoUrl;

  UserModel({
    required this.uid,
    required this.displayName,
    required this.email,
    required this.role,
    required this.facilityId,
    this.photoUrl,
  });

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'displayName': displayName,
      'email': email,
      'role': role.toString().split('.').last,
      'facilityId': facilityId,
      'photoUrl': photoUrl,
    };
  }

  factory UserModel.fromMap(Map<String, dynamic> map, String documentId) {
    return UserModel(
      uid: documentId,
      displayName: map['displayName'] ?? '',
      email: map['email'] ?? '',
      role: UserRole.values.firstWhere(
        (e) => e.toString().split('.').last == (map['role'] ?? 'NURSE'),
        orElse: () => UserRole.NURSE,
      ),
      facilityId: map['facilityId'] ?? 'DEFAULT',
      photoUrl: map['photoUrl'],
    );
  }
}
