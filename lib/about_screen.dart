import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';

class AboutScreen extends StatefulWidget {
  const AboutScreen({super.key});

  @override
  State<AboutScreen> createState() => _AboutScreenState();
}

class _AboutScreenState extends State<AboutScreen> {
  static const Color _primary = Color(0xFF7B5EA7);
  static const Color _danger = Color(0xFFE53935);

  String _versao = '';

  @override
  void initState() {
    super.initState();
    _carregarVersao();
  }

  Future<void> _carregarVersao() async {
    try {
      final info = await PackageInfo.fromPlatform();
      if (mounted) setState(() => _versao = info.version);
    } catch (_) {
      if (mounted) setState(() => _versao = '1.3.0');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F2F7),
      appBar: AppBar(
        title: const Text('Sobre o App'),
        backgroundColor: _primary,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF7B5EA7), Color(0xFF9C7CC7)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              children: [
                const Icon(Icons.notifications_active,
                    size: 56, color: Colors.white),
                const SizedBox(height: 12),
                const Text('Me Lembra Aí',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 26,
                        fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text(
                  _versao.isNotEmpty ? 'Versão $_versao' : 'Versão 1.3.0',
                  style: const TextStyle(color: Colors.white70, fontSize: 14),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Lembretes acessíveis para toda a família',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white70, fontSize: 13),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Manual do usuário
          _sectionLabel('MANUAL DO USUÁRIO'),
          const SizedBox(height: 8),

          _manualTile(
            icon: Icons.elderly,
            color: _primary,
            titulo: 'Perfil Melhor Idade',
            itens: [
              'Botão SOS: pressione para acionar emergência. Um contador de 5 segundos permite cancelar se acionado por engano.',
              '5 toques rápidos em qualquer lugar da tela também disparam o SOS.',
              'Criar lembrete por voz: toque em "Criar lembrete por voz" e diga o lembrete em voz alta. O app detecta data, hora e tipo automaticamente.',
              'Ouvir lembretes: toque em "Ouvir lembretes de hoje" para escutar todos os compromissos do dia.',
              'Meus Lembretes: visualize lembretes organizados por categoria (remédios, consultas, aniversários, mercado, eventos).',
              'Minha Localização: abre o mapa com sua posição atual.',
              'Meus Veículos: gerencie documentos e alertas do seu veículo.',
              'Meus Alertas SOS: veja o histórico de emergências e confirme que o familiar recebeu.',
            ],
          ),

          _manualTile(
            icon: Icons.person,
            color: const Color(0xFF4A90D9),
            titulo: 'Perfil Adulto',
            itens: [
              'Dashboard com resumo do dia: veja quantos lembretes tem hoje, próximos e já realizados.',
              'Sugestões inteligentes: o app sugere lembretes com base nos seus hábitos.',
              'Agenda do dia: todos os compromissos do dia em ordem de horário.',
              'Card de Veículos: acessa seus veículos com alerta visual quando há pendências.',
              'Histórico: acesse o ícone de relógio no cabeçalho para ver lembretes confirmados.',
            ],
          ),

          _manualTile(
            icon: Icons.child_care,
            color: const Color(0xFF43A047),
            titulo: 'Perfil Filhos',
            itens: [
              'Tarefas gamificadas: cada tarefa concluída avança a barra de progresso.',
              'O cuidador acompanha a adesão pela tela de monitoramento no perfil Família.',
            ],
          ),

          _manualTile(
            icon: Icons.family_restroom,
            color: const Color(0xFFFFB300),
            titulo: 'Perfil Família',
            itens: [
              'Vincular familiar: toque em "Adicionar" e insira o código de convite do idoso ou criança.',
              'Feed SOS: receba alertas em tempo real quando um familiar acionar o SOS.',
              'Monitoramento: veja a adesão a lembretes e histórico de alertas de cada monitorado.',
              'Chat: envie mensagens de texto ou segure o botão de microfone para gravar um áudio.',
            ],
          ),

          _manualTile(
            icon: Icons.sos,
            color: _danger,
            titulo: 'Sistema SOS',
            itens: [
              'Ao acionar o SOS, o app registra sua localização GPS, envia mensagem no chat familiar e liga automaticamente para o contato principal.',
              'Se houver mais de um contato cadastrado, um botão extra aparece para ligar para os demais.',
              'Quando o familiar abre a tela de monitoramento, o alerta é marcado como "visualizado".',
              'Configure o número de emergência em Configurações → Botão de Pânico.',
              'É possível cadastrar até 3 contatos de emergência.',
              'SOS por teclas: ative em Configurações → SOS por Teclas e pressione o volume 5 vezes seguidas.',
            ],
          ),

          _manualTile(
            icon: Icons.notifications,
            color: const Color(0xFF00897B),
            titulo: 'Lembretes',
            itens: [
              'Criar: toque no botão "+" ou use o comando de voz (perfil idoso).',
              'Categorias: Remédio, Consulta, Aniversário, Mercado, Reunião, Tomar.',
              'Repetição: único, diário ou semanal.',
              'Notificações chegam no horário agendado mesmo com o app fechado.',
              'Confirmar: marque o lembrete como feito tocando no círculo ao lado.',
              'Excluir: deslize o lembrete para a esquerda ou toque no ícone de lixeira.',
            ],
          ),

          _manualTile(
            icon: Icons.directions_car,
            color: const Color(0xFF1E88E5),
            titulo: 'Veículos',
            itens: [
              'Cadastre seus veículos com apelido, placa e informações de manutenção.',
              'Troca de óleo: informe o km atual e o intervalo. O app avisa quando estiver próximo.',
              'IPVA: registre o valor, vencimento e parcelas. Marque como pago diretamente no app.',
              'CNH: cadastre o vencimento e receba alerta com 30 dias de antecedência.',
              'Seguro: registre o valor e parcelas, acompanhe o vencimento.',
              'Ícone de alerta (laranja) aparece no card quando há pendência.',
            ],
          ),

          _manualTile(
            icon: Icons.settings,
            color: Colors.grey.shade700,
            titulo: 'Configurações',
            itens: [
              'Meu nome: defina o nome exibido para familiares.',
              'Trocar perfil: mude de perfil sem sair da conta.',
              'Número de emergência: configure até 3 contatos SOS.',
              'Modo Proteção: mantém o app ativo em segundo plano para receber alertas SOS.',
              'SOS por Teclas: pressione volume 5 vezes para disparar SOS com app aberto.',
              'Modo Escuro: alterna entre tema claro e escuro.',
              'Sair da conta: encerra a sessão atual.',
            ],
          ),

          const SizedBox(height: 24),

          // Rodapé empresa
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Column(
              children: [
                Icon(Icons.business,
                    size: 32, color: Colors.grey.shade400),
                const SizedBox(height: 10),
                Text(
                  'Copyright © 2026 HEXAGON TECNOLOGIA.\nTodos os direitos reservados.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey.shade600,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionLabel(String t) => Text(
        t,
        style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: _primary,
            letterSpacing: 1),
      );

  Widget _manualTile({
    required IconData icon,
    required Color color,
    required String titulo,
    required List<String> itens,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      elevation: 1,
      child: ExpansionTile(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        collapsedShape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        leading: CircleAvatar(
          backgroundColor: color.withOpacity(0.12),
          child: Icon(icon, color: color, size: 22),
        ),
        title: Text(titulo,
            style: const TextStyle(
                fontWeight: FontWeight.bold, fontSize: 15)),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: itens
                  .map(
                    (item) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            margin: const EdgeInsets.only(top: 6, right: 8),
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(
                              color: color,
                              shape: BoxShape.circle,
                            ),
                          ),
                          Expanded(
                            child: Text(item,
                                style: const TextStyle(
                                    fontSize: 14, height: 1.4)),
                          ),
                        ],
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),
        ],
      ),
    );
  }
}
