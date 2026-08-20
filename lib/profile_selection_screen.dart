import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'services/fcm_service.dart';
import 'services/profile_service.dart';

class ProfileSelectionScreen extends StatefulWidget {
  const ProfileSelectionScreen({super.key});

  @override
  State<ProfileSelectionScreen> createState() => _ProfileSelectionScreenState();
}

class _ProfileSelectionScreenState extends State<ProfileSelectionScreen> {
  /// Mapeia o nome do perfil para a rota dedicada.
  String _routeForProfile(String perfil) {
    switch (perfil) {
      case 'Vovô / Vovó':
        return '/elderly';
      case 'Adulto':
        return '/adult';
      case 'Filhos':
        return '/child';
      case 'Família':
        return '/family';
      default:
        return '/adult';
    }
  }

  Future<void> _goToProfile(String perfil) async {
    if (!mounted) return;
    // BUG-001: login/cadastro chegam aqui e vao direto para a tela do
    // perfil, sem nunca construir a HomeScreen nesta sessao — por isso o
    // FCM precisa ser inicializado tambem neste ponto (fire-and-forget,
    // igual ao HomeScreen.initState, e seguro chamar de novo depois).
    FcmService.init();
    Navigator.pushReplacementNamed(context, _routeForProfile(perfil));
  }

  Future<void> _askNameIfNeededAndEnter(String perfil) async {
    await ProfileService.saveProfile(perfil);
    if (!mounted) return;

    final existingName = await ProfileService.getNameForProfile(perfil);
    if (!mounted) return;

    if (existingName != null && existingName.trim().isNotEmpty) {
      await _goToProfile(perfil);
      return;
    }

    final controller = TextEditingController();

    final result = await showDialog<String?>(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Olá, seja bem-vindo!'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Align(
                alignment: Alignment.centerLeft,
                child: Text('Como posso te chamar?'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                textInputAction: TextInputAction.done,
                decoration: const InputDecoration(
                  hintText: 'Ex: André',
                  border: OutlineInputBorder(),
                ),
                onSubmitted: (_) =>
                    Navigator.of(dialogContext).pop(controller.text.trim()),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(null),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () =>
                  Navigator.of(dialogContext).pop(controller.text.trim()),
              child: const Text('Continuar'),
            ),
          ],
        );
      },
    );

    if (!mounted) return;

    final name = (result ?? '').trim();
    if (name.isNotEmpty) {
      await ProfileService.saveNameForProfile(perfil, name);
      if (!mounted) return;
    }

    await _goToProfile(perfil);
  }

  Widget _cardPerfil(
    String titulo,
    IconData icone,
    Color cor,
    String descricao, {
    String? imagePath,
  }) {
    final size = MediaQuery.sizeOf(context);
    final iconSize = math.min(56.0, size.width * 0.14);

    Widget avatar;
    if (imagePath != null) {
      avatar = ClipRRect(
        borderRadius: BorderRadius.circular(50),
        child: Image.asset(
          imagePath,
          width: iconSize + 28,
          height: iconSize + 28,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: cor.withOpacity(0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(icone, color: cor, size: iconSize),
          ),
        ),
      );
    } else {
      avatar = Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: cor.withOpacity(0.12),
          shape: BoxShape.circle,
        ),
        child: Icon(icone, color: cor, size: iconSize),
      );
    }

    return GestureDetector(
      onTap: () => _askNameIfNeededAndEnter(titulo),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              blurRadius: 12,
              color: Colors.black.withOpacity(0.08),
            ),
          ],
        ),
        child: Column(
          children: [
            Center(child: avatar),
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
            const SizedBox(height: 6),
            Text(
              descricao,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13,
                color: Colors.black54,
                height: 1.25,
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
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          child: ListView(
            children: [
              // ── Header ──────────────────────────────────────
              const SizedBox(height: 4),
              Center(
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFF4A90D9),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Icon(
                    Icons.notifications_active,
                    color: Colors.white,
                    size: 44,
                  ),
                ),
              ),
              const SizedBox(height: 14),
              const Center(
                child: Text(
                  'ME LEMBRA AI',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF4A90D9),
                  ),
                ),
              ),
              const SizedBox(height: 6),
              const Center(
                child: Text(
                  'Quem vai usar o aplicativo?',
                  style: TextStyle(fontSize: 15, color: Colors.black54),
                ),
              ),
              const SizedBox(height: 12),
              // ── Cards ────────────────────────────────────────
              _cardPerfil(
                'Vovô / Vovó',
                Icons.elderly,
                const Color(0xFF4A90D9),
                'Interface acessível com alertas por voz e SOS',
                imagePath: 'assets/images/avos.png',
              ),
              _cardPerfil(
                'Adulto',
                Icons.person,
                const Color(0xFF50C878),
                'Lembretes inteligentes e agenda integrada',
                imagePath: 'assets/images/adultos.png',
              ),
              _cardPerfil(
                'Filhos',
                Icons.child_care,
                const Color(0xFFFF8C00),
                'Monitorado por responsável com localização',
                imagePath: 'assets/images/filhos.png',
              ),
              _cardPerfil(
                'Família',
                Icons.family_restroom,
                const Color(0xFF7B5EA7),
                'Monitore familiares e receba alertas em tempo real',
              ),
            ],
          ),
        ),
      ),
    );
  }
}
