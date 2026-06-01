import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/reminder.dart';
import 'notification_service.dart';

class ReminderService {
  static final _db = FirebaseFirestore.instance;

  static String? get _userId => FirebaseAuth.instance.currentUser?.uid;

  static CollectionReference<Map<String, dynamic>> get _col =>
      _db.collection('users').doc(_userId).collection('reminders');

  // Adicionar lembrete
  static Future<void> add(Reminder reminder) async {
    if (_userId == null) return;
    await _col.add(reminder.toFirestore());
  }

  // Stream em tempo real
  static Stream<List<Reminder>> stream() {
    if (_userId == null) return const Stream.empty();
    return _col
        .orderBy('dateTime')
        .snapshots()
        .map((snap) => snap.docs.map(Reminder.fromFirestore).toList());
  }

  // Buscar todos (uma vez)
  static Future<List<Reminder>> getAll() async {
    if (_userId == null) return [];
    final snap = await _col.orderBy('dateTime').get();
    return snap.docs.map(Reminder.fromFirestore).toList();
  }

  // Deletar
  static Future<void> delete(String id, {int? notificationId}) async {
    if (_userId == null) return;
    if (notificationId != null) {
      await NotificationService.cancel(notificationId);
    }
    await _col.doc(id).delete();
  }

  // Confirmar lembrete (ex: "remédio tomado")
  static Future<void> confirm(String id) async {
    if (_userId == null) return;
    await _col.doc(id).update({'confirmed': true});
  }

  // Atualizar lembrete existente
  static Future<void> update(Reminder reminder) async {
    if (_userId == null) return;
    await _col.doc(reminder.id).update(reminder.toFirestore());
  }

  // Migrar dados antigos do SharedPreferences para Firestore
  static Future<void> migrarSharedPreferences(
      List<String> rawList, String perfil) async {
    for (final raw in rawList) {
      final parts = raw.split('|');
      if (parts.length < 2) continue;
      final type = parts[0];
      final title = parts.length > 1 ? parts[1] : '';
      final description = parts.length > 2 ? parts[2] : '';
      final horaStr = parts.length > 4 ? parts[4] : '00:00';
      final horaParts = horaStr.split(':');
      final hora = int.tryParse(horaParts[0]) ?? 0;
      final minuto =
          int.tryParse(horaParts.length > 1 ? horaParts[1] : '0') ?? 0;
      final now = DateTime.now();
      final dateTime = DateTime(now.year, now.month, now.day, hora, minuto);

      final reminder = Reminder(
        id: '',
        userId: _userId ?? '',
        title: title,
        type: type,
        description: description,
        dateTime: dateTime,
        repeat: 'unico',
        notification: '',
        perfil: perfil,
      );
      await add(reminder);
    }
  }
}
