import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import 'package:voltride/core/theme.dart';
import 'package:voltride/providers/app_providers.dart';

class LiveMapsPage extends ConsumerStatefulWidget {
  const LiveMapsPage({super.key});

  @override
  ConsumerState<LiveMapsPage> createState() => _LiveMapsPageState();
}

class _LiveMapsPageState extends ConsumerState<LiveMapsPage> {
  final MapController _mapController = MapController();
  bool _autoCenter = true;
  bool _isSatellite = false;

  @override
  Widget build(BuildContext context) {
    final currentPos = ref.watch(currentPositionProvider);
    final tripPoints = ref.watch(currentTripPointsProvider);
    final isRecording = ref.watch(isRecordingProvider);

    final LatLng center = currentPos != null
        ? LatLng(currentPos.latitude, currentPos.longitude)
        : const LatLng(-6.200000, 106.816666); // Jakarta Default

    // If autoCenter is enabled and we get a new position, move the map center
    if (_autoCenter && currentPos != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _mapController.move(center, _mapController.camera.zoom);
      });
    }

    final List<LatLng> polylinePoints = tripPoints
        .map((p) => LatLng(p.latitude, p.longitude))
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('LIVE MAPS'),
        actions: [
          IconButton(
            icon: Icon(
              _isSatellite ? Icons.map : Icons.satellite,
              color: VoltRideTheme.neonGreen,
            ),
            tooltip: _isSatellite ? 'Switch to Normal Map' : 'Switch to Satellite Map',
            onPressed: () {
              setState(() {
                _isSatellite = !_isSatellite;
              });
            },
          ),
          IconButton(
            icon: Icon(
              _autoCenter ? Icons.gps_fixed : Icons.gps_not_fixed,
              color: _autoCenter ? VoltRideTheme.electricBlue : VoltRideTheme.textSecondary,
            ),
            tooltip: 'Auto Center Location',
            onPressed: () {
              setState(() {
                _autoCenter = !_autoCenter;
              });
              if (_autoCenter && currentPos != null) {
                _mapController.move(center, _mapController.camera.zoom);
              }
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: center,
              initialZoom: 16.0,
              onPositionChanged: (position, hasGesture) {
                if (hasGesture && _autoCenter) {
                  setState(() {
                    _autoCenter = false;
                  });
                }
              },
            ),
            children: [
              TileLayer(
                urlTemplate: _isSatellite 
                    ? 'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}'
                    : 'https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}{r}.png',
                subdomains: const ['a', 'b', 'c', 'd'],
                userAgentPackageName: 'com.voltride.app',
              ),
              if (polylinePoints.isNotEmpty)
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: polylinePoints,
                      color: VoltRideTheme.electricBlue,
                      strokeWidth: 4.5,
                    ),
                  ],
                ),
              // Markers Layer
              MarkerLayer(
                markers: [
                  // Start point marker (if recording and has points)
                  if (polylinePoints.isNotEmpty)
                    Marker(
                      point: polylinePoints.first,
                      width: 24,
                      height: 24,
                      child: Container(
                        decoration: BoxDecoration(
                          color: VoltRideTheme.neonGreen,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                        child: const Icon(
                          Icons.play_arrow,
                          color: Colors.black,
                          size: 12,
                        ),
                      ),
                    ),
                  // Current user location marker
                  Marker(
                    point: center,
                    width: 40,
                    height: 40,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        // Ripple pulse glow
                        _LocationPulseAnimation(color: VoltRideTheme.electricBlue),
                        Container(
                          width: 16,
                          height: 16,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: VoltRideTheme.electricBlue,
                            border: Border.all(color: Colors.white, width: 2),
                            boxShadow: [
                              BoxShadow(
                                color: VoltRideTheme.electricBlue.withOpacity(0.8),
                                blurRadius: 10,
                                spreadRadius: 3,
                              ),
                            ],
                          ),
                        ),
                        if (currentPos != null && currentPos.heading > 0)
                          Transform.rotate(
                            angle: currentPos.heading * (3.14159 / 180),
                            child: const Icon(
                              Icons.navigation,
                              color: VoltRideTheme.electricBlue,
                              size: 28,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),

          // Zoom control overlay
          Positioned(
            right: 16,
            bottom: 32,
            child: Column(
              children: [
                FloatingActionButton(
                  heroTag: 'zoom_in',
                  mini: true,
                  backgroundColor: VoltRideTheme.surface.withOpacity(0.9),
                  foregroundColor: Colors.white,
                  child: const Icon(Icons.add),
                  onPressed: () {
                    _mapController.move(
                      _mapController.camera.center,
                      _mapController.camera.zoom + 1.0,
                    );
                  },
                ),
                const SizedBox(height: 8),
                FloatingActionButton(
                  heroTag: 'zoom_out',
                  mini: true,
                  backgroundColor: VoltRideTheme.surface.withOpacity(0.9),
                  foregroundColor: Colors.white,
                  child: const Icon(Icons.remove),
                  onPressed: () {
                    _mapController.move(
                      _mapController.camera.center,
                      _mapController.camera.zoom - 1.0,
                    );
                  },
                ),
              ],
            ),
          ),

          // Telemetry Floating Bar Overlay
          if (isRecording && currentPos != null)
            Positioned(
              top: 16,
              left: 16,
              right: 16,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: VoltRideTheme.glassCard(),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          'SPEED',
                          style: TextStyle(
                            color: VoltRideTheme.textSecondary,
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.2,
                          ),
                        ),
                        Text(
                          '${currentPos.speedKmh.toStringAsFixed(1)} km/h',
                          style: const TextStyle(
                            color: VoltRideTheme.electricBlue,
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          'ALTITUDE',
                          style: TextStyle(
                            color: VoltRideTheme.textSecondary,
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.2,
                          ),
                        ),
                        Text(
                          '${currentPos.altitude.toStringAsFixed(0)} m',
                          style: const TextStyle(
                            color: VoltRideTheme.voltYellow,
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          'GPS ACCURACY',
                          style: TextStyle(
                            color: VoltRideTheme.textSecondary,
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.2,
                          ),
                        ),
                        Text(
                          '±${currentPos.accuracy.toStringAsFixed(1)} m',
                          style: TextStyle(
                            color: currentPos.accuracy < 10
                                ? VoltRideTheme.neonGreen
                                : VoltRideTheme.powerOrange,
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _LocationPulseAnimation extends StatefulWidget {
  final Color color;

  const _LocationPulseAnimation({required this.color});

  @override
  State<_LocationPulseAnimation> createState() => _LocationPulseAnimationState();
}

class _LocationPulseAnimationState extends State<_LocationPulseAnimation>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _pulseController,
      builder: (context, child) {
        return Container(
          width: 32 * _pulseController.value,
          height: 32 * _pulseController.value,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: widget.color.withOpacity(0.4 * (1.0 - _pulseController.value)),
          ),
        );
      },
    );
  }
}
