import 'package:cloud_firestore/cloud_firestore.dart';

class UserAchievement {
  final String id;
  final String userId;
  final String code;
  final String title;
  final String description;
  final DateTime unlockedAt;

  const UserAchievement({
    required this.id,
    required this.userId,
    required this.code,
    required this.title,
    required this.description,
    required this.unlockedAt,
  });

  factory UserAchievement.fromDoc(
      DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;
    return UserAchievement(
      id: doc.id,
      userId: data['userId'] as String,
      code: data['code'] as String,
      title: data['title'] as String,
      description: data['description'] as String,
      unlockedAt: (data['unlockedAt'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'code': code,
      'title': title,
      'description': description,
      'unlockedAt': Timestamp.fromDate(unlockedAt),
    };
  }
}
