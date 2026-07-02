import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'about_screen.dart';
import 'services/profile_service.dart';
import 'services/settings_service.dart';
import 'services/sos_protection_service.dart';
import 'services/volume_sos_service.dart';
import 'main.dart' show themeModeNotifier;

class ConfigScreen extends StatefulWidget {
  const ConfigScreen({super.key});
  @override
  State<ConfigScreen> createState() => _ConfigScreenState();
}

class _ConfigScreenState extends State<ConfigScreen> {
  bool _localizacao = false;
  bool _sos = false;
  bool _chat = false;
  bool _notificacoes = true;
  bool _modoEscuro = false;
  bool _modoProtecao = false;
  bool _volumeSos = false;
  String _nomeAtual = '';
  String _versao = '';
  List<TextEditingController> _sosCtrls = [];
  bool _carregado = false;

  @override
  void initState() {
    super.initState();
    _carregarNome();
    _carregarConfig();
    _carregarVersao();
  }

  Future<void> _carregarVersao() async {
    try {
      final info = await PackageInfo.fromPlatform();
      if (mounted) setState(() => _versao = 'v${info.version}');
    } catch (_) {
      if (mounted) setState(() => _versao = 'v1.2.0');
    }
  }

  @override
  void dispose() {
    for (final c in _sosCtrls) c.dispose();
    super.dispose();
  }

  Future<void> _carregarConfig() async {
    final loc = await SettingsService.getLocalizacao();
    final sos = await SettingsService.getSos();
    final chat = await SettingsService.getChat();
    final notif = await SettingsService.getNotificacoes();
    final numeros = await SettingsService.getSosNumeros();
    final escuro = await SettingsService.getModoEscuro();
    final protecao = await SettingsService.getModoProtecao();
    final volSos = await SettingsService.getVolumeSos();
    if (!mounted) return;
    for (final c in _sosCtrls) c.dispose();
    setState(() {
      _localizacao = loc;
      _sos = sos;
      _chat = chat;
      _notificacoes = notif;
      _modoEscuro = escuro;
      _modoProtecao = protecao;
      _volumeSos = volSos;
      _sosCtrls = numeros.isNotEmpty
          ? numeros.map((n) => TextEditingController(text: n)).toList()
          : [TextEditingController()];
      _carregado = true;
    });
  }

  Future<void> _salvarNumeros() async {
    final numeros = _sosCtrls
        .map((c) => c.text.trim())
        .where((n) => n.isNotEmpty)
        .toList();
    await SettingsService.setSosNumeros(numeros);
  }

  /// Um número de telefone brasileiro válido tem DDD + número
  /// (10 ou 11 dígitos, ou 12-13 com código do país). Menos que isso
  /// quase sempre significa que o DDD foi esquecido — a ligação falha
  /// silenciosamente tanto pelo app quanto ao ser rediscada manualmente.
  bool _numeroIncompleto(String texto) {
    if (texto.trim().isEmpty) return false;
    final digitos = texto.replaceAll(RegExp(r'[^\d]'), '');
    return digitos.length < 10;
  }

  void _aviso(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), duration: const Duration(seconds: 1)),
    );
  }

  Future<void> _carregarNome() async {
    final nome = await ProfileService.getNameForSelectedProfile();
    if (mounted) setState(() => _nomeAtual = nome ?? '');
  }

  Future<void> _trocarPerfil() async {
    final perfilAtual = await ProfileService.getProfile();
    if (!mounted) return;

    final opcoes = [
      {'label': 'Vovô / Vovó', 'icon': Icons.elderly, 'cor': const Color(0xFF7B5EA7), 'rota': '/elderly'},
      {'label': 'Adulto', 'icon': Icons.person, 'cor': const Color(0xFF42A5F5), 'rota': '/adult'},
      {'label': 'Filhos', 'icon': Icons.child_care, 'cor': const Color(0xFF66BB6A), 'rota': '/child'},
      {'label': 'Família', 'icon': Icons.family_restroom, 'cor': const Color(0xFFFFB300), 'rota': '/family'},
    ];

    await showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40, height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text('Trocar perfil', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            const Text('Selecione o perfil para continuar', style: TextStyle(color: Colors.grey)),
            const SizedBox(height: 16),
            ...opcoes.map((op) {
              final selecionado = perfilAtual == op['label'];
              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: (op['cor'] as Color).withOpacity(0.15),
                  child: Icon(op['icon'] as IconData, color: op['cor'] as Color),
                ),
                title: Text(
                  op['label'] as String,
                  style: TextStyle(
                    fontWeight: selecionado ? FontWeight.bold : FontWeight.normal,
                    color: selecionado ? const Color(0xFF7B5EA7) : null,
                  ),
                ),
                trailing: selecionado ? const Icon(Icons.check_circle, color: Color(0xFF7B5EA7)) : null,
                onTap: () async {
                  Navigator.pop(ctx);
                  await ProfileService.saveProfile(op['label'] as String);
                  if (mounted) {
                    Navigator.of(context).pushNamedAndRemoveUntil(
                      op['rota'] as String,
                      (route) => false,
                    );
                  }
                },
              );
            }),
          ],
        ),
      ),
    );
  }

  Future<void> _abrirEditarNome() async {
    final perfil = await ProfileService.getProfile();
    if (perfil == null) return;
    final controller = TextEditingController(text: _nomeAtual);
    if (!mounted) return;
    final resultado = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Alterar nome'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Seu nome'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF7B5EA7),
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Salvar'),
          ),
        ],
      ),
    );
    if (resultado != null && resultado.isNotEmpty) {
      await ProfileService.saveNameForProfile(perfil, resultado);
      if (mounted) setState(() => _nomeAtual = resultado);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_carregado) {
      return const SafeArea(child: Center(child: CircularProgressIndicator()));
    }
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Configuracoes', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            const Text('Personalize o app'),
            const SizedBox(height: 24),
            _secao('PERFIL'),
            _card(child: Column(children: [
              ListTile(
                leading: const CircleAvatar(backgroundColor: Color(0xFFEDE7F6), child: Icon(Icons.person, color: Color(0xFF7B5EA7))),
                title: const Text('Meu nome', style: TextStyle(fontWeight: FontWeight.w600)),
                subtitle: Text(_nomeAtual.isNotEmpty ? _nomeAtual : 'Toque para definir seu nome'),
                trailing: const Icon(Icons.chevron_right),
                onTap: _abrirEditarNome,
              ),
              const Divider(height: 1, indent: 70),
              ListTile(
                leading: const CircleAvatar(backgroundColor: Color(0xFFEDE7F6), child: Icon(Icons.swap_horiz, color: Color(0xFF7B5EA7))),
                title: const Text('Trocar perfil', style: TextStyle(fontWeight: FontWeight.w600)),
                subtitle: const Text('Mudar para outro perfil sem sair'),
                trailing: const Icon(Icons.chevron_right),
                onTap: _trocarPerfil,
              ),
            ])),
            const SizedBox(height: 16),
            _secao('FUNCIONALIDADES'),
            _card(child: Column(children: [
              SwitchListTile(
                secondary: const CircleAvatar(backgroundColor: Color(0xFFE3F2FD), child: Icon(Icons.location_on, color: Color(0xFF42A5F5))),
                title: const Text('Localizacao', style: TextStyle(fontWeight: FontWeight.w600)),
                subtitle: const Text('Compartilhar localizacao com familia'),
                value: _localizacao,
                activeThumbColor: const Color(0xFF7B5EA7),
                onChanged: (v) async {
                  setState(() => _localizacao = v);
                  await SettingsService.setLocalizacao(v);
                  _aviso(v ? 'Localização ativada' : 'Localização desativada');
                },
              ),
              const Divider(height: 1, indent: 70),
              SwitchListTile(
                secondary: const CircleAvatar(backgroundColor: Color(0xFFFFEBEE), child: Icon(Icons.sos, color: Color(0xFFE53935))),
                title: const Text('Botao de Panico (SOS)', style: TextStyle(fontWeight: FontWeight.w600)),
                subtitle: const Text('Enviar alerta de emergencia'),
                value: _sos,
                activeThumbColor: const Color(0xFF7B5EA7),
                onChanged: (v) async {
                  setState(() => _sos = v);
                  await SettingsService.setSos(v);
                  _aviso(v ? 'SOS ativado' : 'SOS desativado');
                },
              ),
              if (_sos) Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ..._sosCtrls.asMap().entries.map((e) {
                      final idx = e.key;
                      final ctrl = e.value;
                      final incompleto = _numeroIncompleto(ctrl.text);
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: TextField(
                                    controller: ctrl,
                                    onChanged: (_) {
                                      _salvarNumeros();
                                      setState(() {});
                                    },
                                    decoration: InputDecoration(
                                      hintText: idx == 0
                                          ? 'Contato principal (ex: 11999999999)'
                                          : 'Contato ${idx + 1} (ex: 11998888888)',
                                      prefixIcon: const Icon(Icons.phone, color: Color(0xFFE53935)),
                                      filled: true,
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide: BorderSide.none,
                                      ),
                                    ),
                                    keyboardType: TextInputType.phone,
                                  ),
                                ),
                                if (_sosCtrls.length > 1)
                                  IconButton(
                                    icon: const Icon(Icons.remove_circle_outline, color: Color(0xFFE53935)),
                                    tooltip: 'Remover',
                                    onPressed: () {
                                      _sosCtrls[idx].dispose();
                                      setState(() => _sosCtrls.removeAt(idx));
                                      _salvarNumeros();
                                    },
                                  ),
                              ],
                            ),
                            if (incompleto)
                              const Padding(
                                padding: EdgeInsets.only(left: 12, top: 2),
                                child: Text(
                                  'Número incompleto — inclua o DDD (ex: 11999999999). '
                                  'Sem o DDD a ligação de emergência falha.',
                                  style: TextStyle(color: Color(0xFFE53935), fontSize: 12),
                                ),
                              ),
                          ],
                        ),
                      );
                    }),
                    if (_sosCtrls.length < 3)
                      TextButton.icon(
                        icon: const Icon(Icons.add, size: 18),
                        label: const Text('Adicionar contato'),
                        style: TextButton.styleFrom(foregroundColor: const Color(0xFF7B5EA7)),
                        onPressed: () {
                          setState(() => _sosCtrls.add(TextEditingController()));
                        },
                      ),
                  ],
                ),
              ),
              const Divider(height: 1, indent: 70),
              SwitchListTile(
                secondary: const CircleAvatar(backgroundColor: Color(0xFFE8F5E9), child: Icon(Icons.chat_bubble, color: Color(0xFF43A047))),
                title: const Text('Chat Familiar', style: TextStyle(fontWeight: FontWeight.w600)),
                subtitle: const Text('Ativar comunicacao com familia'),
                value: _chat,
                activeThumbColor: const Color(0xFF7B5EA7),
                onChanged: (v) async {
                  setState(() => _chat = v);
                  await SettingsService.setChat(v);
                  _aviso(v ? 'Chat familiar ativado' : 'Chat familiar desativado');
                },
              ),
              const Divider(height: 1, indent: 70),
              SwitchListTile(
                secondary: const CircleAvatar(
                  backgroundColor: Color(0xFFF3E5F5),
                  child: Icon(Icons.shield, color: Color(0xFF7B5EA7)),
                ),
                title: const Text('Modo Protecao', style: TextStyle(fontWeight: FontWeight.w600)),
                subtitle: const Text('Manter SOS ativo mesmo com app fechado'),
                value: _modoProtecao,
                activeThumbColor: const Color(0xFF7B5EA7),
                onChanged: (v) async {
                  setState(() => _modoProtecao = v);
                  if (v) {
                    await SosProtectionService.start();
                    _aviso('Modo protecao ativado');
                  } else {
                    await SosProtectionService.stop();
                    _aviso('Modo protecao desativado');
                  }
                },
              ),
              const Divider(height: 1, indent: 70),
              SwitchListTile(
                secondary: const CircleAvatar(
                  backgroundColor: Color(0xFFE8F5E9),
                  child: Icon(Icons.volume_up, color: Color(0xFF43A047)),
                ),
                title: const Text('SOS por Teclas', style: TextStyle(fontWeight: FontWeight.w600)),
                subtitle: const Text('Pressionar volume 5x dispara SOS (app aberto)'),
                value: _volumeSos,
                activeThumbColor: const Color(0xFF7B5EA7),
                onChanged: (v) async {
                  setState(() => _volumeSos = v);
                  if (v) {
                    await VolumeSosService.start();
                    _aviso('SOS por teclas ativado');
                  } else {
                    await VolumeSosService.stop();
                    _aviso('SOS por teclas desativado');
                  }
                },
              ),
              const Divider(height: 1, indent: 70),
              ListTile(
                leading: const CircleAvatar(
                  backgroundColor: Color(0xFFE3F2FD),
                  child: Icon(Icons.map, color: Color(0xFF1E88E5)),
                ),
                title: const Text('Minha Localizacao', style: TextStyle(fontWeight: FontWeight.w600)),
                subtitle: const Text('Ver mapa e compartilhar localizacao no SOS'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.pushNamed(context, '/map'),
              ),
            ])),
            const SizedBox(height: 16),
            _secao('NOTIFICACOES'),
            _card(child: SwitchListTile(
              secondary: const CircleAvatar(backgroundColor: Color(0xFFFFF3E0), child: Icon(Icons.notifications, color: Color(0xFFFFB300))),
              title: const Text('Notificacoes', style: TextStyle(fontWeight: FontWeight.w600)),
              subtitle: const Text('Receber alertas de lembretes'),
              value: _notificacoes,
              activeThumbColor: const Color(0xFF7B5EA7),
              onChanged: (v) async {
                setState(() => _notificacoes = v);
                await SettingsService.setNotificacoes(v);
                _aviso(v ? 'Notificações ativadas' : 'Notificações desativadas');
              },
            )),
            const SizedBox(height: 16),
            _secao('APARENCIA'),
            _card(child: SwitchListTile(
              secondary: const CircleAvatar(backgroundColor: Color(0xFF263238), child: Icon(Icons.dark_mode, color: Colors.white)),
              title: const Text('Modo Escuro', style: TextStyle(fontWeight: FontWeight.w600)),
              subtitle: const Text('Interface com tema escuro'),
              value: _modoEscuro,
              activeThumbColor: const Color(0xFF7B5EA7),
              onChanged: (v) async {
                setState(() => _modoEscuro = v);
                await SettingsService.setModoEscuro(v);
                themeModeNotifier.value = v ? ThemeMode.dark : ThemeMode.light;
                _aviso(v ? 'Modo escuro ativado' : 'Modo escuro desativado');
              },
            )),
            const SizedBox(height: 16),
            _secao('SOBRE'),
            _card(child: Column(children: [
              ListTile(
                leading: const CircleAvatar(backgroundColor: Color(0xFFEDE7F6), child: Icon(Icons.info_outline, color: Color(0xFF7B5EA7))),
                title: const Text('Sobre o App', style: TextStyle(fontWeight: FontWeight.w600)),
                subtitle: Text(_versao.isNotEmpty ? _versao : 'v1.3.0'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const AboutScreen()),
                ),
              ),
            ])),
            const SizedBox(height: 16),
            _secao('CONTA'),
            _card(child: ListTile(
              leading: const CircleAvatar(
                backgroundColor: Color(0xFFFFEBEE),
                child: Icon(Icons.logout, color: Color(0xFFE53935)),
              ),
              title: const Text('Sair da conta', style: TextStyle(fontWeight: FontWeight.w600, color: Color(0xFFE53935))),
              subtitle: const Text('Encerrar sessão atual'),
              onTap: () async {
                final confirmar = await showDialog<bool>(
                  context: context,
                  builder: (_) => AlertDialog(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    title: const Text('Sair da conta'),
                    content: const Text('Tem certeza que deseja sair?'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text('Cancelar'),
                      ),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFE53935),
                          foregroundColor: Colors.white,
                        ),
                        onPressed: () => Navigator.pop(context, true),
                        child: const Text('Sair'),
                      ),
                    ],
                  ),
                );
                if (confirmar == true) {
                  await FirebaseAuth.instance.signOut();
                  if (mounted) {
                    Navigator.of(context)
                        .pushNamedAndRemoveUntil('/', (route) => false);
                  }
                }
              },
            )),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  Widget _secao(String t) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(t, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF7B5EA7), letterSpacing: 1)),
  );

  Widget _card({required Widget child}) => Builder(
    builder: (ctx) => Container(
      margin: const EdgeInsets.only(bottom: 4),
      decoration: BoxDecoration(
        color: Theme.of(ctx).cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(blurRadius: 6, color: Colors.black.withOpacity(0.04))],
      ),
      child: child,
    ),
  );
}