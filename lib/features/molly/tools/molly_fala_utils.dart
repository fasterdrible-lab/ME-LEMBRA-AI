/// Formata um horário para fala natural em pt-BR.
/// Ex.: 16:27 -> "16 horas e 27 minutos"; 16:00 -> "16 horas".
///
/// Compartilhado entre as ferramentas da MOLLY para não duplicar a mesma
/// função pequena em cada arquivo (`reminder_tool.dart`,
/// `molly_agent_service.dart`, etc.).
String horaFalada(DateTime dt) {
  final h = dt.hour;
  final m = dt.minute;
  final hStr = h == 1 ? '1 hora' : '$h horas';
  if (m == 0) return hStr;
  final mStr = m == 1 ? '1 minuto' : '$m minutos';
  return '$hStr e $mStr';
}
