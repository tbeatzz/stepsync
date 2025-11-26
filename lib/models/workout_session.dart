import 'package:cloud_firestore/cloud_firestore.dart';

class WorkoutSession {
  final String? id;
  final String userId;
  final bool isGuest;
  final String mode; // "Caminar", "Trotar", "Correr"
  final int steps;
  final int maxCombo;
  final int avgBpm;
  final DateTime startedAt;
  final DateTime endedAt;

  WorkoutSession({
    this.id,
    required this.userId,
    required this.isGuest,
    required this.mode,
    required this.steps,
    required this.maxCombo,
    required this.avgBpm,
    required this.startedAt,
    required this.endedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'isGuest': isGuest,
      'mode': mode,
      'steps': steps,
      'maxCombo': maxCombo,
      'avgBpm': avgBpm,
      'startedAt': Timestamp.fromDate(startedAt),
      'endedAt': Timestamp.fromDate(endedAt),
    };
  }

  factory WorkoutSession.fromDoc(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return WorkoutSession(
      id: doc.id,
      userId: data['userId'] as String? ?? 'unknown',
      isGuest: data['isGuest'] as bool? ?? true,
      mode: data['mode'] as String? ?? 'Caminar',
      steps: data['steps'] as int? ?? 0,
      maxCombo: data['maxCombo'] as int? ?? 0,
      avgBpm: data['avgBpm'] as int? ?? 0,
      startedAt: (data['startedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      endedAt: (data['endedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}
