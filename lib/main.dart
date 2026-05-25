import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:ui';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:voltride/core/theme.dart';
import 'package:voltride/pages/splash_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Catch and display all Flutter Errors clearly on the screen (even in release/web)
  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
    debugPrint('FLUTTER ERROR: ${details.exception}\nStack: ${details.stack}');
  };

  PlatformDispatcher.instance.onError = (Object error, StackTrace stack) {
    debugPrint('PLATFORM ERROR: $error\nStack: $stack');
    return false; // Let the error propagate
  };

  ErrorWidget.builder = (FlutterErrorDetails details) {
    return Scaffold(
      backgroundColor: VoltRideTheme.surface,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, color: VoltRideTheme.alertRed, size: 64),
              const SizedBox(height: 24),
              const Text(
                'VoltRide - Initialization Error',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
              ),
              const SizedBox(height: 12),
              Text(
                details.exception.toString(),
                style: const TextStyle(color: VoltRideTheme.voltYellow, fontSize: 14),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: VoltRideTheme.cardBorder),
                ),
                child: Text(
                  details.stack.toString().split('\n').take(8).join('\n'),
                  style: const TextStyle(fontSize: 11, color: VoltRideTheme.textMuted, fontFamily: 'monospace'),
                  textAlign: TextAlign.left,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  };

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
