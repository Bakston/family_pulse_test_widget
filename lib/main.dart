import 'dart:async';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

void main() {
  runApp(const FamilyPulseGeoTestApp());
}

class FamilyPulseGeoTestApp extends StatelessWidget {
  const FamilyPulseGeoTestApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Family Pulse — Geo Widget Test',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: const Color(0xFF1F6F54),
        scaffoldBackgroundColor: const Color(0xFFF6F8F7),
      ),
      home: const GeoWidgetTestScreen(),
    );
  }
}

class GeoWidgetTestScreen extends StatefulWidget {
  const GeoWidgetTestScreen({super.key});

  @override
  State<GeoWidgetTestScreen> createState() => _GeoWidgetTestScreenState();
}

class _GeoWidgetTestScreenState extends State<GeoWidgetTestScreen> {
  final MapController _mapController = MapController();

  // Стартовая точка по умолчанию (Екатеринбург) до получения реальных координат
  LatLng _currentPosition = const LatLng(56.8389, 60.6057);
  double? _accuracyMeters;
  String _statusText = 'Готово к проверке геолокации';
  bool _isTracking = false;
  StreamSubscription<Position>? _positionSubscription;

  Future<bool> _ensureLocationPermission() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      setState(() => _statusText = 'Служба геолокации на устройстве отключена');
      return false;
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.denied) {
      setState(() => _statusText = 'Доступ к геопозиции отклонён');
      return false;
    }

    if (permission == LocationPermission.deniedForever) {
      setState(
        () => _statusText =
            'Доступ запрещён навсегда — откройте настройки приложения',
      );
      return false;
    }

    return true;
  }

  Future<void> _getCurrentPoint() async {
    final hasPermission = await _ensureLocationPermission();
    if (!hasPermission) return;

    setState(() => _statusText = 'Получение текущих координат...');

    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );
      final point = LatLng(position.latitude, position.longitude);

      setState(() {
        _currentPosition = point;
        _accuracyMeters = position.accuracy;
        _statusText =
            'Точка: ${position.latitude.toStringAsFixed(5)}, ${position.longitude.toStringAsFixed(5)}';
      });
      _mapController.move(point, 15);
    } catch (e) {
      setState(() => _statusText = 'Ошибка получения координат: $e');
    }
  }

  Future<void> _togglePositionStream() async {
    if (_isTracking) {
      await _positionSubscription?.cancel();
      _positionSubscription = null;
      setState(() {
        _isTracking = false;
        _statusText = 'Поток обновлений остановлен';
      });
      return;
    }

    final hasPermission = await _ensureLocationPermission();
    if (!hasPermission) return;

    const locationSettings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 10,
    );

    _positionSubscription = Geolocator.getPositionStream(
      locationSettings: locationSettings,
    ).listen(
      (Position position) {
        final point = LatLng(position.latitude, position.longitude);
        setState(() {
          _currentPosition = point;
          _accuracyMeters = position.accuracy;
          _statusText =
              'Поток: ${position.latitude.toStringAsFixed(5)}, ${position.longitude.toStringAsFixed(5)}';
        });
        _mapController.move(point, _mapController.camera.zoom);
      },
      onError: (Object error) {
        setState(() => _statusText = 'Ошибка потока геолокации: $error');
      },
    );

    setState(() {
      _isTracking = true;
      _statusText = 'Поток обновлений запущен (шаг от 10 м)';
    });
  }

  @override
  void dispose() {
    _positionSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Family Pulse — Тест виджетов геопозиции'),
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
      ),
      body: Column(
        children: [
          Expanded(
            child: FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: _currentPosition,
                initialZoom: 13.5,
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'ru.familypulse.widgettest',
                ),
                MarkerLayer(
                  markers: [
                    Marker(
                      point: _currentPosition,
                      width: 48,
                      height: 48,
                      child: const Icon(
                        Icons.location_on,
                        size: 48,
                        color: Color(0xFFD63628),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: Color(0xFFE2E8E5))),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _statusText,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF18221E),
                  ),
                ),
                if (_accuracyMeters != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Точность: ±${_accuracyMeters!.toStringAsFixed(0)} м',
                    style: const TextStyle(
                      fontSize: 13,
                      color: Color(0xFF56655F),
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                Wrap(
                  spacing: 10,
                  runSpacing: 8,
                  children: [
                    FilledButton.icon(
                      onPressed: _getCurrentPoint,
                      icon: const Icon(Icons.my_location),
                      label: const Text('Текущая точка'),
                    ),
                    OutlinedButton.icon(
                      onPressed: _togglePositionStream,
                      icon: Icon(_isTracking ? Icons.stop : Icons.play_arrow),
                      label: Text(_isTracking ? 'Остановить поток' : 'Поток GPS'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}