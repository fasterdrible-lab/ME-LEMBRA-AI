import 'package:flutter/material.dart';
import 'services/profile_service.dart';

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
  String _nomeAtual = '';

  @override
  void initState() {
    super.initState();
    _carregarNome();
  }

  Future<void> _carregarNome() async {
    final nome = await ProfileService.getNameForSelectedProfile();
    if (mounted) setState(() => _nomeAtual = nome ?? '');
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
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Configuracoes', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            const Text('Personalize o app', style: TextStyle(color: Colors.black54)),
            const SizedBox(height: 24),
            _secao('PERFIL'),
            _card(child: ListTile(
              leading: const CircleAvatar(backgroundColor: Color(0xFFEDE7F6), child: Icon(Icons.person, color: Color(0xFF7B5EA7))),
              title: const Text('Meu Perfil', style: TextStyle(fontWeight: FontWeight.w600)),
              subtitle: Text(_nomeAtual.isNotEmpty ? _nomeAtual : 'Nome, foto e informacoes'),
              trailing: const Icon(Icons.chevron_right),
              onTap: _abrirEditarNome,
            )),
            const SizedBox(height: 16),
            _secao('FUNCIONALIDADES'),
            _card(child: Column(children: [
              SwitchListTile(
                secondary: const CircleAvatar(backgroundColor: Color(0xFFE3F2FD), child: Icon(Icons.location_on, color: Color(0xFF42A5F5))),
                title: const Text('Localizacao', style: TextStyle(fontWeight: FontWeight.w600)),
                subtitle: const Text('Compartilhar localizacao com familia'),
                value: _localizacao,
                activeThumbColor: const Color(0xFF7B5EA7),
                onChanged: (v) => setState(() => _localizacao = v),
              ),
              const Divider(height: 1, indent: 70),
              SwitchListTile(
                secondary: const CircleAvatar(backgroundColor: Color(0xFFFFEBEE), child: Icon(Icons.sos, color: Color(0xFFE53935))),
                title: const Text('Botao de Panico (SOS)', style: TextStyle(fontWeight: FontWeight.w600)),
                subtitle: const Text('Enviar alerta de emergencia'),
                value: _sos,
                activeThumbColor: const Color(0xFF7B5EA7),
                onChanged: (v) => setState(() => _sos = v),
              ),
              if (_sos) Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: TextField(
                  decoration: InputDecoration(
                    hintText: 'Numero de emergencia (ex: 11999999999)',
                    prefixIcon: const Icon(Icons.phone, color: Color(0xFFE53935)),
                    filled: true, fillColor: const Color(0xFFF2F2F7),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  ),
                  keyboardType: TextInputType.phone,
                ),
              ),
              const Divider(height: 1, indent: 70),
              SwitchListTile(
                secondary: const CircleAvatar(backgroundColor: Color(0xFFE8F5E9), child: Icon(Icons.chat_bubble, color: Color(0xFF43A047))),
                title: const Text('Chat Familiar', style: TextStyle(fontWeight: FontWeight.w600)),
                subtitle: const Text('Ativar comunicacao com familia'),
                value: _chat,
                activeThumbColor: const Color(0xFF7B5EA7),
                onChanged: (v) => setState(() => _chat = v),
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
              onChanged: (v) => setState(() => _notificacoes = v),
            )),
            const SizedBox(height: 16),
            _secao('SOBRE'),
            _card(child: Column(children: [
              ListTile(
                leading: const CircleAvatar(backgroundColor: Color(0xFFEDE7F6), child: Icon(Icons.info_outline, color: Color(0xFF7B5EA7))),
                title: const Text('Sobre o App', style: TextStyle(fontWeight: FontWeight.w600)),
                subtitle: const Text('Versao 1.0.0'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {},
              ),
            ])),
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

  Widget _card({required Widget child}) => Container(
    margin: const EdgeInsets.only(bottom: 4),
    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16),
      boxShadow: [BoxShadow(blurRadius: 6, color: Colors.black.withValues(alpha: 0.04))]),
    child: child,
  );
}