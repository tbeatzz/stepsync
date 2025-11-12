
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class UserLevelProvider {
  final _db = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  Future<int> getCurrentUserLevel() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return 1; // fallback
    final doc = await _db.collection('users').doc(uid).get();
    final data = doc.data();
    if (data == null) return 1;
    final level = data['level'];
    return (level is int) ? level : 1;
  }
}
