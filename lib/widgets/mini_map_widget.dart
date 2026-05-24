import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import 'package:voltride/core/theme.dart';
import 'package:voltride/providers/app_providers.dart';

class MiniMapWidget extends ConsumerWidget {
  final double height;

  const MiniMapWidget({
    super.key,
    this.height = 180,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentPos = ref.watch(currentPositionProvider);
    final tripPoints = ref.watch(currentTripPointsProvider);

    final LatLng center = currentPos != null
        ? LatLng(currentPos.latitude, currentPos.longitude)
        : const LatLng(-6.200000, 106.816666); // Default: Jakarta

    final List<LatLng> polylinePoints = tripPoints
        .map((p) => LatLng(p.latitude, p.longitude))
        .toList();

    return Container(
      height: height,
      decoration: VoltRideTheme.glassCard(),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          FlutterMap(
            options: MapOptions(
              initialCenter: center,
              initialZoom: 15.0,
              interactionOptions: const InteractionOptions(
                flags: InteractiveFlag.none, // Disable all user interaction for dashboard mini map
              ),
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}{r}.png',
                subdomains: const ['a', 'b', 'c', 'd'],
                userAgentPackageName: 'com.voltride.app',
              ),
              if (polylinePoints.isNotEmpty)
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: polylinePoints,
                      color: VoltRideTheme.electricBlue,
                      strokeWidth: 4.0,
                      isDotted: false,
                    ),
                  ],
                ),
              MarkerLayer(
                markers: [
                  Marker(
                    point: center,
                    width: 32,
                    height: 32,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Container(
                          width: 24,
                          height: 24,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: VoltRideTheme.electricBlue.withOpacity(0.3),
                          ),
                        ),
                        Container(
                          width: 14,
                          height: 14,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: VoltRideTheme.electricBlue,
                            border: Border.all(color: Colors.white, width: 2),
                            boxShadow: [
                              BoxShadow(
                                color: VoltRideTheme.electricBlue.withOpacity(0.8),
                                blurRadius: 8,
                                spreadRadius: 2,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
          // Gradient Overlay to blend map edges into theme
          Positioned.fill(
            child: IgnorePointer(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      VoltRideTheme.card.withOpacity(0.6),
                      Colors.transparent,
                      Colors.transparent,
                      VoltRideTheme.card.withOpacity(0.6),
                    ],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
              ),
            ),
          ),
          // Heading / GPS indicator overlay
          Positioned(
            top: 12,
            right: 12,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: VoltRideTheme.surface.withOpacity(0.8),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: VoltRideTheme.cardBorder),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.gps_fixed,
                    color: VoltRideTheme.neonGreen,
                    size: 12,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    currentPos != null ? 'GPS Active' : 'No GPS',
                    style: const TextStyle(
                      color: VoltRideTheme.textPrimary,
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
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
