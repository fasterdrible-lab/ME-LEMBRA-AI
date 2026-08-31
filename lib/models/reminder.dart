import 'package:cloud_firestore/cloud_firestore.dart';

class Reminder {
  final String id;
  final String userId;
  final String title;
  final String type;
  final String description;
  final DateTime dateTime;
  final String repeat; // 'unico', 'diario', 'semanal'
  final String notification;
  final bool confirmed;
  final String perfil; // 'Melhor Idade', 'Adulto', 'Filhos' (ou o legado 'Vovô / Vovó')

  Reminder({
    required this.id,
    required this.userId,
    required this.title,
    required this.type,
    required this.description,
    required this.dateTime,
    required this.repeat,
    required this.notification,
    this.confirmed = false,
    required this.perfil,
  });

  factory Reminder.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Reminder(
      id: doc.id,
      userId: data['userId'] ?? '',
      title: data['title'] ?? '',
      type: data['type'] ?? '',
      description: data['description'] ?? '',
      dateTime: (data['dateTime'] as Timestamp).toDate(),
      repeat: data['repeat'] ?? 'unico',
      notification: data['notification'] ?? '',
      confirmed: data['confirmed'] ?? false,
      perfil: data['perfil'] ?? '',
    );
  }

  Map<String, dynamic> toFirestore() => {
        'userId': userId,
        'title': title,
        'type': type,
        'description': description,
        'dateTime': Timestamp.fromDate(dateTime),
        'repeat': repeat,
        'notification': notification,
        'confirmed': confirmed,
        'perfil': perfil,
        'createdAt': FieldValue.serverTimestamp(),
      };

  Reminder copyWith({
    String? id,
    String? userId,
    String? title,
    String? type,
    String? description,
    DateTime? dateTime,
    String? repeat,
    String? notification,
    bool? confirmed,
    String? perfil,
  }) {
    return Reminder(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      title: title ?? this.title,
      type: type ?? this.type,
      description: description ?? this.description,
      dateTime: dateTime ?? this.dateTime,
      repeat: repeat ?? this.repeat,
      notification: notification ?? this.notification,
      confirmed: confirmed ?? this.confirmed,
      perfil: perfil ?? this.perfil,
    );
  }
}