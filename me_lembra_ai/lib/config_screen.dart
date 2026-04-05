import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
  final TextEditingController _nomeController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _carregarNome();
  }

  Future<void> _carregarNome() async {
    final prefs = await SharedPreferences.getInstance();
    final nome = prefs.getString('user_name') ?? '';
    setState(() => _nomeController.text = nome);
  }

  Future<void> _salvarNome() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user_name', _nomeController.text.trim());
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Nome salvo!'), duration: Duration(seconds: 2)),
    );
  }

  @override
  void dispose() {
    _nomeController.dispose();
    super.dispose();
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
            _card(child: Column(
              children: [
                ListTile(
                  leading: const CircleAvatar(backgroundColor: Color(0xFFEDE7F6), child: Icon(Icons.person, color: Color(0xFF1565C0))),
                  title: const Text('Meu Perfil', style: TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: const Text('Nome, foto e informacoes'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {},
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _nomeController,
                          decoration: InputDecoration(
                            hintText: 'Seu nome (ex: Andre)',
                            prefixIcon: const Icon(Icons.badge_outlined, color: Color(0xFF1565C0)),
                            filled: true,
                            fillColor: const Color(0xFFF2F2F7),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                          ),
                          textCapitalization: TextCapitalization.words,
                          onSubmitted: (_) => _salvarNome(),
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1565C0),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        ),
                        onPressed: _salvarNome,
                        child: const Text('Salvar'),
                      ),
                    ],
                  ),
                ),
              ],
            )),
            const SizedBox(height: 16),
            _secao('FUNCIONALIDADES'),
            _card(child: Column(children: [
              SwitchListTile(
                secondary: const CircleAvatar(backgroundColor: Color(0xFFE3F2FD), child: Icon(Icons.location_on, color: Color(0xFF42A5F5))),
                title: const Text('Localizacao', style: TextStyle(fontWeight: FontWeight.w600)),
                subtitle: const Text('Compartilhar localizacao com familia'),
                value: _localizacao,
                activeColor: const Color(0xFF1565C0),
                onChanged: (v) => setState(() => _localizacao = v),
              ),
              const Divider(height: 1, indent: 70),
              SwitchListTile(
                secondary: const CircleAvatar(backgroundColor: Color(0xFFFFEBEE), child: Icon(Icons.sos, color: Color(0xFFE53935))),
                title: const Text('Botao de Panico (SOS)', style: TextStyle(fontWeight: FontWeight.w600)),
                subtitle: const Text('Enviar alerta de emergencia'),
                value: _sos,
                activeColor: const Color(0xFF1565C0),
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
                activeColor: const Color(0xFF1565C0),
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
              activeColor: const Color(0xFF1565C0),
              onChanged: (v) => setState(() => _notificacoes = v),
            )),
            const SizedBox(height: 16),
            _secao('SOBRE'),
            _card(child: Column(children: [
              ListTile(
                leading: const CircleAvatar(backgroundColor: Color(0xFFEDE7F6), child: Icon(Icons.info_outline, color: Color(0xFF1565C0))),
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
    child: Text(t, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF1565C0), letterSpacing: 1)),
  );

  Widget _card({required Widget child}) => Container(
    margin: const EdgeInsets.only(bottom: 4),
    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16),
      boxShadow: [BoxShadow(blurRadius: 6, color: Colors.black.withOpacity(0.04))]),
    child: child,
  );
}