import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:voltride/core/theme.dart';
import 'package:voltride/providers/app_providers.dart';

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final settingsNotifier = ref.read(settingsProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        title: const Text('SETTINGS'),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: VoltRideTheme.backgroundGradient,
        ),
        child: ListView(
          padding: const EdgeInsets.all(16),
          physics: const BouncingScrollPhysics(),
          children: [
            // ── Preference Section ──
            _buildSectionHeader('PREFERENCES'),
            const SizedBox(height: 8),
            Container(
              decoration: VoltRideTheme.glassCard(),
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.tune_outlined, color: VoltRideTheme.electricBlue),
                    title: const Text('Measurement Units', style: TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: Text(settings.useMetric ? 'Metric (km, km/h)' : 'Imperial (mi, mph)',
                        style: const TextStyle(color: VoltRideTheme.textSecondary, fontSize: 12)),
                    trailing: Switch(
                      value: settings.useMetric,
                      activeColor: VoltRideTheme.neonGreen,
                      onChanged: (val) {
                        settingsNotifier.setUseMetric(val);
                      },
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // ── Auto Tracking Settings ──
            _buildSectionHeader('AUTO TRACKING'),
            const SizedBox(height: 8),
            Container(
              decoration: VoltRideTheme.glassCard(),
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.play_circle_outline, color: VoltRideTheme.neonGreen),
                    title: const Text('Auto-Start Recording', style: TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: const Text('Automatically record trip when speed exceeds 5 km/h',
                        style: TextStyle(color: VoltRideTheme.textSecondary, fontSize: 12)),
                    trailing: Switch(
                      value: settings.autoStartTrip,
                      activeColor: VoltRideTheme.neonGreen,
                      onChanged: (val) {
                        settingsNotifier.setAutoStartTrip(val);
                      },
                    ),
                  ),
                  const Divider(color: VoltRideTheme.cardBorder, height: 1),
                  ListTile(
                    leading: const Icon(Icons.stop_circle_outline, color: VoltRideTheme.alertRed),
                    title: const Text('Auto-Stop Recording', style: TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: const Text('Automatically stop recording when idle for 5 minutes',
                        style: TextStyle(color: VoltRideTheme.textSecondary, fontSize: 12)),
                    trailing: Switch(
                      value: settings.autoStopTrip,
                      activeColor: VoltRideTheme.neonGreen,
                      onChanged: (val) {
                        settingsNotifier.setAutoStopTrip(val);
                      },
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // ── Service Parameters ──
            _buildSectionHeader('SERVICE PARAMETERS'),
            const SizedBox(height: 8),
            Container(
              decoration: VoltRideTheme.glassCard(),
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.gps_fixed, color: VoltRideTheme.voltYellow),
                    title: const Text('GPS Polling Rate', style: TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: Text('Interval: ${(settings.gpsIntervalMs / 1000).toStringAsFixed(1)}s',
                        style: const TextStyle(color: VoltRideTheme.textSecondary, fontSize: 12)),
                    trailing: DropdownButton<int>(
                      value: settings.gpsIntervalMs,
                      dropdownColor: VoltRideTheme.surface,
                      underline: const SizedBox(),
                      items: const [
                        DropdownMenuItem(value: 500, child: Text('0.5s', style: TextStyle(fontSize: 13))),
                        DropdownMenuItem(value: 1000, child: Text('1.0s', style: TextStyle(fontSize: 13))),
                        DropdownMenuItem(value: 2000, child: Text('2.0s', style: TextStyle(fontSize: 13))),
                        DropdownMenuItem(value: 5000, child: Text('5.0s', style: TextStyle(fontSize: 13))),
                      ],
                      onChanged: (val) {
                        if (val != null) {
                          settingsNotifier.setGpsInterval(val);
                        }
                      },
                    ),
                  ),
                  const Divider(color: VoltRideTheme.cardBorder, height: 1),
                  ListTile(
                    leading: const Icon(Icons.bluetooth, color: VoltRideTheme.purple),
                    title: const Text('BMS Update Rate', style: TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: Text('Interval: ${(settings.blePollingIntervalMs / 1000).toStringAsFixed(1)}s',
                        style: const TextStyle(color: VoltRideTheme.textSecondary, fontSize: 12)),
                    trailing: DropdownButton<int>(
                      value: settings.blePollingIntervalMs,
                      dropdownColor: VoltRideTheme.surface,
                      underline: const SizedBox(),
                      items: const [
                        DropdownMenuItem(value: 500, child: Text('0.5s', style: TextStyle(fontSize: 13))),
                        DropdownMenuItem(value: 1000, child: Text('1.0s', style: TextStyle(fontSize: 13))),
                        DropdownMenuItem(value: 3000, child: Text('3.0s', style: TextStyle(fontSize: 13))),
                        DropdownMenuItem(value: 5000, child: Text('5.0s', style: TextStyle(fontSize: 13))),
                      ],
                      onChanged: (val) {
                        if (val != null) {
                          settingsNotifier.setBlePollingInterval(val);
                        }
                      },
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),

            // ── System Diagnostics info ──
            Center(
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: VoltRideTheme.cardBorder.withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.bolt,
                      color: VoltRideTheme.electricBlue,
                      size: 28,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'VOLTRIDE EV DASHBOARD',
                    style: GoogleFonts.outfit(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 2,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Version 1.0.0 (Production Build)',
                    style: TextStyle(color: VoltRideTheme.textMuted, fontSize: 11),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Offline-First SQLite Database Active',
                    style: TextStyle(color: VoltRideTheme.textMuted, fontSize: 10),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8.0),
      style: const TextStyle(
        color: VoltRideTheme.textPrimary,
        fontSize: 11,
        fontWeight: FontWeight.bold,
        letterSpacing: 1.5,
      ),
    );
  }
}
