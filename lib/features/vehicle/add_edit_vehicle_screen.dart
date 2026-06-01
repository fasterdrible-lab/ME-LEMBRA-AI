import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import '../../models/vehicle.dart';
import '../../services/vehicle_service.dart';

class AddEditVehicleScreen extends StatefulWidget {
  final Vehicle? vehicle;
  const AddEditVehicleScreen({super.key, this.vehicle});

  @override
  State<AddEditVehicleScreen> createState() => _AddEditVehicleScreenState();
}

class _AddEditVehicleScreenState extends State<AddEditVehicleScreen> {
  static const Color _primary = Color(0xFF7B5EA7);

  final _formKey = GlobalKey<FormState>();
  bool _salvando = false;

  // Campos básicos
  final _apelidoCtrl = TextEditingController();
  final _placaCtrl = TextEditingController();

  // Troca de óleo
  final _kmAtualCtrl = TextEditingController();
  final _kmProximaCtrl = TextEditingController();
  DateTime? _dataUltimaTroca;

  // IPVA
  final _anoIpvaCtrl = TextEditingController();
  final _valorIpvaCtrl = TextEditingController();
  DateTime? _vencimentoIpva;
  bool _ipvaParcelado = false;
  final _ipvaNumParcelasCtrl = TextEditingController(text: '2');
  List<_ParcelaForm> _parcelasIpva = [];

  // CNH
  DateTime? _vencimentoCnh;

  // Seguro
  final _valorSeguroCtrl = TextEditingController();
  DateTime? _vencimentoSeguro;
  bool _seguroParcelado = false;
  final _seguroNumParcelasCtrl = TextEditingController(text: '12');
  List<_ParcelaForm> _parcelasSeguro = [];

  bool get _editando => widget.vehicle != null;

  @override
  void initState() {
    super.initState();
    if (_editando) {
      final v = widget.vehicle!;
      _apelidoCtrl.text = v.apelido;
      _placaCtrl.text = v.placa;
      if (v.kmAtual != null) _kmAtualCtrl.text = v.kmAtual.toString();
      if (v.kmProximaTroca != null)
        _kmProximaCtrl.text = v.kmProximaTroca.toString();
      _dataUltimaTroca = v.dataUltimaTroca;
      if (v.anoIpva != null) _anoIpvaCtrl.text = v.anoIpva.toString();
      if (v.valorIpva != null)
        _valorIpvaCtrl.text = v.valorIpva!.toStringAsFixed(2);
      _vencimentoIpva = v.vencimentoIpva;
      if (v.parcelasIpva.isNotEmpty) {
        _ipvaParcelado = true;
        _ipvaNumParcelasCtrl.text = v.parcelasIpva.length.toString();
        _parcelasIpva = v.parcelasIpva
            .map((p) => _ParcelaForm(
                valor: p.valor.toStringAsFixed(2),
                vencimento: p.vencimento,
                pago: p.pago))
            .toList();
      }
      _vencimentoCnh = v.vencimentoCnh;
      if (v.valorSeguro != null)
        _valorSeguroCtrl.text = v.valorSeguro!.toStringAsFixed(2);
      _vencimentoSeguro = v.vencimentoSeguro;
      if (v.parcelasSeguro.isNotEmpty) {
        _seguroParcelado = true;
        _seguroNumParcelasCtrl.text = v.parcelasSeguro.length.toString();
        _parcelasSeguro = v.parcelasSeguro
            .map((p) => _ParcelaForm(
                valor: p.valor.toStringAsFixed(2),
                vencimento: p.vencimento,
                pago: p.pago))
            .toList();
      }
    }
  }

  @override
  void dispose() {
    _apelidoCtrl.dispose();
    _placaCtrl.dispose();
    _kmAtualCtrl.dispose();
    _kmProximaCtrl.dispose();
    _anoIpvaCtrl.dispose();
    _valorIpvaCtrl.dispose();
    _ipvaNumParcelasCtrl.dispose();
    _valorSeguroCtrl.dispose();
    _seguroNumParcelasCtrl.dispose();
    super.dispose();
  }

  // ─── Parcelas ──────────────────────────────

  void _gerarParcelasIpva() {
    final n = int.tryParse(_ipvaNumParcelasCtrl.text) ?? 0;
    final total = double.tryParse(
            _valorIpvaCtrl.text.replaceAll(',', '.')) ??
        0;
    final base = _vencimentoIpva ?? DateTime.now();
    if (n <= 0) return;
    setState(() {
      _parcelasIpva = List.generate(n, (i) {
        final valorParcela = total / n;
        final venc = DateTime(base.year, base.month + i, base.day);
        return _ParcelaForm(
            valor: valorParcela.toStringAsFixed(2), vencimento: venc);
      });
    });
  }

  void _gerarParcelasSeguro() {
    final n = int.tryParse(_seguroNumParcelasCtrl.text) ?? 0;
    final total = double.tryParse(
            _valorSeguroCtrl.text.replaceAll(',', '.')) ??
        0;
    final base = _vencimentoSeguro ?? DateTime.now();
    if (n <= 0) return;
    setState(() {
      _parcelasSeguro = List.generate(n, (i) {
        final valorParcela = total / n;
        final venc = DateTime(base.year, base.month + i, base.day);
        return _ParcelaForm(
            valor: valorParcela.toStringAsFixed(2), vencimento: venc);
      });
    });
  }

  // ─── Salvar ────────────────────────────────

  Future<void> _salvar() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _salvando = true);

    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';

    final parcelasIpvaModel = _ipvaParcelado
        ? _parcelasIpva.asMap().entries.map((e) {
            final ctrl = e.value;
            return VehicleInstallment(
              parcela: e.key + 1,
              valor: double.tryParse(ctrl.valor.replaceAll(',', '.')) ?? 0,
              vencimento: ctrl.vencimento ?? DateTime.now(),
              pago: ctrl.pago,
            );
          }).toList()
        : <VehicleInstallment>[];

    final parcelasSeguroModel = _seguroParcelado
        ? _parcelasSeguro.asMap().entries.map((e) {
            final ctrl = e.value;
            return VehicleInstallment(
              parcela: e.key + 1,
              valor: double.tryParse(ctrl.valor.replaceAll(',', '.')) ?? 0,
              vencimento: ctrl.vencimento ?? DateTime.now(),
              pago: ctrl.pago,
            );
          }).toList()
        : <VehicleInstallment>[];

    final v = Vehicle(
      id: widget.vehicle?.id ?? '',
      userId: uid,
      apelido: _apelidoCtrl.text.trim(),
      placa: _placaCtrl.text.trim().toUpperCase(),
      kmAtual: int.tryParse(_kmAtualCtrl.text),
      kmProximaTroca: int.tryParse(_kmProximaCtrl.text),
      dataUltimaTroca: _dataUltimaTroca,
      anoIpva: int.tryParse(_anoIpvaCtrl.text),
      valorIpva:
          double.tryParse(_valorIpvaCtrl.text.replaceAll(',', '.')),
      vencimentoIpva: _vencimentoIpva,
      parcelasIpva: parcelasIpvaModel,
      vencimentoCnh: _vencimentoCnh,
      vencimentoSeguro: _vencimentoSeguro,
      valorSeguro:
          double.tryParse(_valorSeguroCtrl.text.replaceAll(',', '.')),
      parcelasSeguro: parcelasSeguroModel,
    );

    try {
      if (_editando) {
        await VehicleService.update(v);
      } else {
        await VehicleService.add(v);
      }
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Erro ao salvar: $e')));
      }
    } finally {
      if (mounted) setState(() => _salvando = false);
    }
  }

  Future<void> _excluir() async {
    if (!_editando) return;
    final messenger = ScaffoldMessenger.of(context);
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Excluir veículo'),
        content: Text(
            'Excluir "${widget.vehicle!.apelido}" permanentemente?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );
    if (confirm == true) {
      try {
        await VehicleService.delete(widget.vehicle!.id);
        if (mounted) Navigator.pop(context);
      } catch (e) {
        messenger.showSnackBar(SnackBar(content: Text('Erro: $e')));
      }
    }
  }

  // ─── Helpers de UI ─────────────────────────

  Future<DateTime?> _pickDate(BuildContext context, DateTime? inicial) =>
      showDatePicker(
        context: context,
        initialDate: inicial ?? DateTime.now(),
        firstDate: DateTime(2000),
        lastDate: DateTime(2040),
      );

  Widget _sectionTitle(String text) => Padding(
        padding: const EdgeInsets.only(top: 20, bottom: 8),
        child: Text(text,
            style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 15,
                color: _primary)),
      );

  Widget _dateTile(String label, DateTime? value, VoidCallback onTap,
      {bool obrigatorio = false}) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: const Icon(Icons.calendar_today, color: _primary),
      title: Text(label),
      subtitle: value != null
          ? Text(DateFormat('dd/MM/yyyy').format(value),
              style: const TextStyle(fontWeight: FontWeight.w500))
          : Text(obrigatorio ? 'Toque para selecionar *' : 'Não informado',
              style: TextStyle(
                  color: obrigatorio ? Colors.red[400] : Colors.grey)),
      onTap: onTap,
    );
  }

  // ─── Build ─────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F4F8),
      appBar: AppBar(
        title: Text(_editando ? 'Editar veículo' : 'Novo veículo'),
        backgroundColor: _primary,
        foregroundColor: Colors.white,
        actions: [
          if (_editando)
            IconButton(
                icon: const Icon(Icons.delete_outline),
                onPressed: _excluir),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // ── Básico ──
            _sectionTitle('Dados do veículo'),
            TextFormField(
              controller: _apelidoCtrl,
              decoration: const InputDecoration(
                  labelText: 'Apelido (ex: Meu Gol)',
                  border: OutlineInputBorder()),
              validator: (v) =>
                  v == null || v.trim().isEmpty ? 'Informe um apelido' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _placaCtrl,
              textCapitalization: TextCapitalization.characters,
              decoration: const InputDecoration(
                  labelText: 'Placa', border: OutlineInputBorder()),
            ),

            // ── Óleo ──
            _sectionTitle('Troca de óleo'),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _kmAtualCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                        labelText: 'Km atual',
                        border: OutlineInputBorder()),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextFormField(
                    controller: _kmProximaCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                        labelText: 'Km próxima troca',
                        border: OutlineInputBorder()),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            _dateTile(
              'Data última troca',
              _dataUltimaTroca,
              () async {
                final d = await _pickDate(context, _dataUltimaTroca);
                if (d != null) setState(() => _dataUltimaTroca = d);
              },
            ),

            // ── IPVA ──
            _sectionTitle('IPVA'),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _anoIpvaCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                        labelText: 'Ano IPVA',
                        border: OutlineInputBorder()),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextFormField(
                    controller: _valorIpvaCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                        labelText: 'Valor total (R\$)',
                        border: OutlineInputBorder()),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            _dateTile(
              'Vencimento (ou 1ª parcela)',
              _vencimentoIpva,
              () async {
                final d = await _pickDate(context, _vencimentoIpva);
                if (d != null) setState(() => _vencimentoIpva = d);
              },
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('IPVA parcelado'),
              value: _ipvaParcelado,
              activeColor: _primary,
              onChanged: (v) {
                setState(() {
                  _ipvaParcelado = v;
                  if (!v) _parcelasIpva = [];
                });
              },
            ),
            if (_ipvaParcelado) ...[
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _ipvaNumParcelasCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                          labelText: 'Nº de parcelas',
                          border: OutlineInputBorder()),
                    ),
                  ),
                  const SizedBox(width: 10),
                  ElevatedButton(
                    onPressed: _gerarParcelasIpva,
                    style: ElevatedButton.styleFrom(
                        backgroundColor: _primary,
                        foregroundColor: Colors.white),
                    child: const Text('Gerar'),
                  ),
                ],
              ),
              ..._parcelasIpva.asMap().entries.map((e) =>
                  _ParcelaEditor(
                    numero: e.key + 1,
                    form: e.value,
                    onVencChange: (d) => setState(
                        () => _parcelasIpva[e.key].vencimento = d),
                  )),
            ],

            // ── CNH ──
            _sectionTitle('CNH'),
            _dateTile(
              'Vencimento da CNH',
              _vencimentoCnh,
              () async {
                final d = await _pickDate(context, _vencimentoCnh);
                if (d != null) setState(() => _vencimentoCnh = d);
              },
            ),

            // ── Seguro ──
            _sectionTitle('Seguro do veículo'),
            TextFormField(
              controller: _valorSeguroCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                  labelText: 'Valor total do seguro (R\$)',
                  border: OutlineInputBorder()),
            ),
            const SizedBox(height: 4),
            _dateTile(
              'Vencimento (ou 1ª parcela)',
              _vencimentoSeguro,
              () async {
                final d = await _pickDate(context, _vencimentoSeguro);
                if (d != null) setState(() => _vencimentoSeguro = d);
              },
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Seguro parcelado'),
              value: _seguroParcelado,
              activeColor: _primary,
              onChanged: (v) {
                setState(() {
                  _seguroParcelado = v;
                  if (!v) _parcelasSeguro = [];
                });
              },
            ),
            if (_seguroParcelado) ...[
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _seguroNumParcelasCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                          labelText: 'Nº de parcelas',
                          border: OutlineInputBorder()),
                    ),
                  ),
                  const SizedBox(width: 10),
                  ElevatedButton(
                    onPressed: _gerarParcelasSeguro,
                    style: ElevatedButton.styleFrom(
                        backgroundColor: _primary,
                        foregroundColor: Colors.white),
                    child: const Text('Gerar'),
                  ),
                ],
              ),
              ..._parcelasSeguro.asMap().entries.map((e) =>
                  _ParcelaEditor(
                    numero: e.key + 1,
                    form: e.value,
                    onVencChange: (d) => setState(
                        () => _parcelasSeguro[e.key].vencimento = d),
                  )),
            ],

            const SizedBox(height: 28),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: _salvando ? null : _salvar,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
                child: _salvando
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2))
                    : Text(_editando ? 'Salvar alterações' : 'Cadastrar veículo',
                        style: const TextStyle(fontSize: 16)),
              ),
            ),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Estado mutável de uma parcela no formulário
// ─────────────────────────────────────────────
class _ParcelaForm {
  String valor;
  DateTime? vencimento;
  bool pago;

  _ParcelaForm({required this.valor, this.vencimento, this.pago = false});
}

// ─────────────────────────────────────────────
// Widget de edição de parcela individual
// ─────────────────────────────────────────────
class _ParcelaEditor extends StatelessWidget {
  final int numero;
  final _ParcelaForm form;
  final ValueChanged<DateTime> onVencChange;

  const _ParcelaEditor({
    required this.numero,
    required this.form,
    required this.onVencChange,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 28,
            child: Text('$numero.',
                style: const TextStyle(fontWeight: FontWeight.bold)),
          ),
          Expanded(
            child: Text(
              'R\$ ${form.valor}',
              style: const TextStyle(fontSize: 13),
            ),
          ),
          TextButton.icon(
            icon: const Icon(Icons.calendar_today, size: 14),
            label: Text(
              form.vencimento != null
                  ? DateFormat('dd/MM/yy').format(form.vencimento!)
                  : 'Data',
              style: const TextStyle(fontSize: 13),
            ),
            onPressed: () async {
              final d = await showDatePicker(
                context: context,
                initialDate: form.vencimento ?? DateTime.now(),
                firstDate: DateTime(2020),
                lastDate: DateTime(2040),
              );
              if (d != null) onVencChange(d);
            },
          ),
          if (form.pago)
            const Icon(Icons.check_circle, color: Colors.green, size: 18),
        ],
      ),
    );
  }
}
