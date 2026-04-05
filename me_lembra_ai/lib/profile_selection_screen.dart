import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'services/profile_service.dart';
import 'home_screen.dart';

class ProfileSelectionScreen extends StatefulWidget {
  const ProfileSelectionScreen({super.key});

  @override
  State<ProfileSelectionScreen> createState() => _ProfileSelectionScreenState();
}

class _ProfileSelectionScreenState extends State<ProfileSelectionScreen> {
  Future<void> _goHome() async {
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const HomeScreen()),
    );
  }

  Future<void> _askNameIfNeededAndEnter(String perfil) async {
    await ProfileService.saveProfile(perfil);
    if (!mounted) return;

    final existingName = await ProfileService.getNameForProfile(perfil);
    if (!mounted) return;

    if (existingName != null && existingName.trim().isNotEmpty) {
      await _goHome();
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

    await _goHome();
  }

  Widget _cardPerfil(
    String titulo,
    String imagem,
    Color cor,
    String descricao,
  ) {
    final size = MediaQuery.sizeOf(context);
    final imageSize = math.min(90.0, size.width * 0.22);

    return GestureDetector(
      onTap: () => _askNameIfNeededAndEnter(titulo),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              blurRadius: 12,
              color: Colors.black.withValues(alpha: 0.08),
            ),
          ],
        ),
        child: Column(
          children: [
            Center(
              child: Image.asset(
                imagem,
                width: imageSize,
                height: imageSize,
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
      backgroundColor: const Color(0xFFF2F2F7),
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
                'assets/images/avos.png',
                const Color(0xFF4A90D9),
                'Interface acessivel com alertas por voz e SOS',
              ),
              _cardPerfil(
                'Adulto',
                'assets/images/adultos.png',
                const Color(0xFF50C878),
                'Lembretes inteligentes e agenda integrada',
              ),
              _cardPerfil(
                'Crianca',
                'assets/images/crianca.png',
                const Color(0xFFFF8C00),
                'Monitorado por responsavel com localizacao',
              ),
            ],
          ),
        ),
      ),
    );
  }
}