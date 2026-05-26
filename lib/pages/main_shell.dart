import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:voltride/core/theme.dart';
import 'package:voltride/pages/dashboard_page.dart';
import 'package:voltride/pages/live_maps_page.dart';
import 'package:voltride/pages/settings_page.dart';
import 'package:voltride/pages/trip_history_page.dart';
import 'package:voltride/providers/app_providers.dart';

import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:voltride/services/ble_service.dart';

class MainShell extends ConsumerStatefulWidget {
  const MainShell({super.key});

  @override
  ConsumerState<MainShell> createState() => _MainShellState();
}

class _MainShellState extends ConsumerState<MainShell> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _tryAutoConnect();
    });
  }

  Future<void> _tryAutoConnect() async {
    final settings = ref.read(settingsProvider);
    if (settings.lastConnectedDeviceId != null && settings.lastConnectedDeviceId!.isNotEmpty) {
      // Don't auto-connect to the simulator
      if (settings.lastConnectedDeviceId == 'SIM-001') return;

      final bleService = ref.read(bleServiceProvider);
      if (bleService.state == BleConnectionState.disconnected) {
        try {
          final device = BluetoothDevice.fromId(settings.lastConnectedDeviceId!);
          final success = await bleService.connectToDevice(device);
          if (success) {
            ref.read(jkBmsServiceProvider).startListening();
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Auto-connected to ${settings.lastConnectedDeviceName ?? 'BMS'}!'),
                  backgroundColor: VoltRideTheme.neonGreen,
                  behavior: SnackBarBehavior.floating,
                ),
              );
            }
          }
        } catch (e) {
          debugPrint('Auto connect failed: $e');
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final pageIndex = ref.watch(currentPageIndexProvider);

    final List<Widget> pages = [
      const DashboardPage(),
      const LiveMapsPage(),
      const TripHistoryPage(),
      const SettingsPage(),
    ];

    return Scaffold(
      body: IndexedStack(
        index: pageIndex,
        children: pages,
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          border: Border(
            top: BorderSide(
              color: VoltRideTheme.cardBorder.withOpacity(0.5),
              width: 1,
            ),
          ),
        ),
        child: BottomNavigationBar(
          currentIndex: pageIndex,
          onTap: (index) {
            ref.read(currentPageIndexProvider.notifier).state = index;
          },
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.dashboard_outlined),
              activeIcon: Icon(Icons.dashboard),
              label: 'DASHBOARD',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.map_outlined),
              activeIcon: Icon(Icons.map),
              label: 'MAPS',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.history_outlined),
              activeIcon: Icon(Icons.history),
              label: 'HISTORY',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.settings_outlined),
              activeIcon: Icon(Icons.settings),
              label: 'SETTINGS',
            ),
          ],
        ),
      ),
    );
  }
}
