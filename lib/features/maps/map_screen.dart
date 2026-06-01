import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../services/location_service.dart';
import '../../services/sos_service.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  static const Color _primary = Color(0xFF7B5EA7);
  static const Color _danger = Color(0xFFE53935);

  GoogleMapController? _mapController;
  double? _lat;
  double? _lng;
  bool _loading = true;
  String? _error;
  bool _sosSending = false;

  @override
  void initState() {
    super.initState();
    _loadLocation();
  }

  @override
  void dispose() {
    _mapController?.dispose();
    super.dispose();
  }

  Future<void> _loadLocation() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final pos = await LocationService.getCurrentPosition();
      if (!mounted) return;
      setState(() {
        _lat = pos.latitude;
        _lng = pos.longitude;
        _loading = false;
      });
      _mapController?.animateCamera(
        CameraUpdate.newLatLngZoom(LatLng(pos.latitude, pos.longitude), 16),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = _friendlyError(e.toString());
        _loading = false;
      });
    }
  }

  String _friendlyError(String raw) {
    if (raw.contains('negada') || raw.contains('denied')) {
      return 'Permissão de localização negada.\nAbra Configurações > Aplicativos > Me Lembra Aí > Permissões e ative a Localização.';
    }
    if (raw.contains('desativado') || raw.contains('disabled')) {
      return 'Serviço de localização desativado.\nAtivar em Configurações > Localização.';
    }
    return 'Não foi possível obter a localização.\n$raw';
  }

  Future<void> _sendSos() async {
    setState(() => _sosSending = true);
    try {
      await SosService.trigger(motivo: 'manual');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('SOS enviado com sua localização!'),
            backgroundColor: Color(0xFFE53935),
            duration: Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao enviar SOS: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _sosSending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Minha Localização'),
        backgroundColor: _primary,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Atualizar localização',
            onPressed: _loading ? null : _loadLocation,
          ),
        ],
      ),
      body: _buildBody(),
      floatingActionButton: (_lat != null && _lng != null)
          ? FloatingActionButton.extended(
              onPressed: _sosSending ? null : _sendSos,
              backgroundColor: _danger,
              foregroundColor: Colors.white,
              icon: _sosSending
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2),
                    )
                  : const Icon(Icons.sos),
              label: Text(_sosSending ? 'Enviando...' : 'Enviar SOS com localização'),
            )
          : null,
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: Color(0xFF7B5EA7)),
            SizedBox(height: 16),
            Text('Obtendo localização...'),
          ],
        ),
      );
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.location_off, size: 72, color: Colors.grey),
              const SizedBox(height: 20),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _loadLocation,
                icon: const Icon(Icons.refresh),
                label: const Text('Tentar novamente'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _primary,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        ),
      );
    }

    final lat = _lat!;
    final lng = _lng!;

    return Stack(
      children: [
        GoogleMap(
          initialCameraPosition: CameraPosition(
            target: LatLng(lat, lng),
            zoom: 16,
          ),
          onMapCreated: (c) {
            _mapController = c;
            c.animateCamera(
              CameraUpdate.newLatLngZoom(LatLng(lat, lng), 16),
            );
          },
          myLocationEnabled: true,
          myLocationButtonEnabled: true,
          zoomControlsEnabled: true,
          mapToolbarEnabled: false,
          markers: {
            Marker(
              markerId: const MarkerId('eu'),
              position: LatLng(lat, lng),
              infoWindow: const InfoWindow(
                title: 'Você está aqui',
                snippet: 'Toque em SOS para enviar esta localização',
              ),
            ),
          },
        ),
        // Coordenadas no rodapé
        Positioned(
          bottom: 80,
          left: 16,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.9),
              borderRadius: BorderRadius.circular(8),
              boxShadow: [
                BoxShadow(blurRadius: 4, color: Colors.black.withOpacity(0.1)),
              ],
            ),
            child: Text(
              '${lat.toStringAsFixed(5)}, ${lng.toStringAsFixed(5)}',
              style: const TextStyle(fontSize: 12, color: Colors.black87),
            ),
          ),
        ),
      ],
    );
  }
}
