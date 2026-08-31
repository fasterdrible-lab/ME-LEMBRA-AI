import 'package:flutter/material.dart';

import '../widgets/molly_assistant_panel.dart';

/// Tela principal da MOLLY (TAREFA 6 do prompt mestre).
///
/// Interface pensada para 60+: botões grandes, alto contraste, poucas
/// opções na tela, feedback visual (indicador de estado) e sonoro (TTS).
/// O botão SOS **nunca** fica escondido — está fixo na parte de baixo,
/// fora da área rolável, em qualquer estado da tela.
///
/// Desde a sessão 24, toda a lógica de conversa/voz/risco mora em
/// [MollyAssistantPanel] (`widgets/molly_assistant_panel.dart`) — esta
/// tela é só a casca (AppBar + `SafeArea`) em volta dele, com a lista
/// "Hoje" visível (`mostrarLembretesHoje: true`, o padrão). O mesmo painel
/// é reaproveitado, sem duplicar nada, no atalho rápido aberto direto de
/// `elderly_screen.dart` (bottom sheet, sem navegar pra esta rota).
class MollyScreen extends StatelessWidget {
  const MollyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F4FB),
      appBar: AppBar(
        title: const Text('MOLLY', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF7B5EA7),
        foregroundColor: Colors.white,
        centerTitle: true,
        elevation: 0,
      ),
      body: const SafeArea(child: MollyAssistantPanel()),
    );
  }
}
