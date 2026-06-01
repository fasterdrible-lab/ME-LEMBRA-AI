import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/vehicle.dart';

class VehicleService {
  static final _db = FirebaseFirestore.instance;

  static String? get _userId => FirebaseAuth.instance.currentUser?.uid;

  static CollectionReference<Map<String, dynamic>> get _col =>
      _db.collection('users').doc(_userId).collection('vehicles');

  /// Stream em tempo real
  static Stream<List<Vehicle>> stream() {
    if (_userId == null) return const Stream.empty();
    return _col
        .orderBy('updatedAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map(Vehicle.fromFirestore).toList());
  }

  /// Adicionar veículo
  static Future<void> add(Vehicle vehicle) async {
    if (_userId == null) return;
    await _col.add(vehicle.toFirestore());
  }

  /// Atualizar veículo
  static Future<void> update(Vehicle vehicle) async {
    if (_userId == null) return;
    await _col.doc(vehicle.id).update(vehicle.toFirestore());
  }

  /// Deletar veículo
  static Future<void> delete(String id) async {
    if (_userId == null) return;
    await _col.doc(id).delete();
  }

  /// Marcar parcela do IPVA como paga
  static Future<void> pagarParcelaIpva(Vehicle vehicle, int indiceParcela) async {
    if (_userId == null) return;
    final novasParcelas = List<VehicleInstallment>.from(vehicle.parcelasIpva);
    novasParcelas[indiceParcela] = novasParcelas[indiceParcela].copyWith(pago: true);
    await _col.doc(vehicle.id).update({
      'parcelasIpva': novasParcelas.map((e) => e.toMap()).toList(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Marcar parcela do seguro como paga
  static Future<void> pagarParcelaSeguro(Vehicle vehicle, int indiceParcela) async {
    if (_userId == null) return;
    final novasParcelas = List<VehicleInstallment>.from(vehicle.parcelasSeguro);
    novasParcelas[indiceParcela] = novasParcelas[indiceParcela].copyWith(pago: true);
    await _col.doc(vehicle.id).update({
      'parcelasSeguro': novasParcelas.map((e) => e.toMap()).toList(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Atualizar quilometragem atual
  static Future<void> atualizarKm(String vehicleId, int kmAtual) async {
    if (_userId == null) return;
    await _col.doc(vehicleId).update({
      'kmAtual': kmAtual,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Registrar troca de óleo (reseta data e define próxima km)
  static Future<void> registrarTrocaOleo(
      String vehicleId, int kmAtual, int intervaloKm) async {
    if (_userId == null) return;
    await _col.doc(vehicleId).update({
      'kmAtual': kmAtual,
      'kmProximaTroca': kmAtual + intervaloKm,
      'dataUltimaTroca': Timestamp.fromDate(DateTime.now()),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }
}
