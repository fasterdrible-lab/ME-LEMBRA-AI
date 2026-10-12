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

  /// Dias em que foi confirmado ("2026-10-12"), gravados só por
  /// `ReminderService.confirm` (arrayUnion) — de propósito fora de
  /// [toFirestore], pra editar o lembrete não apagar as confirmações.
  /// [confirmed] continua existindo, mas é um só pra sempre: num lembrete
  /// diário, não diz se o remédio de HOJE foi tomado (sessão 26).
  final List<String> confirmedDates;

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
    this.confirmedDates = const [],
  });

  /// "2026-10-12" — a chave de [confirmedDates]. O servidor
  /// (`server/remedio_notifier.py`) usa o mesmo formato.
  static String chaveDia(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  /// Acontece nesse dia? Diário: de [dateTime] em diante, todo dia;
  /// semanal: no mesmo dia da semana. [dateTime] de um lembrete repetido é
  /// só a PRIMEIRA vez — nada no app o avança.
  bool ocorreEm(DateTime dia) {
    final inicio = DateTime(dateTime.year, dateTime.month, dateTime.day);
    final d = DateTime(dia.year, dia.month, dia.day);
    switch (repeat) {
      case 'diario':
        return !inicio.isAfter(d);
      case 'semanal':
        return !inicio.isAfter(d) && dateTime.weekday == d.weekday;
      default:
        return inicio == d;
    }
  }

  /// O horário dele nesse dia (mesma hora/minuto de [dateTime]).
  DateTime horarioEm(DateTime dia) => DateTime(dia.year, dia.month, dia.day, dateTime.hour, dateTime.minute);

  /// Foi confirmado nesse dia? Lembrete único também aceita o [confirmed]
  /// antigo (confirmações de antes de [confirmedDates] existir).
  bool confirmadoEm(DateTime dia) =>
      confirmedDates.contains(chaveDia(dia)) || (repeat != 'diario' && repeat != 'semanal' && confirmed);

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
      confirmedDates: (data['confirmedDates'] as List?)?.whereType<String>().toList() ?? const [],
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
    List<String>? confirmedDates,
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
      confirmedDates: confirmedDates ?? this.confirmedDates,
    );
  }
}