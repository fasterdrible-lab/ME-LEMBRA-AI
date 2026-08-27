/// Sinais locais de intenção (TAREFA 14 — "comandos naturais" — e
/// TAREFA 15 — "Modo Companhia" — do prompt mestre).
///
/// Isto é um SINAL, não um classificador completo nem uma substituição
/// da IA — a Groq (via `AiCommandService`) já lida bem com variação de
/// linguagem natural hoje, é o caminho principal. `MollyIntentHints`
/// serve para duas coisas:
///
/// 1. Documentar, com teste automatizado (`test/molly_intent_test.dart`),
///    que as frases de exemplo do prompt mestre — e variações razoáveis
///    — são reconhecidas de forma determinística, sem depender de rede.
/// 2. Servir de base para a TAREFA 17 (`OfflineIntentService`): quando os
///    parsers de data/hora forem extraídos de `elderly_screen.dart`, é
///    aqui que a checagem "isso parece um pedido de lembrete?" vai
///    morar. Por ora, nada no app chama [pareceCriarLembrete] pra tomar
///    nenhuma decisão — não há ainda um caminho local de criar lembrete
///    sem IA no módulo novo da MOLLY (`MollyAgentService`), só o antigo
///    em `elderly_screen.dart`.
///
/// Por ser só um sinal (não decide nada crítico sozinho), a lista de
/// gatilhos é propositalmente ampla — prefere reconhecer demais
/// (recall) a deixar passar uma frase válida (precisão não é o objetivo
/// aqui).
class MollyIntentHints {
  static const List<String> _gatilhosCriarLembrete = [
    'me lembra',
    'lembra de',
    'lembrar de',
    'coloca um lembrete',
    'colocar um lembrete',
    'cria um lembrete',
    'criar um lembrete',
    'não deixa eu esquecer',
    'nao deixa eu esquecer',
    'não me deixa esquecer',
    'nao me deixa esquecer',
    'preciso',
    'tenho que',
    'tenho de',
  ];

  /// `true` se [texto] parece um pedido de criar lembrete — reconhece as
  /// quatro frases de exemplo do prompt mestre e variações próximas.
  static bool pareceCriarLembrete(String texto) {
    final t = texto.toLowerCase();
    return _gatilhosCriarLembrete.any(t.contains);
  }

  /// Sinais de que o usuário pode estar buscando companhia/conversa —
  /// TAREFA 15 (Modo Companhia): conversar, dizer que está sozinho, pedir
  /// uma história, pedir algo bom pra ouvir, ou querer falar com um
  /// familiar. Mesmo espírito de [pareceCriarLembrete]: um sinal, não uma
  /// decisão — hoje nada no app usa isso pra pular a IA ou mudar
  /// comportamento sozinho; é a mesma disciplina de "sinal local
  /// documentado e testado, integração vem depois" já usada na TAREFA 14.
  static const List<String> _gatilhosCompanhia = [
    'converse comigo',
    'conversa comigo',
    'estou sozinho',
    'estou sozinha',
    'conte uma história',
    'conta uma historia',
    'conta uma história',
    'me fale alguma coisa boa',
    'fala alguma coisa boa',
    'quero conversar',
    'preciso de companhia',
    'quero falar com',
  ];

  /// `true` se [texto] parece um pedido de companhia/conversa — reconhece
  /// as cinco frases de exemplo do prompt mestre e variações próximas.
  static bool pareceBuscarCompanhia(String texto) {
    final t = texto.toLowerCase();
    return _gatilhosCompanhia.any(t.contains);
  }
}
