import 'package:geolocator/geolocator.dart';

/// Serviço de localização baseado em [Geolocator].
class LocationService {
  /// Garante permissão e serviço ativos. Lança [Exception] se negado.
  static Future<void> _ensurePermission() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw Exception('Serviço de localização desativado.');
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      throw Exception('Permissão de localização negada.');
    }
  }

  /// Retorna a posição atual do dispositivo.
  static Future<Position> getCurrentPosition() async {
    await _ensurePermission();
    return Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );
  }

  /// Posição aproximada para a previsão do tempo da Molly — NUNCA pede
  /// permissão (só usa se já foi concedida), precisão baixa, última posição
  /// conhecida primeiro e no máximo [limite] de espera. `null` em qualquer
  /// problema: a Molly então pergunta a cidade.
  static Future<Position?> posicaoAproximadaSemPedir({
    Duration limite = const Duration(seconds: 2),
  }) async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) return null;
      final permissao = await Geolocator.checkPermission();
      if (permissao != LocationPermission.always &&
          permissao != LocationPermission.whileInUse) {
        return null;
      }
      final ultima = await Geolocator.getLastKnownPosition();
      if (ultima != null) return ultima;
      return await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.low,
        timeLimit: limite,
      );
    } catch (_) {
      return null;
    }
  }

  /// Stream contínuo de posições (útil para acompanhamento em tempo real).
  static Stream<Position> positionStream({
    int distanceFilter = 10,
  }) {
    return Geolocator.getPositionStream(
      locationSettings: LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: distanceFilter,
      ),
    );
  }
}
