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
        builder: (_) => HomeScreen(),
      ),
    );
  }

  Widget _cardPerfil(
    BuildContext context,
    String titulo,
    String imagem,
    Color cor,
    String descricao,
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
        child: Column(
          children: [
            Center(
              child: Image.asset(
                imagem,
                width: 120,
                height: 120,
                fit: BoxFit.contain,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              titulo,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: cor,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              descricao,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13,
                color: Colors.black54,
              ),
            ),
          ],
        ),
      ),
    );
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
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFF4A90D9),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Icon(Icons.notifications_active,
                    color: Colors.white, size: 44),
              ),
              const SizedBox(height: 14),
              const Text(
                "ME LEMBRA AI",
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF4A90D9),
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                "Quem vai usar o aplicativo?",
                style: TextStyle(fontSize: 15, color: Colors.black54),
              ),
              const SizedBox(height: 24),
              Expanded(
                child: ListView(
                  children: [
                    _cardPerfil(
                      context,
                      "Vovo / Vova",
                      "assets/images/avos.png",
                      const Color(0xFF4A90D9),
                      "Interface acessivel com alertas por voz e SOS",
                    ),
                    _cardPerfil(
                      context,
                      "Adulto",
                      "assets/images/adultos.png",
                      const Color(0xFF50C878),
                      "Lembretes inteligentes e agenda integrada",
                    ),
                    _cardPerfil(
                      context,
                      "Crianca",
                      "assets/images/crianca.png",
                      const Color(0xFFFF8C00),
                      "Monitorado por responsavel com localizacao",
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