import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'services/profile_service.dart';
import 'create_reminder_screen.dart';
import 'reminders_screen.dart';
import 'categories_screen.dart';
import 'config_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String _perfil = '';
  String _nomeUsuario = '';
  String _dataFormatada = '';
  List<String> _lembretes = [];
  int _abaAtual = 0;

  @override
  void initState() {
    super.initState();
    _carregarPerfil();
    _carregarNome();
    _carregarData();
    _carregarLembretes();
  }

  Future<void> _carregarPerfil() async {
    final perfil = await ProfileService.getProfile();
    setState(() => _perfil = perfil ?? 'Voce');
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
    const dias = ['Segunda-feira','Terca-feira','Quarta-feira','Quinta-feira','Sexta-feira','Sabado','Domingo'];
    const meses = ['janeiro','fevereiro','marco','abril','maio','junho','julho','agosto','setembro','outubro','novembro','dezembro'];
    setState(() => _dataFormatada = dias[now.weekday - 1] + ', ' + now.day.toString() + ' de ' + meses[now.month - 1]);
  }

  Future<void> _carregarLembretes() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() => _lembretes = prefs.getStringList('lembretes') ?? []);
  }

  String _getEmoji(String raw) {
    final remedio = '💊';
    final consulta = '🩺';
    final aniversario = '🎂';
    final mercado = '🛒';
    final reuniao = '🤝';
    final tomar = '💧';
    final padrao = '🔔';
    final tipo = raw.split('|').first;
    switch (tipo) {
      case 'Remedio': return remedio;
      case 'Consulta': return consulta;
      case 'Aniversario': return aniversario;
      case 'Mercado': return mercado;
      case 'Reuniao': return reuniao;
      case 'Tomar': return tomar;
      default: return padrao;
    }
  }

  Color _getIconeCor(String raw) {
    final tipo = raw.split('|').first;
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

  String _getTitulo(String raw) {
    final parts = raw.split('|');
    return parts.length > 1 ? parts[1] : raw;
  }

  String _getSubtitulo(String raw) {
    final parts = raw.split('|');
    if (parts.length < 2) return '';
    final tipo = parts[0];
    final desc = parts.length > 2 ? parts[2] : '';
    if (desc.isNotEmpty) return tipo + ' \u00B7 ' + desc;
    return tipo;
  }

  String _getHora(String raw) {
    final parts = raw.split('|');
    return parts.length > 4 ? parts[4] : '';
  }

  void _mostrarSOS() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Botao de Panico', style: TextStyle(fontWeight: FontWeight.bold)),
        content: const Text('Deseja enviar um alerta de emergencia para seus contatos?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFE53935),
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(context),
            child: const Text('Enviar SOS'),
          ),
        ],
      ),
    );
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
                  style: TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold),
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
            child: Column(
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
                _lembretes.isEmpty
                    ? Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
                        child: const Center(child: Text('Nenhum lembrete. Toque em Adicionar!',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.black45))),
                      )
                    : Column(children: _lembretes.take(3).map((l) => _lembreteCard(l)).toList()),
                const SizedBox(height: 24),
                const Text('Em breve', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                _lembretes.length > 3
                    ? Column(children: _lembretes.skip(3).map((l) => _lembreteCard(l)).toList())
                    : Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
                        child: const Center(child: Text('Nenhum lembrete em breve.', style: TextStyle(color: Colors.black45))),
                      ),
                const SizedBox(height: 80),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _lembreteCard(String raw) {
    final titulo = _getTitulo(raw);
    final subtitulo = _getSubtitulo(raw);
    final emoji = _getEmoji(raw);
    final cor = _getIconeCor(raw);
    final hora = _getHora(raw);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(blurRadius: 6, color: Colors.black12)],
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
                Text(titulo, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                if (subtitulo.isNotEmpty)
                  Text(subtitulo, style: const TextStyle(color: Colors.black54, fontSize: 12)),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(hora.isNotEmpty ? hora : 'Hoje',
                style: const TextStyle(color: Color(0xFF7B5EA7), fontWeight: FontWeight.w600, fontSize: 13)),
              if (hora.isNotEmpty)
                Container(
                  margin: const EdgeInsets.only(top: 2),
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(color: const Color(0xFF7B5EA7), borderRadius: BorderRadius.circular(6)),
                  child: const Text('HOJ', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
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
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final resultado = await Navigator.push<String>(
            context,
            MaterialPageRoute(builder: (_) => const CreateReminderScreen()),
          );
          if (resultado != null && resultado.isNotEmpty) {
            final prefs = await SharedPreferences.getInstance();
            final lista = prefs.getStringList('lembretes') ?? [];
            lista.add(resultado);
            await prefs.setStringList('lembretes', lista);
            _carregarLembretes();
          }
        },
        backgroundColor: const Color(0xFF7B5EA7),
        child: const Icon(Icons.add, color: Colors.white, size: 28),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _abaAtual == 3 ? 3 : _abaAtual,
        onTap: (i) => setState(() => _abaAtual = i),
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
