import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:voltride/core/theme.dart';
import 'package:voltride/pages/dashboard_page.dart';
import 'package:voltride/pages/live_maps_page.dart';
import 'package:voltride/pages/settings_page.dart';
import 'package:voltride/pages/trip_history_page.dart';
import 'package:voltride/providers/app_providers.dart';

class MainShell extends ConsumerWidget {
  const MainShell({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
