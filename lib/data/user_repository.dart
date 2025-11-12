import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class UserRepository {
  final _db = FirebaseFirestore.instance;

  Future<void> upsertUserProfile(User user) async {
    final ref = _db.collection('users').doc(user.uid);
    await _db.runTransaction((tx) async {
      final snap = await tx.get(ref);
      final now = FieldValue.serverTimestamp();
      if (!snap.exists) {
        tx.set(ref, {
          'displayName': user.displayName,
          'email': user.email,
          'photoURL': user.photoURL,
          'level': 1,
          'points': 0,
          'createdAt': now,
          'updatedAt': now,
        });
      } else {
        tx.update(ref, {'displayName': user.displayName, 'photoURL': user.photoURL, 'updatedAt': now});
      }
    });
  }
  Stream<Map<String, dynamic>?> watchUserProfile(String uid) {
    final ref = _db.collection('users').doc(uid);
    return ref.snapshots().map((d) => d.data());
  }

}
