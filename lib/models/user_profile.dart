import 'package:cloud_firestore/cloud_firestore.dart';

class UserProfile {
  final String uid;
  final String displayName;
  final String email;
  final String? photoURL;

  final int level;
  final int points;

  final DateTime? createdAt;
  final DateTime? updatedAt;

  const UserProfile({
    required this.uid,
    required this.displayName,
    required this.email,
    required this.photoURL,
    required this.level,
    required this.points,
    this.createdAt,
    this.updatedAt,
  });

  /// Factory para crear un perfil inicial a partir del usuario de FirebaseAuth
  factory UserProfile.initialFromFirebaseUser({
    required String uid,
    required String email,
    String? displayName,
    String? photoURL,
  }) {
    return UserProfile(
      uid: uid,
      email: email,
      displayName: displayName ?? 'Usuario',
      photoURL: photoURL,
      level: 1,
      points: 0,
      createdAt: null,
      updatedAt: null,
    );
  }

  /// Construye desde un DocumentSnapshot de /users/{uid}
  factory UserProfile.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;
    return UserProfile(
      uid: doc.id,
      displayName: data['displayName'] as String? ?? 'Usuario',
      email: data['email'] as String? ?? '',
      photoURL: data['photoURL'] as String?,
      level: data['level'] as int? ?? 1,
      points: data['points'] as int? ?? 0,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
    );
  }

  /// Convierte a map listo para guardar en Firestore.
  /// OJO: acá NO ponemos createdAt/updatedAt, eso lo setea el repo con serverTimestamp().
  Map<String, dynamic> toMapForCreate() {
    return {
      'displayName': displayName,
      'email': email,
      'photoURL': photoURL,
      'level': level,
      'points': points,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  Map<String, dynamic> toMapForUpdate() {
    return {
      'displayName': displayName,
      'photoURL': photoURL,
      'level': level,
      'points': points,
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  /// Devuelve una copia modificada (útil después para sumar puntos, subir nivel, etc.)
  UserProfile copyWith({
    String? displayName,
    String? email,
    String? photoURL,
    int? level,
    int? points,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return UserProfile(
      uid: uid,
      displayName: displayName ?? this.displayName,
      email: email ?? this.email,
      photoURL: photoURL ?? this.photoURL,
      level: level ?? this.level,
      points: points ?? this.points,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
