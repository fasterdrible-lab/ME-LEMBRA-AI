import 'package:flutter/material.dart';
import 'services/profile_service.dart';
import 'reminders_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String _perfil = '';

  @override
  void initState() {
    super.initState();
    _carregarPerfil();
  }

  Future<void> _carregarPerfil() async {
    final perfil = await ProfileService.getProfile();
    setState(() {
      _perfil = perfil ?? 'Adulto';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F2F7),
      appBar: AppBar(
        title: const Text(
          'ME LEMBRA AI',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: const Color(0xFF4A90D9),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Olá, $_perfil! 👋',
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'O que você precisa hoje?',
                style: TextStyle(color: Colors.black54, fontSize: 16),
              ),
              const SizedBox(height: 30),
              Expanded(
                child: GridView.count(
                  crossAxisCount: 2,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  children: [
                    _menuCard(
                      context,
                      icon: Icons.alarm,
                      label: 'Lembretes',
                      color: const Color(0xFF4A90D9),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const RemindersScreen(),
                          ),
                        );
                      },
                    ),
                    _menuCard(
                      context,
                      icon: Icons.medication,
                      label: 'Remédios',
                      color: const Color(0xFF50C878),
                      onTap: () {},
                    ),
                    _menuCard(
                      context,
                      icon: Icons.location_on,
                      label: 'Localização',
                      color: const Color(0xFFFF8C00),
                      onTap: () {},
                    ),
                    _menuCard(
                      context,
                      icon: Icons.chat_bubble,
                      label: 'Chat Familiar',
                      color: const Color(0xFF9B59B6),
                      onTap: () {},
                    ),
                    _menuCard(
                      context,
                      icon: Icons.bar_chart,
                      label: 'Relatórios',
                      color: const Color(0xFF1ABC9C),
                      onTap: () {},
                    ),
                    _menuCard(
                      context,
                      icon: Icons.warning_amber_rounded,
                      label: 'SOS',
                      color: const Color(0xFFE74C3C),
                      onTap: () {},
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _menuCard(
    BuildContext context, {
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              blurRadius: 10,
              color: Colors.black.withOpacity(0.07),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircleAvatar(
              radius: 30,
              backgroundColor: color.withOpacity(0.15),
              child: Icon(icon, color: color, size: 30),
            ),
            const SizedBox(height: 12),
            Text(
              label,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}