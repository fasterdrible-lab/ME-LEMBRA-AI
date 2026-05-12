import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/vehicle.dart';
import '../../services/vehicle_service.dart';
import 'add_edit_vehicle_screen.dart';

class VehicleScreen extends StatelessWidget {
  const VehicleScreen({super.key});

  static const Color _primary = Color(0xFF7B5EA7);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F4F8),
      appBar: AppBar(
        title: const Text('Meus Veículos'),
        backgroundColor: _primary,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: _primary,
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const AddEditVehicleScreen()),
        ),
        icon: const Icon(Icons.add),
        label: const Text('Novo veículo'),
      ),
      body: StreamBuilder<List<Vehicle>>(
        stream: VehicleService.stream(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final veiculos = snapshot.data ?? [];
          if (veiculos.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.directions_car_outlined, size: 72, color: Colors.grey[300]),
                  const SizedBox(height: 12),
                  Text('Nenhum veículo cadastrado',
                      style: TextStyle(color: Colors.grey[500], fontSize: 16)),
                  const SizedBox(height: 6),
                  Text('Toque em "Novo veículo" para começar',
                      style: TextStyle(color: Colors.grey[400], fontSize: 13)),
                ],
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
            itemCount: veiculos.length,
            itemBuilder: (context, i) => _VehicleCard(vehicle: veiculos[i]),
          );
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Card de um veículo
// ─────────────────────────────────────────────
class _VehicleCard extends StatelessWidget {
  final Vehicle vehicle;
  const _VehicleCard({required this.vehicle});

  static const Color _primary = Color(0xFF7B5EA7);

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      elevation: 2,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
              builder: (_) => AddEditVehicleScreen(vehicle: vehicle)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Cabeçalho
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: _primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.directions_car, color: _primary, size: 26),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(vehicle.apelido,
                            style: const TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 16)),
                        Text(vehicle.placa.toUpperCase(),
                            style: TextStyle(
                                color: Colors.grey[600], fontSize: 13)),
                      ],
                    ),
                  ),
                  if (vehicle.temAlerta)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.red[50],
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.red[200]!),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.warning_amber_rounded,
                              size: 14, color: Colors.red[600]),
                          const SizedBox(width: 4),
                          Text('Atenção',
                              style: TextStyle(
                                  color: Colors.red[700],
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 14),
              const Divider(height: 1),
              const SizedBox(height: 12),
              // Itens de status
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _StatusChip(
                    icon: Icons.oil_barrel,
                    label: _labelOleo(vehicle),
                    status: vehicle.statusOleo,
                  ),
                  if (vehicle.vencimentoIpva != null)
                    _StatusChip(
                      icon: Icons.receipt_long,
                      label: _labelData('IPVA', vehicle.vencimentoIpva),
                      status: vehicle.statusIpva,
                    ),
                  if (vehicle.vencimentoCnh != null)
                    _StatusChip(
                      icon: Icons.credit_card,
                      label: _labelData('CNH', vehicle.vencimentoCnh),
                      status: vehicle.statusCnh,
                    ),
                  if (vehicle.vencimentoSeguro != null)
                    _StatusChip(
                      icon: Icons.security,
                      label: _labelData('Seguro', vehicle.vencimentoSeguro),
                      status: vehicle.statusSeguro,
                    ),
                ],
              ),
              // Parcelas em aberto
              if (vehicle.proximaParcelaIpva != null) ...[
                const SizedBox(height: 10),
                _ParcelaRow(
                    label: 'IPVA',
                    parcela: vehicle.proximaParcelaIpva!,
                    total: vehicle.parcelasIpva.length,
                    pagas: vehicle.parcelasIpva.where((p) => p.pago).length,
                    onPagar: () => _pagarIpva(context, vehicle)),
              ],
              if (vehicle.proximaParcelaSeguro != null) ...[
                const SizedBox(height: 6),
                _ParcelaRow(
                    label: 'Seguro',
                    parcela: vehicle.proximaParcelaSeguro!,
                    total: vehicle.parcelasSeguro.length,
                    pagas: vehicle.parcelasSeguro.where((p) => p.pago).length,
                    onPagar: () => _pagarSeguro(context, vehicle)),
              ],
              // Ação troca de óleo
              if (vehicle.statusOleo == 'vencido' || vehicle.statusOleo == 'atencao') ...[
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.oil_barrel, size: 16),
                    label: const Text('Registrar troca de óleo'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: _primary,
                      side: const BorderSide(color: _primary),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: () => _registrarTroca(context, vehicle),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  String _labelOleo(Vehicle v) {
    if (v.kmParaTroca != null) {
      final km = v.kmParaTroca!;
      if (km <= 0) return 'Óleo vencido (${(-km).abs()} km)';
      return 'Óleo: ${km} km';
    }
    if (v.diasParaTrocaOleo != null) {
      final d = v.diasParaTrocaOleo!;
      if (d < 0) return 'Óleo vencido (${(-d)} dias)';
      return 'Óleo: $d dias';
    }
    return 'Óleo';
  }

  String _labelData(String label, DateTime? data) {
    if (data == null) return label;
    final dias = data.difference(DateTime.now()).inDays;
    if (dias < 0) return '$label vencido';
    if (dias == 0) return '$label hoje!';
    return '$label: $dias dias';
  }

  Future<void> _pagarIpva(BuildContext context, Vehicle vehicle) async {
    final idx = vehicle.parcelasIpva.indexOf(vehicle.proximaParcelaIpva!);
    final parcela = vehicle.proximaParcelaIpva!;
    final fmt = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Pagar parcela IPVA'),
        content: Text(
            'Parcela ${parcela.parcela} — ${fmt.format(parcela.valor)}\n'
            'Vencimento: ${DateFormat('dd/MM/yyyy').format(parcela.vencimento)}\n\n'
            'Marcar como paga?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar')),
          ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Confirmar')),
        ],
      ),
    );
    if (confirm == true) {
      await VehicleService.pagarParcelaIpva(vehicle, idx);
    }
  }

  Future<void> _pagarSeguro(BuildContext context, Vehicle vehicle) async {
    final idx = vehicle.parcelasSeguro.indexOf(vehicle.proximaParcelaSeguro!);
    final parcela = vehicle.proximaParcelaSeguro!;
    final fmt = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Pagar parcela Seguro'),
        content: Text(
            'Parcela ${parcela.parcela} — ${fmt.format(parcela.valor)}\n'
            'Vencimento: ${DateFormat('dd/MM/yyyy').format(parcela.vencimento)}\n\n'
            'Marcar como paga?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar')),
          ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Confirmar')),
        ],
      ),
    );
    if (confirm == true) {
      await VehicleService.pagarParcelaSeguro(vehicle, idx);
    }
  }

  Future<void> _registrarTroca(BuildContext context, Vehicle vehicle) async {
    final kmController =
        TextEditingController(text: vehicle.kmAtual?.toString() ?? '');
    final intervaloController = TextEditingController(text: '10000');

    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Registrar troca de óleo'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: kmController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                  labelText: 'Km atual', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: intervaloController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                  labelText: 'Intervalo entre trocas (km)',
                  border: OutlineInputBorder()),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final km = int.tryParse(kmController.text);
              final intervalo = int.tryParse(intervaloController.text) ?? 10000;
              if (km != null) {
                await VehicleService.registrarTrocaOleo(vehicle.id, km, intervalo);
              }
            },
            child: const Text('Salvar'),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Chip de status colorido
// ─────────────────────────────────────────────
class _StatusChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final String status; // 'ok', 'atencao', 'vencido'

  const _StatusChip(
      {required this.icon, required this.label, required this.status});

  Color get _bg {
    if (status == 'vencido') return Colors.red[50]!;
    if (status == 'atencao') return Colors.orange[50]!;
    return Colors.green[50]!;
  }

  Color get _fg {
    if (status == 'vencido') return Colors.red[700]!;
    if (status == 'atencao') return Colors.orange[800]!;
    return Colors.green[700]!;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: _bg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: _fg),
          const SizedBox(width: 4),
          Text(label,
              style: TextStyle(
                  fontSize: 12, color: _fg, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Linha de parcela
// ─────────────────────────────────────────────
class _ParcelaRow extends StatelessWidget {
  final String label;
  final VehicleInstallment parcela;
  final int total;
  final int pagas;
  final VoidCallback onPagar;

  const _ParcelaRow({
    required this.label,
    required this.parcela,
    required this.total,
    required this.pagas,
    required this.onPagar,
  });

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');
    final venc = DateFormat('dd/MM/yy').format(parcela.vencimento);
    final atrasada = parcela.vencimento.isBefore(DateTime.now());

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: atrasada ? Colors.red[50] : Colors.blue[50],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(Icons.payments_outlined,
              size: 16, color: atrasada ? Colors.red[700] : Colors.blue[700]),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '$label ${pagas + 1}/$total — ${fmt.format(parcela.valor)} · vence $venc',
              style: TextStyle(
                  fontSize: 12,
                  color: atrasada ? Colors.red[800] : Colors.blue[800]),
            ),
          ),
          TextButton(
            onPressed: onPagar,
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              foregroundColor:
                  atrasada ? Colors.red[700] : const Color(0xFF7B5EA7),
            ),
            child: const Text('Pagar', style: TextStyle(fontSize: 12)),
          ),
        ],
      ),
    );
  }
}
