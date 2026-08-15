import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'models.dart';

class UserRepository {
  UserRepository(this._db);
  final FirebaseFirestore _db;

  Stream<UserProfile?> currentUserProfile() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return Stream.value(null);
    return _db
        .collection('users')
        .doc(uid)
        .snapshots()
        .map((doc) => doc.exists ? UserProfile.fromDoc(doc) : null);
  }

  Stream<List<UserProfile>> allUsers() => _db
      .collection('users')
      .where('isActive', isEqualTo: true)
      .snapshots()
      .map((s) => s.docs.map(UserProfile.fromDoc).toList());

  Future<UserProfile?> getById(String uid) async {
    final doc = await _db.collection('users').doc(uid).get();
    return doc.exists ? UserProfile.fromDoc(doc) : null;
  }

  Future<void> setRole(String uid, UserRole role) =>
      _db.collection('users').doc(uid).update({
        'role': role.name,
        'updatedAt': FieldValue.serverTimestamp(),
      });

  Future<void> upsertProfile(UserProfile profile) =>
      _db.collection('users').doc(profile.uid).set(
            profile.toMap(),
            SetOptions(merge: true),
          );
}
