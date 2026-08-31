import 'package:flutter/foundation.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

import '../../../services/voice_service.dart';

/// Estado da "voz" da MOLLY, para uma UI (TAREFA 6) mostrar "Estou
/// ouvindo" / "Pensando" / "Falando" sem precisar espiar detalhes de
/// `speech_to_text`/`flutter_tts`.
enum MollyVoiceState { idle, listening, thinking, speaking, error }

/// Camada de voz da MOLLY (TAREFA 5 do prompt mestre).
///
/// Reaproveita `speech_to_text` (STT) e o `VoiceService` já existente
/// (TTS) — não reimplementa nenhum dos dois, só orquestra. Extrai a lógica
/// hoje embutida em `elderly_screen.dart` (`_iniciarEscuta`,
/// `_finalizarComando`, `_falar`) para uma classe própria e testável.
///
/// Diferente dos demais serviços da MOLLY (estáticos, sem estado — ver
/// `MollyAgentService`/`MollyToolRegistry`/`MollyRiskPolicy`), este é
/// **instanciável de propósito**: guarda o ciclo de vida real de um
/// `SpeechToText` e o estado atual da conversa por voz. Quem usa deve
/// manter uma única instância por tela (exatamente como `elderly_screen.dart`
/// já faz hoje com seu campo `_speech`) e chamar [dispose] ao descartá-la.
///
/// Detecção de palavras críticas (ex.: "SOCORRO") **não é responsabilidade
/// desta classe** — é lógica de negócio, não de voz, e continua sendo
/// decisão de quem chama, através de [aoOuvirParcial] em [escutar]. Isso
/// preserva a garantia da TAREFA 7/18 do prompt mestre: SOS nunca deve
/// depender desta camada estar correta, muito menos de uma IA.
class MollyVoiceService {
  final stt.SpeechToText _speech = stt.SpeechToText();

  /// Estado atual — uma UI pode ouvir com `ValueListenableBuilder`.
  final ValueNotifier<MollyVoiceState> estado = ValueNotifier(MollyVoiceState.idle);

  /// Transcrição parcial/em andamento, atualizada a cada resultado do STT
  /// (mesmo antes do resultado final) — útil para mostrar "ouvindo: ...".
  final ValueNotifier<String> textoParcial = ValueNotifier('');

  String _capturaAtual = '';
  bool _finalJaEntregue = false;
  bool _descartado = false;

  /// Inicia um turno de escuta. Retorna `false` se o reconhecimento de voz
  /// não estiver disponível no aparelho (mesma checagem de
  /// `_iniciarEscuta` hoje).
  ///
  /// [aoOuvirParcial] é chamado a cada trecho reconhecido, final ou não —
  /// é aqui que quem chama deve checar palavras críticas como "SOCORRO"
  /// (ver docstring da classe) e, se detectar uma, chamar [pararEscuta]
  /// e agir imediatamente, sem esperar [aoReconhecerFinal].
  ///
  /// [aoReconhecerFinal] é chamado uma única vez por turno, com a
  /// transcrição final (pode vir vazia, se o usuário ficou em silêncio ou
  /// o reconhecimento falhou). Pode ainda ser chamado mesmo depois de
  /// [aoOuvirParcial] já ter sinalizado algo que [pararEscuta] tratou como
  /// emergência — quem chama deve guardar sua própria flag para ignorar
  /// esse callback nesse caso, do mesmo jeito que `elderly_screen.dart`
  /// faz hoje com `_sosDisparado`.
  Future<bool> escutar({
    required void Function(String texto) aoReconhecerFinal,
    void Function(String textoParcial)? aoOuvirParcial,
    void Function(String mensagem)? aoErro,
  }) async {
    _capturaAtual = '';
    _finalJaEntregue = false;
    textoParcial.value = '';

    final disponivel = await _speech.initialize(
      onStatus: (status) {
        if (_descartado) return;
        final aindaOuvindo = estado.value == MollyVoiceState.listening;
        if ((status == 'done' || status == 'notListening') && aindaOuvindo) {
          _finalizarTurno(aoReconhecerFinal);
        }
      },
      onError: (erro) {
        if (_descartado) return;
        estado.value = MollyVoiceState.error;
        aoErro?.call(erro.errorMsg);
      },
    );
    if (_descartado) return false;

    if (!disponivel) {
      estado.value = MollyVoiceState.error;
      aoErro?.call('Não consegui usar o microfone agora.');
      return false;
    }

    estado.value = MollyVoiceState.listening;

    // Tempos generosos (herdados de elderly_screen.dart, TASK-31/32):
    // usuários idosos costumam falar com pausas entre palavras, e um
    // pauseFor curto corta a frase no meio.
    await _speech.listen(
      localeId: 'pt_BR',
      listenFor: const Duration(seconds: 25),
      pauseFor: const Duration(seconds: 6),
      onResult: (resultado) {
        if (_descartado) return;
        _capturaAtual = resultado.recognizedWords;
        textoParcial.value = _capturaAtual;
        aoOuvirParcial?.call(_capturaAtual);
        if (resultado.finalResult) {
          _finalizarTurno(aoReconhecerFinal);
        }
      },
    );
    return true;
  }

  Future<void> _finalizarTurno(void Function(String) aoReconhecerFinal) async {
    if (_finalJaEntregue) return;
    _finalJaEntregue = true;
    if (!_descartado && estado.value == MollyVoiceState.listening) {
      estado.value = MollyVoiceState.idle;
    }

    // Corrige uma corrida real do plugin speech_to_text (achada em teste
    // ao vivo no aparelho físico, TASK-33 da sessão 21): o status
    // "done"/"notListening" às vezes chega um instante ANTES do onResult
    // entregar a transcrição final de verdade — inclusive uma palavra
    // crítica como "SOCORRO". Uma espera curta, só quando a captura ainda
    // está vazia, dá tempo do onResult atrasado chegar (via
    // [aoOuvirParcial], synchronous, antes deste método retomar) em vez
    // de entregar uma transcrição vazia por engano.
    if (_capturaAtual.trim().isEmpty) {
      await Future<void>.delayed(const Duration(milliseconds: 400));
    }
    if (_descartado) return;
    aoReconhecerFinal(_capturaAtual);
  }

  /// Para a escuta manualmente (ex.: usuário tocou o botão de novo, ou
  /// quem chama detectou uma palavra crítica em [aoOuvirParcial] e quer
  /// agir sem esperar o resultado final).
  void pararEscuta() {
    _speech.stop();
    if (!_descartado && estado.value == MollyVoiceState.listening) {
      estado.value = MollyVoiceState.idle;
    }
  }

  /// Marca que a MOLLY está processando a resposta (entre reconhecer o
  /// texto e ter uma fala pronta) — não mexe no motor de voz, só no
  /// estado exposto para a UI.
  void marcarPensando() {
    if (_descartado) return;
    estado.value = MollyVoiceState.thinking;
  }

  /// Fala [texto] pelo TTS já existente (`VoiceService`), expondo o
  /// estado `speaking` enquanto isso acontece.
  Future<void> falar(String texto) async {
    if (texto.trim().isEmpty || _descartado) return;
    estado.value = MollyVoiceState.speaking;
    await VoiceService.speak(texto);
    if (!_descartado && estado.value == MollyVoiceState.speaking) {
      estado.value = MollyVoiceState.idle;
    }
  }

  /// Fala várias frases em sequência (ex.: resumo + um lembrete por
  /// frase, como em `MollyToolResult.falasEmSequencia`).
  Future<void> falarSequencia(List<String> textos) async {
    final validos = textos.where((t) => t.trim().isNotEmpty);
    if (validos.isEmpty || _descartado) return;
    estado.value = MollyVoiceState.speaking;
    await VoiceService.speakAll(validos);
    if (!_descartado && estado.value == MollyVoiceState.speaking) {
      estado.value = MollyVoiceState.idle;
    }
  }

  /// Interrompe a fala em andamento. Serve como primitiva para um futuro
  /// "voltar a falar interrompe a MOLLY" (barge-in) — esta classe não
  /// implementa detecção automática disso: ouvir e falar ao mesmo tempo
  /// de verdade (sem eco pegando a própria fala da MOLLY) é o problema que
  /// a TAREFA 33 do prompt mestre (voz em tempo real via LiveKit) resolve
  /// de forma adequada; forçar isso aqui em cima do `speech_to_text`
  /// clássico seria um comportamento novo, não validado em campo.
  void interromperFala() {
    VoiceService.stop();
    if (!_descartado && estado.value == MollyVoiceState.speaking) {
      estado.value = MollyVoiceState.idle;
    }
  }

  /// Libera os recursos do reconhecimento de voz. Chamar no `dispose()` de
  /// quem possui esta instância.
  ///
  /// Marca [_descartado] ANTES de liberar os `ValueNotifier`s: um `await`
  /// em [falar]/[escutar] pode retomar depois que a tela que possui esta
  /// instância já foi descartada (ex.: usuário saiu da tela no meio de uma
  /// fala) — sem essa flag, o código retomado tentava escrever em
  /// `estado.value` já descartado e derrubava a conversa com uma exceção
  /// não tratada (achado em teste ao vivo no aparelho físico).
  void dispose() {
    _descartado = true;
    _speech.stop();
    estado.dispose();
    textoParcial.dispose();
  }
}
