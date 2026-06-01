import 'package:cloud_firestore/cloud_firestore.dart';

class VehicleInstallment {
  final int parcela;
  final double valor;
  final DateTime vencimento;
  final bool pago;

  VehicleInstallment({
    required this.parcela,
    required this.valor,
    required this.vencimento,
    this.pago = false,
  });

  factory VehicleInstallment.fromMap(Map<String, dynamic> m) =>
      VehicleInstallment(
        parcela: (m['parcela'] as num).toInt(),
        valor: (m['valor'] as num).toDouble(),
        vencimento: (m['vencimento'] as Timestamp).toDate(),
        pago: m['pago'] ?? false,
      );

  Map<String, dynamic> toMap() => {
        'parcela': parcela,
        'valor': valor,
        'vencimento': Timestamp.fromDate(vencimento),
        'pago': pago,
      };

  VehicleInstallment copyWith({bool? pago}) => VehicleInstallment(
        parcela: parcela,
        valor: valor,
        vencimento: vencimento,
        pago: pago ?? this.pago,
      );
}

class Vehicle {
  final String id;
  final String userId;
  final String apelido; // ex: "Meu Gol", "Moto"
  final String placa;

  // Troca de óleo
  final int? kmAtual;
  final int? kmProximaTroca;
  final DateTime? dataUltimaTroca;

  // IPVA
  final int? anoIpva;
  final double? valorIpva;
  final DateTime? vencimentoIpva;
  final List<VehicleInstallment> parcelasIpva;

  // CNH
  final DateTime? vencimentoCnh;

  // Seguro
  final DateTime? vencimentoSeguro;
  final double? valorSeguro;
  final List<VehicleInstallment> parcelasSeguro;

  Vehicle({
    required this.id,
    required this.userId,
    required this.apelido,
    required this.placa,
    this.kmAtual,
    this.kmProximaTroca,
    this.dataUltimaTroca,
    this.anoIpva,
    this.valorIpva,
    this.vencimentoIpva,
    this.parcelasIpva = const [],
    this.vencimentoCnh,
    this.vencimentoSeguro,
    this.valorSeguro,
    this.parcelasSeguro = const [],
  });

  factory Vehicle.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return Vehicle(
      id: doc.id,
      userId: d['userId'] ?? '',
      apelido: d['apelido'] ?? '',
      placa: d['placa'] ?? '',
      kmAtual: d['kmAtual'] != null ? (d['kmAtual'] as num).toInt() : null,
      kmProximaTroca: d['kmProximaTroca'] != null ? (d['kmProximaTroca'] as num).toInt() : null,
      dataUltimaTroca: d['dataUltimaTroca'] != null
          ? (d['dataUltimaTroca'] as Timestamp).toDate()
          : null,
      anoIpva: d['anoIpva'] != null ? (d['anoIpva'] as num).toInt() : null,
      valorIpva: d['valorIpva'] != null ? (d['valorIpva'] as num).toDouble() : null,
      vencimentoIpva: d['vencimentoIpva'] != null
          ? (d['vencimentoIpva'] as Timestamp).toDate()
          : null,
      parcelasIpva: d['parcelasIpva'] != null
          ? (d['parcelasIpva'] as List)
              .map((e) => VehicleInstallment.fromMap(e as Map<String, dynamic>))
              .toList()
          : [],
      vencimentoCnh: d['vencimentoCnh'] != null
          ? (d['vencimentoCnh'] as Timestamp).toDate()
          : null,
      vencimentoSeguro: d['vencimentoSeguro'] != null
          ? (d['vencimentoSeguro'] as Timestamp).toDate()
          : null,
      valorSeguro: d['valorSeguro'] != null ? (d['valorSeguro'] as num).toDouble() : null,
      parcelasSeguro: d['parcelasSeguro'] != null
          ? (d['parcelasSeguro'] as List)
              .map((e) => VehicleInstallment.fromMap(e as Map<String, dynamic>))
              .toList()
          : [],
    );
  }

  Map<String, dynamic> toFirestore() => {
        'userId': userId,
        'apelido': apelido,
        'placa': placa,
        'kmAtual': kmAtual,
        'kmProximaTroca': kmProximaTroca,
        'dataUltimaTroca':
            dataUltimaTroca != null ? Timestamp.fromDate(dataUltimaTroca!) : null,
        'anoIpva': anoIpva,
        'valorIpva': valorIpva,
        'vencimentoIpva':
            vencimentoIpva != null ? Timestamp.fromDate(vencimentoIpva!) : null,
        'parcelasIpva': parcelasIpva.map((e) => e.toMap()).toList(),
        'vencimentoCnh':
            vencimentoCnh != null ? Timestamp.fromDate(vencimentoCnh!) : null,
        'vencimentoSeguro':
            vencimentoSeguro != null ? Timestamp.fromDate(vencimentoSeguro!) : null,
        'valorSeguro': valorSeguro,
        'parcelasSeguro': parcelasSeguro.map((e) => e.toMap()).toList(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

  Vehicle copyWith({
    String? apelido,
    String? placa,
    int? kmAtual,
    int? kmProximaTroca,
    DateTime? dataUltimaTroca,
    int? anoIpva,
    double? valorIpva,
    DateTime? vencimentoIpva,
    List<VehicleInstallment>? parcelasIpva,
    DateTime? vencimentoCnh,
    DateTime? vencimentoSeguro,
    double? valorSeguro,
    List<VehicleInstallment>? parcelasSeguro,
  }) =>
      Vehicle(
        id: id,
        userId: userId,
        apelido: apelido ?? this.apelido,
        placa: placa ?? this.placa,
        kmAtual: kmAtual ?? this.kmAtual,
        kmProximaTroca: kmProximaTroca ?? this.kmProximaTroca,
        dataUltimaTroca: dataUltimaTroca ?? this.dataUltimaTroca,
        anoIpva: anoIpva ?? this.anoIpva,
        valorIpva: valorIpva ?? this.valorIpva,
        vencimentoIpva: vencimentoIpva ?? this.vencimentoIpva,
        parcelasIpva: parcelasIpva ?? this.parcelasIpva,
        vencimentoCnh: vencimentoCnh ?? this.vencimentoCnh,
        vencimentoSeguro: vencimentoSeguro ?? this.vencimentoSeguro,
        valorSeguro: valorSeguro ?? this.valorSeguro,
        parcelasSeguro: parcelasSeguro ?? this.parcelasSeguro,
      );

  // --- Lógica de alertas ---

  /// Retorna true se a troca de óleo está vencida por km ou por 6 meses
  bool get trocaOleoVencida {
    if (kmProximaTroca != null && kmAtual != null && kmAtual! >= kmProximaTroca!) {
      return true;
    }
    if (dataUltimaTroca != null) {
      final limite = dataUltimaTroca!.add(const Duration(days: 180));
      if (DateTime.now().isAfter(limite)) return true;
    }
    return false;
  }

  /// Dias restantes para troca de óleo por data (negativo = vencido)
  int? get diasParaTrocaOleo {
    if (dataUltimaTroca == null) return null;
    final limite = dataUltimaTroca!.add(const Duration(days: 180));
    return limite.difference(DateTime.now()).inDays;
  }

  /// Km restante para troca (negativo = vencido)
  int? get kmParaTroca {
    if (kmAtual == null || kmProximaTroca == null) return null;
    return kmProximaTroca! - kmAtual!;
  }

  /// Status geral de alerta: 'ok', 'atencao' (≤30 dias), 'vencido'
  String statusVencimento(DateTime? data) {
    if (data == null) return 'ok';
    final dias = data.difference(DateTime.now()).inDays;
    if (dias < 0) return 'vencido';
    if (dias <= 30) return 'atencao';
    return 'ok';
  }

  String get statusIpva => statusVencimento(vencimentoIpva);
  String get statusCnh => statusVencimento(vencimentoCnh);
  String get statusSeguro => statusVencimento(vencimentoSeguro);
  String get statusOleo {
    if (trocaOleoVencida) return 'vencido';
    if (diasParaTrocaOleo != null && diasParaTrocaOleo! <= 30) return 'atencao';
    if (kmParaTroca != null && kmParaTroca! <= 500) return 'atencao';
    return 'ok';
  }

  /// Parcelas do IPVA em aberto
  List<VehicleInstallment> get parcelasIpvaEmAberto =>
      parcelasIpva.where((p) => !p.pago).toList();

  /// Parcelas do seguro em aberto
  List<VehicleInstallment> get parcelasSeguroEmAberto =>
      parcelasSeguro.where((p) => !p.pago).toList();

  /// Próxima parcela de IPVA a vencer
  VehicleInstallment? get proximaParcelaIpva {
    final abertas = parcelasIpvaEmAberto
      ..sort((a, b) => a.vencimento.compareTo(b.vencimento));
    return abertas.isEmpty ? null : abertas.first;
  }

  /// Próxima parcela de seguro a vencer
  VehicleInstallment? get proximaParcelaSeguro {
    final abertas = parcelasSeguroEmAberto
      ..sort((a, b) => a.vencimento.compareTo(b.vencimento));
    return abertas.isEmpty ? null : abertas.first;
  }

  /// Tem algum alerta crítico
  bool get temAlerta =>
      statusOleo != 'ok' ||
      statusIpva != 'ok' ||
      statusCnh != 'ok' ||
      statusSeguro != 'ok';
}
