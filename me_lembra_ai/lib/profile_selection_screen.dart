import 'package:flutter/material.dart';
import 'services/profile_service.dart';
import 'home_screen.dart';

class ProfileSelectionScreen extends StatelessWidget {
  const ProfileSelectionScreen({super.key});

  void _entrar(BuildContext context, String perfil) async {
    await ProfileService.saveProfile(perfil);

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => const HomeScreen(),
      ),
    );
  }

  Widget _cardPerfil(
    BuildContext context,
    String titulo,
    String imagem,
    Color cor,
    IconData icone,
  ) {
    return GestureDetector(
      onTap: () => _entrar(context, titulo),
      child: Container(
        margin: const EdgeInsets.only(bottom: 20),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              blurRadius: 12,
              color: Colors.black.withOpacity(0.08),
            )
          ],
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 32,
              backgroundColor: cor.withOpacity(0.15),
              child: Icon(icone, color: cor, size: 32),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    titulo,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _descricao(titulo),
                    style: const TextStyle(
                      fontSize: 13,
                      color: Colors.black54,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Colors.black26),
          ],
        ),
      ),
    );
  }

  String _descricao(String titulo) {
    switch (titulo) {
      case 'Vovô / Vovó':
        return 'Interface acessível com alertas por voz e SOS';
      case 'Adulto':
        return 'Lembretes inteligentes e agenda integrada';
      case 'Criança':
        return 'Monitorado por responsável com localização';
      default:
        return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F2F7),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
          child: Column(
            children: [
              const SizedBox(height: 30),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF4A90D9),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Icon(Icons.notifications_active,
                    color: Colors.white, size: 48),
              ),
              const SizedBox(height: 20),
              const Text(
                "ME LEMBRA AI",
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF4A90D9),
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                "Quem vai usar o aplicativo?",
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.black54,
                ),
              ),
              const SizedBox(height: 36),
              Expanded(
                child: ListView(
                  children: [
                    _cardPerfil(
                      context,
                      "Vovô / Vovó",
                      "assets/images/avos.png",
                      const Color(0xFF4A90D9),
                      Icons.elderly,
                    ),
                    _cardPerfil(
                      context,
                      "Adulto",
                      "assets/images/adultos.png",
                      const Color(0xFF50C878),
                      Icons.person,
                    ),
                    _cardPerfil(
                      context,
                      "Criança",
                      "assets/images/crianca.png",
                      const Color(0xFFFF8C00),
                      Icons.child_care,
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
}