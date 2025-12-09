import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/app_config.dart';
import '../models/pack_def.dart';
import '../models/loop_def.dart';

class ContentRepository {
  final FirebaseFirestore _db;
  ContentRepository(this._db);

  Stream<AppConfig> watchAppConfig() {
    return _db.doc('app_config/current').snapshots().map((snap) {
      return AppConfig.fromMap(snap.data());
    });
  }

  Stream<List<PackDef>> watchPacks() {
    return _db.collection('packs').orderBy('order').snapshots().map((q) {
      return q.docs.map((d) => PackDef.fromFirestore(d.id, d.data())).toList();
    });
  }

  Stream<List<LoopDef>> watchLoops(String packId) {
    return _db
        .collection('packs')
        .doc(packId)
        .collection('loops')
        .snapshots()
        .map((q) => q.docs.map((d) => LoopDef.fromFirestore(d.id, d.data())).toList());
  }
}
