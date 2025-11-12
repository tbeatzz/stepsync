import 'package:cloud_firestore/cloud_firestore.dart';

class LoopsRepository {
  final _db = FirebaseFirestore.instance;

  Future<List<Map<String, dynamic>>> fetchAll() async {
    final snap = await _db.collection('loops')
        .orderBy('bucket')
        .orderBy('requiredLevel')
        .get();

    return snap.docs.map((d) => {'id': d.id, ...d.data()}).toList();
  }

  Future<Map<String, dynamic>?> bestForBucket(int bucket, int userLevel) async {
    final q = await _db.collection('loops')
        .where('bucket', isEqualTo: bucket)
        .where('requiredLevel', isLessThanOrEqualTo: userLevel)
        .orderBy('requiredLevel', descending: true)
        .limit(1)
        .get();

    if (q.docs.isEmpty) return null;
    final d = q.docs.first;
    return {'id': d.id, ...d.data()};
  }
}
