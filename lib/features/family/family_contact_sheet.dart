import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../models/family_member.dart';
import '../../services/family_service.dart';
import 'chat_screen.dart';

/// Bottom sheet "Chat Familiar" — lista membros e oferece três ações:
/// Ligar / Mensagem / Áudio (WhatsApp).
class FamilyContactSheet extends StatelessWidget {
  const FamilyContactSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => const FamilyContactSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scroll) {
        return Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Chat Familiar',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                'Escolha um familiar e a forma de contato',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, color: Colors.black54),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: StreamBuilder<List<FamilyMember>>(
                  stream: FamilyService.stream(),
                  builder: (context, snap) {
                    if (snap.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    final lista = snap.data ?? const <FamilyMember>[];
                    if (lista.isEmpty) {
                      return const Center(
                        child: Text(
                          'Você ainda não tem familiares vinculados.\nAdicione na tela "Família".',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 18, color: Colors.black54),
                        ),
                      );
                    }
                    return ListView.separated(
                      controller: scroll,
                      itemCount: lista.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (_, i) => _MemberCard(member: lista[i]),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _MemberCard extends StatelessWidget {
  final FamilyMember member;
  const _MemberCard({required this.member});

  static String _phoneKey(String uid) => 'family_phone_$uid';

  Future<String?> _getPhone() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_phoneKey(member.uid));
  }

  Future<void> _setPhone(String phone) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_phoneKey(member.uid), phone);
  }

  Future<String?> _ensurePhone(BuildContext context) async {
    final existing = await _getPhone();
    if (existing != null && existing.isNotEmpty) return existing;
    if (!context.mounted) return null;
    final ctrl = TextEditingController();
    final ok = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Telefone de ${member.nome}'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          keyboardType: TextInputType.phone,
          decoration: const InputDecoration(
            hintText: 'Ex.: 11999999999 (DDD + número)',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, ctrl.text.trim()),
            child: const Text('Salvar'),
          ),
        ],
      ),
    );
    if (ok == null || ok.isEmpty) return null;
    await _setPhone(ok);
    return ok;
  }

  String _digits(String raw) => raw.replaceAll(RegExp(r'[^0-9]'), '');

  Future<void> _ligar(BuildContext context) async {
    final phone = await _ensurePhone(context);
    if (phone == null) return;
    final uri = Uri.parse('tel:${_digits(phone)}');
    await launchUrl(uri);
  }

  Future<void> _mensagem(BuildContext context) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => ChatScreen(member: member)),
    );
  }

  Future<void> _audio(BuildContext context) async {
    // Abre o chat interno; o usuário toca no ícone de microfone lá para gravar.
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => ChatScreen(member: member)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFEDE7F6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const CircleAvatar(
                radius: 26,
                backgroundColor: Color(0xFFEDE7F6),
                child: Icon(Icons.person, size: 30, color: Color(0xFF7B5EA7)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  member.nome,
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _acaoBtn(
                  icon: Icons.call,
                  label: 'Ligar',
                  color: const Color(0xFF43A047),
                  onTap: () => _ligar(context),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _acaoBtn(
                  icon: Icons.chat_bubble,
                  label: 'Mensagem',
                  color: const Color(0xFF4A90D9),
                  onTap: () => _mensagem(context),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _acaoBtn(
                  icon: Icons.mic,
                  label: 'Áudio',
                  color: const Color(0xFF7B5EA7),
                  onTap: () => _audio(context),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _acaoBtn({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return ElevatedButton(
      onPressed: onTap,
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 28),
          const SizedBox(height: 4),
          Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
