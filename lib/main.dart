import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:voltride/core/theme.dart';
import 'package:voltride/pages/splash_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Force dark mode system navigation bar and overlay colors
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: VoltRideTheme.surface,
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );

  // Keep screen on during dashboard/telemetry usage
  try {
    await WakelockPlus.enable();
  } catch (e) {
    debugPrint('Wakelock not supported on this platform: $e');
  }

  runApp(
    const ProviderScope(
      child: VoltRideApp(),
    ),
  );
}

class VoltRideApp extends StatelessWidget {
  const VoltRideApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'VoltRide EV Dashboard',
      debugShowCheckedModeBanner: false,
      theme: VoltRideTheme.darkTheme,
      home: const SplashPage(),
    );
  }
}
