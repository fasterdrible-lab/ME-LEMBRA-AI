import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../models/reminder.dart';
import '../../services/reminder_service.dart';
import '../../services/voice_service.dart';

/// Tela de lembretes completa para o perfil Vovô / Vovó.
/// Seções fixas por categoria: Remédios · Água · Consultas · Mercado · Aniversários · Eventos.
/// Inspirado em: Microsoft To Do (check animado), Todoist (badge count),
/// Google Tasks (swipe delete), WaterMinder (contador de copos), AnyList (desmarcar todos).
class MeusLembretesScreen extends StatefulWidget {
  const MeusLembretesScreen({super.key});

  @override
  State<MeusLembretesScreen> createState() => _MeusLembretesScreenState();
}

class _MeusLembretesScreenState extends State<MeusLembretesScreen> {
  static const Color _primary = Color(0xFF7B5EA7);
  static const Color _danger = Color(0xFFE53935);
  static const int _metaAgua = 8;

  List<Reminder> _todos = [];
  bool _loading = true;
  // check_<id>_<idx>  → marcação de item na lista de compras
  Map<String, bool> _checks = {};
  // done_<id>_<YYYYMMDD> → lembrete confirmado hoje (Microsoft To Do style)
  Map<String, bool> _done = {};
  int _coposAgua = 0;

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  // Chave do dia atual ex.: "20260509"
  String get _hojeKey {
    final now = DateTime.now();
    return '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}';
  }

  Future<void> _carregar() async {
    setState(() => _loading = true);
    final lista = await ReminderService.getAll();
    lista.sort((a, b) => a.dateTime.compareTo(b.dateTime));
    final prefs = await SharedPreferences.getInstance();
    final checks = <String, bool>{};
    final done = <String, bool>{};
    for (final key in prefs.getKeys()) {
      if (key.startsWith('check_')) checks[key] = prefs.getBool(key) ?? false;
      if (key.startsWith('done_') && key.endsWith(_hojeKey)) {
        done[key] = prefs.getBool(key) ?? false;
      }
    }
    final copos = prefs.getInt('agua_$_hojeKey') ?? 0;
    if (mounted) {
      setState(() {
        _todos = lista;
        _checks = checks;
        _done = done;
        _coposAgua = copos;
        _loading = false;
      });
    }
  }

  // ── Água ─────────────────────────────────────────────────────────────────

  Future<void> _registrarCopo() async {
    if (_coposAgua >= _metaAgua) return;
    final prefs = await SharedPreferences.getInstance();
    final novo = _coposAgua + 1;
    await prefs.setInt('agua_$_hojeKey', novo);
    setState(() => _coposAgua = novo);
    if (novo == _metaAgua) {
      await VoiceService.speak('Parabéns! Você tomou os 8 copos de água hoje!');
    }
  }

  Future<void> _removerCopo() async {
    if (_coposAgua <= 0) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('agua_$_hojeKey', _coposAgua - 1);
    setState(() => _coposAgua--);
  }

  // ── Confirmar lembrete (check animado — Microsoft To Do style) ────────────

  Future<void> _toggleDone(Reminder r) async {
    final key = 'done_${r.id}_$_hojeKey';
    final prefs = await SharedPreferences.getInstance();
    final novo = !(_done[key] ?? false);
    await prefs.setBool(key, novo);
    setState(() => _done[key] = novo);
    if (novo && r.type == 'Remédio') {
      await VoiceService.speak('Remédio marcado como tomado!');
    }
  }

  // ── Marcação de item na lista de compras ──────────────────────────────────

  Future<void> _toggleItem(String remId, int idx, bool val) async {
    final key = 'check_${remId}_$idx';
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(key, val);
    setState(() => _checks[key] = val);
  }

  Future<void> _desmarcarTodos(String remId, int total) async {
    final prefs = await SharedPreferences.getInstance();
    for (var i = 0; i < total; i++) {
      await prefs.remove('check_${remId}_$i');
    }
    await _carregar();
  }

  Future<void> _limparChecks(String remId, int total) async {
    final prefs = await SharedPreferences.getInstance();
    for (var i = 0; i < total; i++) {
      await prefs.remove('check_${remId}_$i');
    }
  }

  // ── Exclusão ──────────────────────────────────────────────────────────────

  Future<void> _excluir(Reminder r) async {
    if (!mounted) return;
    final notifId = (r.title.hashCode ^ r.dateTime.millisecondsSinceEpoch)
        .remainder(2147483647)
        .abs();
    final itens =
        r.description.trim().split('\n').where((e) => e.isNotEmpty).length;
    final messenger = ScaffoldMessenger.of(context);

    await showDialog<void>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Excluir lembrete', style: TextStyle(fontSize: 24)),
        content: Text(
          'Deseja excluir "${r.title.isNotEmpty ? r.title : r.type}"?',
          style: const TextStyle(fontSize: 20),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text('Cancelar', style: TextStyle(fontSize: 20)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: _danger, foregroundColor: Colors.white),
            onPressed: () async {
              Navigator.pop(dialogCtx);
              try {
                await ReminderService.delete(r.id, notificationId: notifId);
                await _limparChecks(r.id, itens);
                await _carregar();
              } catch (e) {
                messenger.showSnackBar(
                  SnackBar(content: Text('Erro ao excluir: $e')),
                );
              }
            },
            child: const Text('Excluir', style: TextStyle(fontSize: 24)),
          ),
        ],
      ),
    );
  }

  // ── Filtros por categoria ─────────────────────────────────────────────────

  bool _isCategoria(Reminder r, String cat) {
    final txt = '${r.title} ${r.type} ${r.description}'.toLowerCase();
    switch (cat) {
      case 'remedio':
        return r.type == 'Remedio' ||
            txt.contains('remédio') ||
            txt.contains('remedio') ||
            txt.contains('medicamento') ||
            txt.contains('comprimido');
      case 'consulta':
        return r.type == 'Consulta' ||
            txt.contains('consulta') ||
            txt.contains('médico') ||
            txt.contains('medico') ||
            txt.contains('dentista') ||
            txt.contains('exame');
      case 'aniversario':
        return r.type == 'Aniversario' ||
            txt.contains('aniversário') ||
            txt.contains('aniversario') ||
            txt.contains('niver');
      case 'mercado':
        return r.type == 'Mercado' ||
            txt.contains('compra') ||
            txt.contains('mercado') ||
            txt.contains('supermercado') ||
            txt.contains('lista');
      case 'evento':
        return r.type == 'Reuniao' ||
            txt.contains('evento') ||
            txt.contains('festa') ||
            txt.contains('reunião') ||
            txt.contains('reuniao') ||
            txt.contains('churrasco');
      case 'tomar':
        return r.type == 'Tomar';
      default:
        return false;
    }
  }

  List<Reminder> _filtrar(String cat) =>
      _todos.where((r) => _isCategoria(r, cat)).toList();

  List<Reminder> get _outros => _todos
      .where((r) =>
          !_isCategoria(r, 'remedio') &&
          !_isCategoria(r, 'consulta') &&
          !_isCategoria(r, 'aniversario') &&
          !_isCategoria(r, 'mercado') &&
          !_isCategoria(r, 'evento') &&
          !_isCategoria(r, 'tomar'))
      .toList();

  // ── Chip de repetição ─────────────────────────────────────────────────────

  Widget _repeatChip(Reminder r) {
    if (r.repeat == 'unico') return const SizedBox.shrink();
    final label = r.repeat == 'diario' ? '↻ Diário' : '↻ Semanal';
    final color =
        r.repeat == 'diario' ? const Color(0xFF43A047) : const Color(0xFF7B5EA7);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: color.withAlpha(20),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withAlpha(80)),
      ),
      child: Text(label,
          style: TextStyle(
              fontSize: 12, color: color, fontWeight: FontWeight.w600)),
    );
  }

  // ── Item simples com check animado e swipe para excluir ───────────────────

  Widget _itemSimples(Reminder r, Color catColor) {
    final titulo = r.title.isNotEmpty ? r.title : r.type;
    final doneKey = 'done_${r.id}_$_hojeKey';
    final done = _done[doneKey] ?? false;
    final h = r.dateTime.hour.toString().padLeft(2, '0');
    final m = r.dateTime.minute.toString().padLeft(2, '0');

    return Dismissible(
      key: Key('item_${r.id}'),
      direction: DismissDirection.endToStart,
      confirmDismiss: (_) async {
        await _excluir(r);
        return false;
      },
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: _danger,
          borderRadius: BorderRadius.circular(14),
        ),
        child: const Icon(Icons.delete_outline, color: Colors.white, size: 28),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: done ? Colors.grey.shade100 : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
              color: done
                  ? Colors.grey.shade300
                  : catColor.withAlpha(50)),
        ),
        child: ListTile(
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          // Check animado — toque para confirmar (Microsoft To Do style)
          leading: GestureDetector(
            onTap: () => _toggleDone(r),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: done ? catColor : Colors.white,
                border: Border.all(color: catColor, width: 2),
              ),
              child: done
                  ? const Icon(Icons.check, color: Colors.white, size: 20)
                  : null,
            ),
          ),
          title: Text(
            titulo,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              decoration:
                  done ? TextDecoration.lineThrough : null,
              color: done ? Colors.black38 : Colors.black87,
            ),
          ),
          subtitle: Row(
            children: [
              Text('$h:$m',
                  style: const TextStyle(fontSize: 14, color: Colors.black45)),
              const SizedBox(width: 8),
              _repeatChip(r),
            ],
          ),
          trailing: IconButton(
            icon: Icon(Icons.delete_outline,
                color: _danger.withAlpha(180), size: 24),
            onPressed: () => _excluir(r),
          ),
        ),
      ),
    );
  }

  // ── Cartão de mercado com itens marcáveis e swipe ─────────────────────────

  Widget _mercadoCard(Reminder r) {
    final titulo = r.title.isNotEmpty ? r.title : 'Lista de compras';
    final itens = r.description.trim().isNotEmpty
        ? r.description
            .trim()
            .split('\n')
            .where((e) => e.isNotEmpty)
            .toList()
        : <String>[];
    final pendentes = itens
        .asMap()
        .entries
        .where((e) => !(_checks['check_${r.id}_${e.key}'] ?? false))
        .length;
    final algumMarcado = itens
        .asMap()
        .entries
        .any((e) => _checks['check_${r.id}_${e.key}'] ?? false);

    return Dismissible(
      key: Key('mercado_${r.id}'),
      direction: DismissDirection.endToStart,
      confirmDismiss: (_) async {
        await _excluir(r);
        return false;
      },
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: _danger,
          borderRadius: BorderRadius.circular(14),
        ),
        child: const Icon(Icons.delete_outline, color: Colors.white, size: 28),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border:
              Border.all(color: const Color(0xFF1E88E5).withAlpha(50)),
        ),
        child: ExpansionTile(
          initiallyExpanded: true,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14)),
          collapsedShape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14)),
          title: Row(
            children: [
              Expanded(
                child: Text(titulo,
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.w600)),
              ),
              if (pendentes > 0)
                Container(
                  margin: const EdgeInsets.only(right: 4),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E88E5),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text('$pendentes faltam',
                      style: const TextStyle(
                          color: Colors.white, fontSize: 12)),
                ),
            ],
          ),
          subtitle: _repeatChip(r),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.expand_more),
              IconButton(
                icon: Icon(Icons.delete_outline,
                    color: _danger.withAlpha(180), size: 24),
                onPressed: () => _excluir(r),
              ),
            ],
          ),
          children: [
            if (itens.isEmpty)
              Padding(
                padding:
                    const EdgeInsets.fromLTRB(16, 4, 16, 16),
                child: Text(
                  'Diga "adicionar leite na lista" para incluir itens.',
                  style: TextStyle(
                      fontSize: 15, color: Colors.grey.shade500),
                  textAlign: TextAlign.center,
                ),
              )
            else ...[
              ...itens.asMap().entries.map((e) {
                final idx = e.key;
                final item = e.value;
                final ck = _checks['check_${r.id}_$idx'] ?? false;
                return CheckboxListTile(
                  dense: true,
                  activeColor: const Color(0xFF1E88E5),
                  value: ck,
                  onChanged: (v) =>
                      _toggleItem(r.id, idx, v ?? false),
                  title: Text(
                    item,
                    style: TextStyle(
                      fontSize: 17,
                      decoration: ck
                          ? TextDecoration.lineThrough
                          : null,
                      color:
                          ck ? Colors.black38 : Colors.black87,
                    ),
                  ),
                );
              }),
              // AnyList style: botão para desmarcar todos
              if (algumMarcado)
                Padding(
                  padding:
                      const EdgeInsets.fromLTRB(16, 0, 16, 10),
                  child: TextButton.icon(
                    onPressed: () =>
                        _desmarcarTodos(r.id, itens.length),
                    icon: const Icon(Icons.refresh, size: 16),
                    label: const Text('Desmarcar todos'),
                    style: TextButton.styleFrom(
                        foregroundColor:
                            const Color(0xFF1E88E5)),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }

  // ── Contador de água (WaterMinder / Samsung Health style) ─────────────────

  Widget _aguaWidget() {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
            color: const Color(0xFF29B6F6).withAlpha(80)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.water_drop,
                  color: Color(0xFF29B6F6), size: 22),
              const SizedBox(width: 8),
              Text(
                '$_coposAgua / $_metaAgua copos hoje',
                style: const TextStyle(
                    fontSize: 17, fontWeight: FontWeight.w600),
              ),
              const Spacer(),
              // Botão − para desfazer
              IconButton(
                icon: const Icon(Icons.remove_circle_outline,
                    color: Colors.black38, size: 22),
                tooltip: 'Desfazer',
                onPressed: _removerCopo,
              ),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF29B6F6),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 8),
                ),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Beber',
                    style: TextStyle(fontSize: 15)),
                onPressed:
                    _coposAgua < _metaAgua ? _registrarCopo : null,
              ),
            ],
          ),
          const SizedBox(height: 10),
          // Barra de progresso segmentada
          Row(
            children: List.generate(_metaAgua, (i) {
              final cheio = i < _coposAgua;
              return Expanded(
                child: Container(
                  margin:
                      const EdgeInsets.symmetric(horizontal: 2),
                  height: 14,
                  decoration: BoxDecoration(
                    color: cheio
                        ? const Color(0xFF29B6F6)
                        : const Color(0xFFE3F2FD),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              );
            }),
          ),
          if (_coposAgua >= _metaAgua)
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Text(
                '✅ Meta diária de água atingida!',
                style: TextStyle(
                    color: Color(0xFF29B6F6),
                    fontWeight: FontWeight.w600,
                    fontSize: 14),
              ),
            ),
        ],
      ),
    );
  }

  // ── Seção expansível por categoria (Todoist style badge) ─────────────────

  Widget _secao({
    required IconData icon,
    required Color color,
    required String titulo,
    required List<Widget> items,
    required int badge,
    bool initiallyExpanded = true,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      elevation: 2,
      child: ExpansionTile(
        initiallyExpanded: initiallyExpanded,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18)),
        collapsedShape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18)),
        leading: CircleAvatar(
          backgroundColor: color.withAlpha(30),
          radius: 22,
          child: Icon(icon, color: color, size: 24),
        ),
        title: Row(
          children: [
            Text(titulo,
                style: const TextStyle(
                    fontSize: 20, fontWeight: FontWeight.bold)),
            if (badge > 0) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text('$badge',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.bold)),
              ),
            ],
          ],
        ),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: items.isEmpty
                ? Padding(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    child: Text(
                      'Nenhum item. Use o comando de voz para adicionar.',
                      style: TextStyle(
                          fontSize: 15, color: Colors.grey.shade500),
                      textAlign: TextAlign.center,
                    ),
                  )
                : Column(children: items),
          ),
        ],
      ),
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final remedios = _filtrar('remedio');
    final consultas = _filtrar('consulta');
    final aniversarios = _filtrar('aniversario');
    final mercado = _filtrar('mercado');
    final eventos = _filtrar('evento');
    final outros = _outros;

    // Badge = pendentes (não confirmados hoje)
    int pendentes(List<Reminder> lista) => lista
        .where((r) => !(_done['done_${r.id}_$_hojeKey'] ?? false))
        .length;

    return Scaffold(
      backgroundColor: const Color(0xFFF7F4FB),
      appBar: AppBar(
        title:
            const Text('Meus Lembretes', style: TextStyle(fontSize: 24)),
        backgroundColor: _primary,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, size: 28),
            tooltip: 'Atualizar',
            onPressed: _carregar,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _carregar,
              child: ListView(
                padding:
                    const EdgeInsets.fromLTRB(14, 16, 14, 80),
                children: [
                  // ── Remédios ──────────────────────────────────
                  _secao(
                    icon: Icons.medication,
                    color: const Color(0xFF43A047),
                    titulo: 'Remédios',
                    badge: pendentes(remedios),
                    items: remedios
                        .map((r) =>
                            _itemSimples(r, const Color(0xFF43A047)))
                        .toList(),
                  ),

                  // ── Tomar Água ────────────────────────────────
                  _secao(
                    icon: Icons.water_drop,
                    color: const Color(0xFF29B6F6),
                    titulo: 'Tomar Água',
                    badge: _metaAgua - _coposAgua > 0
                        ? _metaAgua - _coposAgua
                        : 0,
                    items: [_aguaWidget()],
                  ),

                  // ── Consultas ─────────────────────────────────
                  _secao(
                    icon: Icons.local_hospital,
                    color: const Color(0xFF00897B),
                    titulo: 'Consultas',
                    badge: pendentes(consultas),
                    items: consultas
                        .map((r) =>
                            _itemSimples(r, const Color(0xFF00897B)))
                        .toList(),
                  ),

                  // ── Mercado / Compras ─────────────────────────
                  _secao(
                    icon: Icons.shopping_cart,
                    color: const Color(0xFF1E88E5),
                    titulo: 'Mercado',
                    badge: mercado.length,
                    items: mercado.map(_mercadoCard).toList(),
                  ),

                  // ── Aniversários ──────────────────────────────
                  _secao(
                    icon: Icons.cake,
                    color: const Color(0xFFE91E63),
                    titulo: 'Aniversários',
                    badge: pendentes(aniversarios),
                    items: aniversarios
                        .map((r) =>
                            _itemSimples(r, const Color(0xFFE91E63)))
                        .toList(),
                  ),

                  // ── Eventos ───────────────────────────────────
                  _secao(
                    icon: Icons.celebration,
                    color: const Color(0xFFFF6F00),
                    titulo: 'Eventos',
                    badge: pendentes(eventos),
                    items: eventos
                        .map((r) =>
                            _itemSimples(r, const Color(0xFFFF6F00)))
                        .toList(),
                  ),

                  // ── Outros ────────────────────────────────────
                  if (outros.isNotEmpty)
                    _secao(
                      icon: Icons.alarm,
                      color: _primary,
                      titulo: 'Outros',
                      badge: pendentes(outros),
                      items: outros
                          .map((r) => _itemSimples(r, _primary))
                          .toList(),
                    ),
                ],
              ),
            ),
    );
  }
}
