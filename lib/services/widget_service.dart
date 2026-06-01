import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/reminder.dart';

/// Salva os lembretes de hoje no SharedPreferences e aciona a
/// atualização do AppWidget via MethodChannel.
class WidgetService {
  static const _channel = MethodChannel('com.melembra.ai/widget');

  static Future<void> update(List<Reminder> reminders) async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    final todayList = reminders
        .where((r) => _occursOn(r, today))
        .toList()
      ..sort((a, b) => a.dateTime.compareTo(b.dateTime));

    final payload = todayList
        .map((r) => {
              'title': r.title,
              'time':
                  '${r.dateTime.hour.toString().padLeft(2, '0')}:${r.dateTime.minute.toString().padLeft(2, '0')}',
              'confirmed': r.confirmed,
            })
        .toList();

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('widget_reminders', jsonEncode(payload));
      await _channel.invokeMethod('updateWidget');
    } catch (_) {
      // Silencia erros em plataformas sem widget (ex: iOS, web)
    }
  }

  static bool _occursOn(Reminder r, DateTime day) {
    final rd = DateTime(r.dateTime.year, r.dateTime.month, r.dateTime.day);
    if (r.repeat == 'unico') return rd == day;
    if (r.repeat == 'diario') return !rd.isAfter(day);
    if (r.repeat == 'semanal') {
      return !rd.isAfter(day) && r.dateTime.weekday == day.weekday;
    }
    return false;
  }
}
