import 'package:flutter/foundation.dart';

import '../../../services/settings_service.dart';

/// Estado da escuta por palavra de ativação.
enum WakeWordState { idle, listening, detected, unavailable, error }

/// Ativação por voz "Molly" (TAREFA 16 do prompt mestre).
///
/// ## Pesquisa (exigida explicitamente pela tarefa): Picovoice Porcupine
///
/// O prompt mestre pede pesquisa de integração com o Porcupine, da
/// Picovoice — um motor de wake-word que roda 100% no aparelho (sem
/// internet), leve o bastante pra escutar continuamente. Achados antes
/// de decidir integrar de verdade:
///
/// 1. **"Molly" não é uma palavra-chave pronta.** As palavras-chave
///    embutidas gratuitas do Porcupine são um conjunto fixo em inglês
///    ("Porcupine", "Bumblebee", "Computer", "Jarvis", "Hey Google",
///    "Alexa", "Hey Siri" etc.) — nenhuma delas é "Molly". Seria preciso
///    treinar uma palavra-chave CUSTOM no Picovoice Console
///    (console.picovoice.ai), o que gera um arquivo `.ppn` por
///    plataforma (Android/iOS) pra empacotar como asset do app. Isso
///    exige criar uma conta Picovoice — não é só adicionar um pacote ao
///    `pubspec.yaml`.
/// 2. **Precisa de uma `AccessKey`** (gerada na mesma conta), a guardar
///    com o mesmo cuidado de outras chaves do projeto — nunca commitada,
///    mesmo padrão já usado pra `GROQ_API_KEY`.
/// 3. **Impacto de bateria não é zero.** Escuta contínua significa o
///    microfone aberto o tempo todo com uma rede neural leve rodando em
///    cima — a Picovoice descreve isso como "baixo consumo", mas "baixo"
///    ainda é mais que "nenhum". Manter isso funcionando com o app em
///    segundo plano (o caso de uso real de uma wake word) exigiria um
///    Foreground Service dedicado no Android — mesma lição já aprendida
///    na sessão 22 com o detector de queda (`SosProtectionService.kt` +
///    `FlutterEngine` headless): sem isso, o Android mata o acesso ao
///    microfone assim que o app sai de primeiro plano.
/// 4. **Indicador de microfone sempre visível.** Android 12+ e iOS
///    mostram um indicador (bolinha/ícone) sempre que o microfone está
///    em uso — um app "sempre ouvindo" deixaria esse indicador
///    permanentemente aceso, o que pode preocupar o usuário idoso (achar
///    que algo está errado) mesmo sendo um comportamento esperado.
/// 5. **Licenciamento**: Picovoice tem tier gratuito (uso pessoal/poucos
///    dispositivos ativos); uso comercial em escala pede licença paga —
///    a avaliar se/quando o app crescer além de uso familiar.
///
/// Por tudo isso — e pela orientação explícita do próprio prompt mestre
/// ("não integrar imediatamente no núcleo se houver impacto
/// significativo de bateria") — esta tarefa entrega só a abstração
/// abaixo e um feature flag desligado por padrão
/// (`SettingsService.getWakeWordEnabled`), **sem** adicionar a
/// dependência `porcupine_flutter`/`picovoice_flutter` ao
/// `pubspec.yaml`, sem `AccessKey`, sem modelo `.ppn` — nada disso existe
/// ainda no projeto. A implementação real fica bloqueada até: (a) o
/// usuário decidir criar uma conta Picovoice e treinar a palavra
/// "Molly"; (b) uma avaliação de bateria em campo, no aparelho físico de
/// referência (R9QL200MJ0N).
///
/// Enquanto isso, [criar] sempre devolve [UnavailableWakeWordService] —
/// nenhum código no app hoje liga a wake word de verdade, mesmo com a
/// flag ativada.
abstract class WakeWordService {
  ValueListenable<WakeWordState> get estado;

  /// Começa a escutar pela palavra de ativação. Devolve `false` se a
  /// wake word não estiver disponível nesta build (sempre o caso hoje).
  Future<bool> iniciar({required VoidCallback aoDetectarPalavraChave});

  Future<void> parar();

  void dispose();

  /// Cria a implementação ativa de acordo com a flag `wakeWordEnabled`.
  /// Hoje sempre devolve [UnavailableWakeWordService] — não existe
  /// implementação real ainda (ver pesquisa acima).
  static Future<WakeWordService> criar() async {
    await SettingsService.getWakeWordEnabled();
    // TODO(TAREFA 16+): quando existir uma implementação real
    // (ex.: PorcupineWakeWordService), decidir entre ela e
    // UnavailableWakeWordService de acordo com a flag lida acima.
    return UnavailableWakeWordService();
  }
}

/// Implementação padrão — sempre indisponível. Usada enquanto a
/// integração real (Porcupine) não existe.
class UnavailableWakeWordService implements WakeWordService {
  @override
  final ValueNotifier<WakeWordState> estado = ValueNotifier(WakeWordState.unavailable);

  @override
  Future<bool> iniciar({required VoidCallback aoDetectarPalavraChave}) async {
    estado.value = WakeWordState.unavailable;
    return false;
  }

  @override
  Future<void> parar() async {}

  @override
  void dispose() {
    estado.dispose();
  }
}
