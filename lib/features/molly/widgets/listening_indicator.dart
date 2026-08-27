import 'package:flutter/material.dart';

import '../services/molly_voice_service.dart';

/// Indicação textual do estado da MOLLY — "Estou ouvindo...", "Pensando...",
/// "Falando..." (TAREFA 6 do prompt mestre).
///
/// Acessível de propósito: o estado nunca depende só de cor/ícone, sempre
/// tem um texto grande explicando o que está acontecendo, para não exigir
/// do usuário 60+ decifrar um símbolo.
class ListeningIndicator extends StatelessWidget {
  final MollyVoiceState estado;

  const ListeningIndicator({super.key, required this.estado});

  @override
  Widget build(BuildContext context) {
    final (String texto, Color cor) = switch (estado) {
      MollyVoiceState.listening => ('Estou ouvindo...', const Color(0xFF4A90D9)),
      MollyVoiceState.thinking => ('Pensando...', const Color(0xFFFF8C00)),
      MollyVoiceState.speaking => ('Falando...', const Color(0xFF50C878)),
      MollyVoiceState.error => ('Não consegui ouvir', const Color(0xFFE53935)),
      MollyVoiceState.idle => ('Toque no microfone para falar', const Color(0xFF7B5EA7)),
    };
    final ativo = estado != MollyVoiceState.idle;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (ativo) ...[
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(color: cor, shape: BoxShape.circle),
          ),
          const SizedBox(width: 10),
        ],
        Flexible(
          child: Text(
            texto,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 22, color: cor, fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }
}
