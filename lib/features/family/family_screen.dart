import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../models/family_member.dart';
import '../../services/family_service.dart';
import 'monitor_screen.dart';
import 'chat_screen.dart';

class FamilyScreen extends StatefulWidget {
  const FamilyScreen({super.key});

  @override
  State<FamilyScreen> createState() => _FamilyScreenState();
}

class _FamilyScreenState extends State<FamilyScreen> {
  String? _myCode;
  bool _loadingCode = false;
  String? _codeError;
  final TextEditingController _codeCtrl = TextEditingController();
  bool _linking = false;

  @override
  void initState() {
    super.initState();
    _loadCode();
  }

  Future<void> _loadCode() async {
    setState(() {
      _loadingCode = true;
      _codeError = null;
    });
    try {
      final c = await FamilyService.getOrCreateInviteCode();
      if (mounted) setState(() => _myCode = c);
    } catch (e) {
      if (mounted) setState(() => _codeError = e.toString());
    } finally {
      if (mounted) setState(() => _loadingCode = false);
    }
  }

  Future<void> _link() async {
    setState(() => _linking = true);
    try {
      final m = await FamilyService.linkWithCode(_codeCtrl.text);
      if (!mounted) return;
      _codeCtrl.clear();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Vinculado a ${m.nome}.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro: $e')),
      );
    } finally {
      if (mounted) setState(() => _linking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Família'),
        backgroundColor: const Color(0xFF4A90D9),
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _myCodeCard(),
          const SizedBox(height: 16),
          _linkCard(),
          const SizedBox(height: 16),
          const Text('Vínculos',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          StreamBuilder<List<FamilyMember>>(
            stream: FamilyService.stream(),
            builder: (context, snap) {
              if (!snap.hasData) {
                return const Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              final list = snap.data!;
              if (list.isEmpty) {
                return const Card(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Text('Nenhum vínculo ainda.'),
                  ),
                );
              }
              return Column(
                children: list.map(_memberTile).toList(),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _myCodeCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Seu código de convite',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 8),
            if (_loadingCode)
              const CircularProgressIndicator()
            else if (_codeError != null)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Erro: $_codeError',
                    style: const TextStyle(color: Colors.red, fontSize: 13),
                  ),
                  const SizedBox(height: 8),
                  TextButton.icon(
                    onPressed: _loadCode,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Tentar novamente'),
                  ),
                ],
              )
            else
              Row(
                children: [
                  Expanded(
                    child: SelectableText(
                      _myCode ?? '---',
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 4,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.copy),
                    onPressed: _myCode == null
                        ? null
                        : () {
                            Clipboard.setData(ClipboardData(text: _myCode!));
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Código copiado.')),
                            );
                          },
                  ),
                ],
              ),
            const Text(
              'Compartilhe este código com seu familiar para que ele te adicione.',
              style: TextStyle(color: Colors.black54),
            ),
          ],
        ),
      ),
    );
  }

  Widget _linkCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Adicionar familiar',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 8),
            TextField(
              controller: _codeCtrl,
              textCapitalization: TextCapitalization.characters,
              decoration: const InputDecoration(
                hintText: 'Digite o código (ex: AB12CD)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            ElevatedButton.icon(
              onPressed: _linking ? null : _link,
              icon: const Icon(Icons.link),
              label: Text(_linking ? 'Vinculando...' : 'Vincular'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4A90D9),
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _memberTile(FamilyMember m) {
    final isMonitored = m.papel == 'monitorado';
    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: isMonitored
              ? const Color(0xFF7B5EA7)
              : const Color(0xFF4A90D9),
          child: Icon(
            isMonitored ? Icons.elderly : Icons.shield,
            color: Colors.white,
          ),
        ),
        title: Text(m.nome),
        subtitle: Text('${m.perfil} · ${m.papel}'),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isMonitored)
              IconButton(
                icon: const Icon(Icons.monitor_heart, color: Color(0xFFE53935)),
                tooltip: 'Monitorar',
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => MonitorScreen(member: m),
                  ),
                ),
              ),
            IconButton(
              icon: const Icon(Icons.chat_bubble_outline),
              tooltip: 'Conversar',
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ChatScreen(member: m),
                ),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.link_off, color: Colors.red),
              tooltip: 'Desvincular',
              onPressed: () async {
                await FamilyService.unlink(m.uid);
              },
            ),
          ],
        ),
      ),
    );
  }
}
