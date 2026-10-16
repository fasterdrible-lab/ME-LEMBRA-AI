import 'package:flutter/material.dart';

import '../../../services/notification_service.dart';
import '../../../services/profile_service.dart';
import '../../../services/settings_service.dart';
import '../../../services/voice_service.dart';

/// Configurações da Molly (TAREFA 24 do prompt mestre). Rota
/// `/molly-settings`, aberta por Configurações → "Configurações da Molly".
///
/// Reúne num lugar só opções que já existiam no código sem tela (memória,
/// modo companhia) e as novas da tarefa. Cada interruptor grava na hora em
/// `SettingsService` — sem botão "Salvar", menos passos pra quem é 60+.
///
/// "Wake word 'Molly'" (pedida na tarefa) fica de fora de propósito: a
/// implementação real não existe ainda (ver `wake_word_service.dart`) e um
/// interruptor que não faz nada confunde mais do que ajuda.
class MollySettingsScreen extends StatefulWidget {
  const MollySettingsScreen({super.key});

  @override
  State<MollySettingsScreen> createState() => _MollySettingsScreenState();
}

class _MollySettingsScreenState extends State<MollySettingsScreen> {
  static const Color _corPrimaria = Color(0xFF7B5EA7);

  bool _carregando = true;
  bool _ativa = true;
  bool _respostaPorVoz = true;
  bool _interromperPorVoz = true;
  bool _vozLenta = false;
  bool _memoria = false;
  bool _companhia = false;
  bool _avisos = true;
  bool _briefing = true;
  bool _avisarFamilia = false;

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  Future<void> _carregar() async {
    final valores = await Future.wait([
      SettingsService.getMollyAtiva(),
      SettingsService.getMollyRespostaPorVoz(),
      SettingsService.getVozLenta(),
      SettingsService.getMollyMemoriaAutorizada(),
      SettingsService.getMollyModoCompanhia(),
      SettingsService.getMollyAvisosProativos(),
      SettingsService.getBriefingDiario(),
      SettingsService.getAvisarFamiliaRemedio(),
      SettingsService.getMollyInterromperPorVoz(),
    ]);
    if (!mounted) return;
    setState(() {
      _ativa = valores[0];
      _respostaPorVoz = valores[1];
      _vozLenta = valores[2];
      _memoria = valores[3];
      _companhia = valores[4];
      _avisos = valores[5];
      _briefing = valores[6];
      _avisarFamilia = valores[7];
      _interromperPorVoz = valores[8];
      _carregando = false;
    });
  }

  Future<void> _mudarVelocidade(bool lenta) async {
    setState(() => _vozLenta = lenta);
    await SettingsService.setVozLenta(lenta);
    await VoiceService.aplicarVelocidade(lenta: lenta);
    // Exemplo na hora, pra pessoa ouvir a diferença.
    await VoiceService.speak(lenta ? 'Assim fica mais devagar.' : 'Assim é a velocidade normal.');
  }

  Future<void> _mudarBriefing(bool v) async {
    setState(() => _briefing = v);
    await SettingsService.setBriefingDiario(v);
    await NotificationService.scheduleMorningBriefing(); // agenda ou cancela
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F4FB),
      appBar: AppBar(
        title: const Text('Configurações da Molly', style: TextStyle(fontSize: 22)),
        backgroundColor: _corPrimaria,
        foregroundColor: Colors.white,
      ),
      body: _carregando
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _cartao(_interruptor(
                  titulo: 'Molly ativa',
                  ligado: 'O botão "Assistente Molly" aparece na tela principal.',
                  desligado: 'O botão "Assistente Molly" fica escondido.',
                  valor: _ativa,
                  aoMudar: (v) {
                    setState(() => _ativa = v);
                    SettingsService.setMollyAtiva(v);
                  },
                )),
                _titulo('Voz'),
                _cartao(Column(children: [
                  _interruptor(
                    titulo: 'Resposta por voz',
                    ligado: 'A Molly fala as respostas em voz alta.',
                    desligado: 'A Molly só mostra as respostas escritas.',
                    valor: _respostaPorVoz,
                    aoMudar: (v) {
                      setState(() => _respostaPorVoz = v);
                      SettingsService.setMollyRespostaPorVoz(v);
                    },
                  ),
                  const Divider(height: 1),
                  _interruptor(
                    titulo: 'Interromper falando',
                    ligado: 'Se você falar enquanto a Molly fala, ela para e escuta você.',
                    desligado: 'Para interromper a Molly, toque no microfone.',
                    valor: _interromperPorVoz,
                    aoMudar: (v) {
                      setState(() => _interromperPorVoz = v);
                      SettingsService.setMollyInterromperPorVoz(v);
                    },
                  ),
                  const Divider(height: 1),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Velocidade da voz',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 4),
                        const Text('Vale para todas as falas do aplicativo.',
                            style: TextStyle(fontSize: 14, color: Colors.black54)),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: SegmentedButton<bool>(
                            segments: const [
                              ButtonSegment(value: true, label: Text('Lenta', style: TextStyle(fontSize: 18))),
                              ButtonSegment(value: false, label: Text('Normal', style: TextStyle(fontSize: 18))),
                            ],
                            selected: {_vozLenta},
                            showSelectedIcon: false,
                            onSelectionChanged: (s) => _mudarVelocidade(s.first),
                            style: ButtonStyle(
                              minimumSize: WidgetStateProperty.all(const Size(0, 52)),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ])),
                _titulo('Conversa'),
                _cartao(Column(children: [
                  _interruptor(
                    titulo: 'Memória',
                    ligado: 'A Molly pode lembrar suas preferências, sempre perguntando antes.',
                    desligado: 'A Molly não guarda nada de novo sobre você.',
                    valor: _memoria,
                    aoMudar: (v) {
                      setState(() => _memoria = v);
                      SettingsService.setMollyMemoriaAutorizada(v);
                    },
                  ),
                  ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                    title: const Text('Ver o que a Molly lembra', style: TextStyle(fontSize: 17)),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => Navigator.pushNamed(context, '/molly-memory').then((_) => _carregar()),
                  ),
                  const Divider(height: 1),
                  _interruptor(
                    titulo: 'Modo companhia',
                    ligado: 'A Molly conversa com mais calma e pode contar histórias curtas.',
                    desligado: 'A Molly responde de forma curta e objetiva.',
                    valor: _companhia,
                    aoMudar: (v) {
                      setState(() => _companhia = v);
                      SettingsService.setMollyModoCompanhia(v);
                    },
                  ),
                ])),
                _titulo('Avisos'),
                _cartao(Column(children: [
                  _interruptor(
                    titulo: 'Avisos da Molly',
                    ligado: '15 minutos depois do horário do remédio, a Molly pergunta se você tomou.',
                    desligado: 'A Molly só fala quando você pede.',
                    valor: _avisos,
                    aoMudar: (v) {
                      setState(() => _avisos = v);
                      SettingsService.setMollyAvisosProativos(v);
                      // Desligou: some com as perguntas já agendadas.
                      if (!v) NotificationService.cancelarAcompanhamentosDeRemedio();
                    },
                  ),
                  const Divider(height: 1),
                  _interruptor(
                    titulo: 'Avisar minha família sobre o remédio',
                    ligado: 'Se o remédio não for confirmado em 1 hora, quem acompanha seus lembretes recebe um aviso.',
                    desligado: 'Sua família não recebe aviso quando o remédio não é confirmado.',
                    valor: _avisarFamilia,
                    aoMudar: (v) {
                      setState(() => _avisarFamilia = v);
                      SettingsService.setAvisarFamiliaRemedio(v);
                      ProfileService.setAvisarFamiliaRemedio(v);
                    },
                  ),
                  const Divider(height: 1),
                  _interruptor(
                    titulo: 'Bom dia às 8h',
                    ligado: 'Todo dia às 8h chega um aviso com o resumo do seu dia.',
                    desligado: 'Sem aviso de bom dia.',
                    valor: _briefing,
                    aoMudar: _mudarBriefing,
                  ),
                ])),
                const SizedBox(height: 16),
                const Text(
                  'O SOS e a palavra "socorro" funcionam sempre, com qualquer uma dessas opções.',
                  style: TextStyle(fontSize: 15, color: Colors.black54),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
    );
  }

  Widget _titulo(String t) => Padding(
        padding: const EdgeInsets.fromLTRB(4, 20, 4, 8),
        child: Text(t, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
      );

  Widget _cartao(Widget filho) => Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        clipBehavior: Clip.antiAlias,
        child: filho,
      );

  Widget _interruptor({
    required String titulo,
    required String ligado,
    required String desligado,
    required bool valor,
    required ValueChanged<bool> aoMudar,
  }) {
    return SwitchListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      title: Text(titulo, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
      subtitle: Text(valor ? ligado : desligado, style: const TextStyle(fontSize: 15)),
      value: valor,
      activeThumbColor: _corPrimaria,
      onChanged: aoMudar,
    );
  }
}
