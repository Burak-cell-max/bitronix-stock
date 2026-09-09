import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'models.dart';

class UserRepository {
  UserRepository(this._db);
  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _users => _db.collection('users');

  Stream<UserProfile?> currentUserProfile() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return Stream.value(null);
    return _users
        .doc(uid)
        .snapshots()
        .map((doc) => doc.exists ? UserProfile.fromDoc(doc) : null);
  }

  Stream<List<UserProfile>> allUsers() =>
      _users.snapshots().map((s) => s.docs.map(UserProfile.fromDoc).toList());

  Future<UserProfile?> getById(String uid) async {
    final doc = await _users.doc(uid).get();
    return doc.exists ? UserProfile.fromDoc(doc) : null;
  }

  /// Yeni kayıt: `users/{uid}` profilini oluşturur. Platform rolü daima `user`;
  /// yükseltme yalnızca bir superAdmin tarafından yapılabilir (güvenlik kuralı).
  Future<void> createProfile({
    required String uid,
    required String email,
    required String displayName,
    String? companyName,
  }) => _users.doc(uid).set({
    'email': email,
    'displayName': displayName,
    'name': displayName,
    'companyName': ?companyName,
    'role': UserRole.admin.name, // kendi workspace'inin admini
    'platformRole': PlatformRole.user.wire,
    'status': 'active',
    'isActive': true,
    'createdAt': FieldValue.serverTimestamp(),
    'updatedAt': FieldValue.serverTimestamp(),
  }, SetOptions(merge: true));

  /// Konsol'dan eklenip profili olmayan eski hesaplar için minimal profil.
  Future<void> upsertProfile(UserProfile profile) => _users
      .doc(profile.uid)
      .set(profile.toMap(), SetOptions(merge: true));

  /// Sadece MEVCUT profili günceller. Doküman yoksa (kayıt anındaki yarış,
  /// Console'dan eklenmiş hesap) sessizce başarısız olur — çağıran .catchError'lar.
  /// set(merge) kullanmıyoruz: bare bir doküman oluşturursa createProfile'ın
  /// platformRole/status eklemesi kural gereği reddedilir.
  Future<void> touchLastLogin(String uid) => _users.doc(uid).update({
    'lastLogin': FieldValue.serverTimestamp(),
  });

  // ─── Admin (Faz 2) ────────────────────────────────────────────────────────

  Future<void> setPlatformRole(String uid, PlatformRole role) =>
      _users.doc(uid).update({
        'platformRole': role.wire,
        'updatedAt': FieldValue.serverTimestamp(),
      });

  Future<void> setStatus(String uid, String status) => _users.doc(uid).update({
    'status': status,
    'isActive': status == 'active',
    'updatedAt': FieldValue.serverTimestamp(),
  });

  /// Legacy V1 "Kullanıcılar" ekranı — workspace rolünü users dokümanına yazar.
  /// V2'de rol atamaları workspace üyeliğinden yönetilir; bu yalnızca geriye
  /// dönük uyumluluk içindir.
  Future<void> setRole(String uid, UserRole role) => _users.doc(uid).update({
    'role': role.name,
    'updatedAt': FieldValue.serverTimestamp(),
  });
}
