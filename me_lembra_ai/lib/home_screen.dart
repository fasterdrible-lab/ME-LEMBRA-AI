import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'services/profile_service.dart';
import 'services/reminder_service.dart';
import 'models/reminder.dart';
import 'create_reminder_screen.dart';
import 'reminders_screen.dart';
import 'categories_screen.dart';
import 'config_screen.dart';
import 'elderly_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String _perfil = '';
  String _nomeUsuario = '';
  String _dataFormatada = '';
  int _abaAtual = 0;

  @override
  void initState() {
    super.initState();
    _carregarPerfil();
    _carregarNome();
    _carregarData();
    _migrarSharedPreferencesSeNecessario();
  }

  Future<void> _carregarPerfil() async {
    final perfil = await ProfileService.getProfile();
    if (mounted) {
      setState(() => _perfil = perfil ?? '');
      if (perfil == 'Vovô / Vovó') {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (_) => const ElderlyScreen()),
            );
          }
        });
      }
    }
  }

  Future<void> _carregarNome() async {
    final nome = await ProfileService.getNameForSelectedProfile();
    if (mounted) setState(() => _nomeUsuario = nome ?? '');
  }

  String _getSaudacao() {
    final hora = DateTime.now().hour;
    if (hora < 12) return 'Bom dia';
    if (hora < 18) return 'Boa tarde';
    return 'Boa noite';
  }

  void _carregarData() {
    final now = DateTime.now();
    const dias = ['Segunda-feira','Terça-feira','Quarta-feira','Quinta-feira','Sexta-feira','Sábado','Domingo'];
    const meses = ['janeiro','fevereiro','março','abril','maio','junho','julho','agosto','setembro','outubro','novembro','dezembro'];
    setState(() => _dataFormatada = '${dias[now.weekday - 1]}, ${now.day} de ${meses[now.month - 1]}');
  }

  Future<void> _migrarSharedPreferencesSeNecessario() async {
    final prefs = await SharedPreferences.getInstance();
    final lista = prefs.getStringList('lembretes');
    if (lista != null && lista.isNotEmpty) {
      final perfil = await ProfileService.getProfile() ?? '';
      await ReminderService.migrarSharedPreferences(lista, perfil);
      await prefs.remove('lembretes');
    }
  }

  String _getEmoji(String tipo) {
    switch (tipo) {
      case 'Remedio': return '💊';
      case 'Consulta': return '🩺';
      case 'Aniversario': return '🎂';
      case 'Mercado': return '🛒';
      case 'Reuniao': return '🤝';
      case 'Tomar': return '💧';
      default: return '🔔';
    }
  }

  Color _getIconeCor(String tipo) {
    switch (tipo) {
      case 'Remedio': return const Color(0xFFFFEEEE);
      case 'Consulta': return const Color(0xFFEEF4FF);
      case 'Aniversario': return const Color(0xFFFFF3E0);
      case 'Mercado': return const Color(0xFFE8F5E9);
      case 'Reuniao': return const Color(0xFFEDE7F6);
      case 'Tomar': return const Color(0xFFE3F2FD);
      default: return const Color(0xFFF2F2F7);
    }
  }

  Widget _buildHome() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(20, 50, 20, 28),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF7B5EA7), Color(0xFF5B4FCF)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(28),
                bottomRight: Radius.circular(28),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _nomeUsuario.isNotEmpty
                      ? '${_getSaudacao()}, $_nomeUsuario! 👋'
                      : '${_getSaudacao()}! 👋',
                  style: const TextStyle(color: Colors.white70, fontSize: 16),
                ),
                const SizedBox(height: 6),
                const Text('Me Lembra Ai',
                  style: TextStyle(color: Color(0xFFFFB800), fontSize: 28, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.calendar_today, color: Colors.white, size: 14),
                      const SizedBox(width: 6),
                      Text(_dataFormatada, style: const TextStyle(color: Colors.white, fontSize: 13)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
            child: StreamBuilder<List<Reminder>>(
              stream: ReminderService.stream(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
                    child: const Center(child: Text('Erro ao carregar lembretes.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.black45))),
                  );
                }
                final lembretes = snapshot.data ?? [];
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Hoje', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        TextButton(
                          onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const RemindersScreen())),
                          child: const Text('Ver todos', style: TextStyle(color: Color(0xFF7B5EA7))),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    lembretes.isEmpty
                        ? Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
                            child: const Center(child: Text('Nenhum lembrete. Toque em Adicionar!',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: Colors.black45))),
                          )
                        : Column(children: lembretes.take(3).map((l) => _lembreteCard(l)).toList()),
                    const SizedBox(height: 24),
                    const Text('Em breve', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    lembretes.length > 3
                        ? Column(children: lembretes.skip(3).map((l) => _lembreteCard(l)).toList())
                        : Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
                            child: const Center(child: Text('Nenhum lembrete em breve.', style: TextStyle(color: Colors.black45))),
                          ),
                    const SizedBox(height: 80),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _lembreteCard(Reminder reminder) {
    final emoji = _getEmoji(reminder.type);
    final cor = _getIconeCor(reminder.type);
    final hora = '${reminder.dateTime.hour.toString().padLeft(2, '0')}:${reminder.dateTime.minute.toString().padLeft(2, '0')}';
    final subtitulo = reminder.description.isNotEmpty
        ? '${reminder.type} · ${reminder.description}'
        : reminder.type;
    final now = DateTime.now();
    final isToday = reminder.dateTime.year == now.year &&
        reminder.dateTime.month == now.month &&
        reminder.dateTime.day == now.day;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [const BoxShadow(blurRadius: 6, color: Colors.black12)],
      ),
      child: Row(
        children: [
          Container(
            width: 44, height: 44,
            decoration: BoxDecoration(color: cor, borderRadius: BorderRadius.circular(12)),
            child: Center(child: Text(emoji, style: const TextStyle(fontSize: 22))),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(reminder.title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                if (subtitulo.isNotEmpty)
                  Text(subtitulo, style: const TextStyle(color: Colors.black54, fontSize: 12)),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(hora,
                style: const TextStyle(color: Color(0xFF7B5EA7), fontWeight: FontWeight.w600, fontSize: 13)),
              if (isToday)
                Container(
                  margin: const EdgeInsets.only(top: 2),
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(color: const Color(0xFF7B5EA7), borderRadius: BorderRadius.circular(6)),
                  child: const Text('HOJE', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final telas = [
      _buildHome(),
      const CategoriesScreen(),
      const SizedBox(),
      const ConfigScreen(),
    ];
    return Scaffold(
      backgroundColor: const Color(0xFFF2F2F7),
      body: telas[_abaAtual],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _abaAtual == 3 ? 3 : _abaAtual,
        onTap: (i) async {
          if (i == 2) {
            await Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const CreateReminderScreen()),
            );
          } else {
            setState(() => _abaAtual = i);
          }
        },
        type: BottomNavigationBarType.fixed,
        selectedItemColor: const Color(0xFF7B5EA7),
        unselectedItemColor: Colors.grey,
        showUnselectedLabels: true,
        elevation: 12,
        items: const [
BottomNavigationBarItem(icon: Text('🏠', style: TextStyle(fontSize: 22)), label: 'Inicio'),
          BottomNavigationBarItem(icon: Text('📂', style: TextStyle(fontSize: 22)), label: 'Categorias'),
          BottomNavigationBarItem(icon: Text('➕', style: TextStyle(fontSize: 22)), label: 'Adicionar'),
          BottomNavigationBarItem(icon: Text('⚙', style: TextStyle(fontSize: 22)), label: 'Config'),
        ],
      ),
    );
  }
}