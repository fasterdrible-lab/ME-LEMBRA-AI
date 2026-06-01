import 'package:flutter/material.dart';

import '../family/family_screen.dart';

/// Compatibilidade: a antiga tela de monitoramento agora redireciona
/// para a nova tela de família/monitoramento real.
class ChildMonitorScreen extends StatelessWidget {
  const ChildMonitorScreen({super.key});

  @override
  Widget build(BuildContext context) => const FamilyScreen();
}
