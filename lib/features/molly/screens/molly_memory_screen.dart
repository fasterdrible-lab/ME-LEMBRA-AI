import 'package:flutter/material.dart';

import '../../../services/settings_service.dart';
import '../memory/long_term_memory.dart';
import '../models/molly_memory_entry.dart';

/// Tela "O que a Molly lembra" (TAREFA 9 do prompt mestre).
///
/// Único ponto de contato do usuário com a memória de longo prazo
/// (TAREFA 8) — pensada para privacidade totalmente transparente: mostra
/// cada memória com o que é, quando foi atualizada e de onde veio
/// (`source`), deixa editar ou excluir uma por uma, apagar tudo de uma
/// vez, e o interruptor geral "A Molly pode lembrar minhas preferências?"
/// que também funciona como "impedir novas memórias" — desligado, ele
/// nada mais faz que fazer `LongTermMemoryService.salvar()` recusar
/// qualquer gravação nova (a checagem já existe na TAREFA 8); memórias já
/// guardadas continuam visíveis e editáveis até o usuário excluí-las.
///
/// Aditiva, como `molly_screen.dart` (TAREFA 6): existe na rota
/// `/molly-memory`, mas nenhum botão do app navega pra cá ainda.
class MollyMemoryScreen extends StatefulWidget {
  const MollyMemoryScreen({super.key});

  @override
  State<MollyMemoryScreen> createState() => _MollyMemoryScreenState();
}

class _MollyMemoryScreenState extends State<MollyMemoryScreen> {
  bool _autorizado = false;
  bool _carregandoToggle = true;

  static const Map<String, String> _rotulos = {
    'nome_preferido': 'Nome preferido',
    'familiares': 'Familiares',
    'horario_almoco': 'Horário do almoço',
    'horario_cafe': 'Horário do café',
    'preferencia_de_voz': 'Preferência de voz',
    'preferencia_de_lembrete': 'Preferência de lembrete',
    'rotinas': 'Rotina',
  };

  @override
  void initState() {
    super.initState();
    _carregarToggle();
  }

  Future<void> _carregarToggle() async {
    final v = await SettingsService.getMollyMemoriaAutorizada();
    if (mounted) {
      setState(() {
        _autorizado = v;
        _carregandoToggle = false;
      });
    }
  }

  Future<void> _alternarAutorizacao(bool v) async {
    setState(() => _autorizado = v);
    await SettingsService.setMollyMemoriaAutorizada(v);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(v
          ? 'A Molly pode guardar novas preferências, sempre com sua autorização.'
          : 'A Molly não vai guardar nenhuma preferência nova.'),
    ));
  }

  Future<void> _editar(MollyMemoryEntry memoria) async {
    final controller = TextEditingController(text: memoria.value);
    final novoValor = await showDialog<String>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(_rotulo(memoria.type), style: const TextStyle(fontSize: 22)),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: const TextStyle(fontSize: 20),
          decoration: const InputDecoration(border: OutlineInputBorder()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text('Cancelar', style: TextStyle(fontSize: 18)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogCtx, controller.text),
            child: const Text('Salvar', style: TextStyle(fontSize: 18)),
          ),
        ],
      ),
    );
    if (novoValor != null && novoValor.trim().isNotEmpty && novoValor.trim() != memoria.value) {
      await LongTermMemoryService.atualizarValor(memoria.id, novoValor);
    }
  }

  Future<void> _excluir(MollyMemoryEntry memoria) async {
    final messenger = ScaffoldMessenger.of(context);
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Excluir memória', style: TextStyle(fontSize: 22)),
        content: Text(
          'A Molly vai esquecer "${memoria.value}". Continuar?',
          style: const TextStyle(fontSize: 18),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx, false),
            child: const Text('Cancelar', style: TextStyle(fontSize: 18)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: _corPerigo, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(dialogCtx, true),
            child: const Text('Excluir', style: TextStyle(fontSize: 18)),
          ),
        ],
      ),
    );
    if (confirmar != true) return;
    try {
      await LongTermMemoryService.excluir(memoria.id);
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Erro ao excluir: $e')));
    }
  }

  Future<void> _apagarTudo() async {
    final messenger = ScaffoldMessenger.of(context);
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Apagar tudo', style: TextStyle(fontSize: 22)),
        content: const Text(
          'A Molly vai esquecer tudo que sabe sobre você. Essa ação não pode ser desfeita.',
          style: TextStyle(fontSize: 18),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx, false),
            child: const Text('Cancelar', style: TextStyle(fontSize: 18)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: _corPerigo, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(dialogCtx, true),
            child: const Text('Apagar tudo', style: TextStyle(fontSize: 18)),
          ),
        ],
      ),
    );
    if (confirmar != true) return;
    try {
      await LongTermMemoryService.excluirTudo();
      messenger.showSnackBar(const SnackBar(content: Text('Todas as memórias foram apagadas.')));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Erro ao apagar: $e')));
    }
  }

  String _rotulo(String type) => _rotulos[type] ?? type.replaceAll('_', ' ');

  String _dataFormatada(DateTime? dt) {
    if (dt == null) return 'agora há pouco';
    return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F4FB),
      appBar: AppBar(
        title: const Text('O que a Molly lembra', style: TextStyle(fontSize: 22)),
        backgroundColor: _corPrimaria,
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: _carregandoToggle
                ? const Padding(
                    padding: EdgeInsets.all(16),
                    child: LinearProgressIndicator(),
                  )
                : SwitchListTile(
                    title: const Text(
                      'A Molly pode lembrar minhas preferências?',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                    ),
                    subtitle: Text(
                      _autorizado
                          ? 'Sim — sempre com sua autorização a cada nova memória.'
                          : 'Não — a Molly não vai guardar nada de novo sobre você.',
                    ),
                    value: _autorizado,
                    activeThumbColor: _corPrimaria,
                    onChanged: _alternarAutorizacao,
                  ),
          ),
          const SizedBox(height: 20),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 4),
            child: Text('Memórias guardadas', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          ),
          const SizedBox(height: 8),
          StreamBuilder<List<MollyMemoryEntry>>(
            stream: LongTermMemoryService.stream(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              final memorias = snapshot.data!;
              if (memorias.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Text(
                    'A Molly ainda não guardou nenhuma preferência sua.',
                    style: TextStyle(fontSize: 16, color: Colors.black54),
                  ),
                );
              }
              return Column(
                children: [
                  for (final m in memorias)
                    _CardMemoria(
                      entrada: m,
                      rotulo: _rotulo(m.type),
                      dataFormatada: _dataFormatada(m.updatedAt),
                      onEditar: () => _editar(m),
                      onExcluir: () => _excluir(m),
                    ),
                ],
              );
            },
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _apagarTudo,
              icon: const Icon(Icons.delete_forever, color: _corPerigo),
              label: const Text('Apagar tudo', style: TextStyle(fontSize: 16)),
              style: OutlinedButton.styleFrom(
                foregroundColor: _corPerigo,
                side: const BorderSide(color: _corPerigo),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Abaixo disso, a memória é destacada para revisão do usuário — não é
// descartada automaticamente (ver docstring de MollyMemoryEntry.confidence).
const double _limiarConfiancaBaixa = 0.7;
const Color _corPrimaria = Color(0xFF7B5EA7);
const Color _corPerigo = Color(0xFFE53935);
const Color _corAviso = Color(0xFFFF8C00);

class _CardMemoria extends StatelessWidget {
  final MollyMemoryEntry entrada;
  final String rotulo;
  final String dataFormatada;
  final VoidCallback onEditar;
  final VoidCallback onExcluir;

  const _CardMemoria({
    required this.entrada,
    required this.rotulo,
    required this.dataFormatada,
    required this.onEditar,
    required this.onExcluir,
  });

  @override
  Widget build(BuildContext context) {
    final baixaConfianca = entrada.confidence < _limiarConfiancaBaixa;
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: baixaConfianca ? const Color(0xFFFFF3E0) : const Color(0xFFEDE7F6),
          child: Icon(
            baixaConfianca ? Icons.help_outline : Icons.psychology_alt_outlined,
            color: baixaConfianca ? _corAviso : _corPrimaria,
          ),
        ),
        title: Text(rotulo, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 17)),
        subtitle: Text(
          '${entrada.value}\n'
          'Atualizado em $dataFormatada · origem: ${entrada.source}'
          '${baixaConfianca ? '\nBaixa confiança — confira se está certo.' : ''}',
        ),
        isThreeLine: true,
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(icon: const Icon(Icons.edit_outlined), tooltip: 'Editar', onPressed: onEditar),
            IconButton(
              icon: const Icon(Icons.delete_outline, color: _corPerigo),
              tooltip: 'Excluir',
              onPressed: onExcluir,
            ),
          ],
        ),
      ),
    );
  }
}
