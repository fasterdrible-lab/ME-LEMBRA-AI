import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../login_screen.dart';

/// Fluxo de boas-vindas (onboarding) exibido na primeira execução.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _pagina = 0;

  static const List<_OnboardingPage> _paginas = [
    _OnboardingPage(
      icon: Icons.notifications_active,
      titulo: 'Nunca mais esqueça',
      descricao:
          'Receba lembretes inteligentes de remédios, consultas e tarefas do dia.',
      cor: Color(0xFF7B5EA7),
    ),
    _OnboardingPage(
      icon: Icons.family_restroom,
      titulo: 'Toda a família junta',
      descricao:
          'Perfis para idosos, adultos e crianças, com recursos pensados para cada um.',
      cor: Color(0xFF4A90D9),
    ),
    _OnboardingPage(
      icon: Icons.shield_outlined,
      titulo: 'Segurança em primeiro lugar',
      descricao:
          'Botão SOS, alertas por voz e notificações para quem você ama.',
      cor: Color(0xFFE53935),
    ),
  ];

  void _avancar() {
    if (_pagina < _paginas.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    } else {
      _concluir();
    }
  }

  Future<void> _concluir() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboarding_visto', true);
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
    );
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pagina = _paginas[_pagina];
    return Scaffold(
      backgroundColor: pagina.cor,
      body: SafeArea(
        child: Column(
          children: [
            Align(
              alignment: Alignment.topRight,
              child: TextButton(
                onPressed: () => _concluir(),
                child: const Text('Pular',
                    style: TextStyle(color: Colors.white, fontSize: 16)),
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                onPageChanged: (i) => setState(() => _pagina = i),
                itemCount: _paginas.length,
                itemBuilder: (_, i) => _buildPage(_paginas[i]),
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                _paginas.length,
                (i) => AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: i == _pagina ? 24 : 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: i == _pagina ? 1 : 0.4),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(24),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _avancar,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: pagina.cor,
                    minimumSize: const Size(double.infinity, 54),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: Text(
                    _pagina == _paginas.length - 1 ? 'Começar' : 'Próximo',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPage(_OnboardingPage p) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(p.icon, color: Colors.white, size: 120),
          const SizedBox(height: 32),
          Text(
            p.titulo,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            p.descricao,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white70, fontSize: 16),
          ),
        ],
      ),
    );
  }
}

class _OnboardingPage {
  final IconData icon;
  final String titulo;
  final String descricao;
  final Color cor;

  const _OnboardingPage({
    required this.icon,
    required this.titulo,
    required this.descricao,
    required this.cor,
  });
}
