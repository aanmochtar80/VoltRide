import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:voltride/core/theme.dart';
import 'package:voltride/pages/main_shell.dart';
import 'package:voltride/services/gps_service.dart';
import 'package:voltride/providers/app_providers.dart';

class SplashPage extends ConsumerStatefulWidget {
  const SplashPage({super.key});

  @override
  ConsumerState<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends ConsumerState<SplashPage>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _opacityAnimation;
  String _statusText = 'Initializing EV Systems...';

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );

    _scaleAnimation = Tween<double>(begin: 0.6, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.6, curve: Curves.easeOutBack),
      ),
    );

    _opacityAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.4, curve: Curves.easeIn),
      ),
    );

    _controller.forward();
    _startInitSequence();
  }

  Future<void> _startInitSequence() async {
    await Future.delayed(const Duration(milliseconds: 1500));
    
    setState(() {
      _statusText = 'Requesting Location Permission...';
    });
    await Future.delayed(const Duration(milliseconds: 500));

    // Start GPS with proper permission handling
    try {
      final gpsService = ref.read(gpsServiceProvider);
      final gpsResult = await gpsService.checkAndRequestPermission();
      
      switch (gpsResult) {
        case GpsPermissionResult.granted:
          setState(() {
            _statusText = 'GPS Active — Starting Telemetry...';
          });
          await gpsService.startTracking();
          break;
        case GpsPermissionResult.serviceDisabled:
          setState(() {
            _statusText = 'GPS disabled — Enable Location in Settings';
          });
          await Future.delayed(const Duration(milliseconds: 1000));
          break;
        case GpsPermissionResult.permissionDenied:
          setState(() {
            _statusText = 'Location permission denied — GPS unavailable';
          });
          await Future.delayed(const Duration(milliseconds: 1000));
          break;
        case GpsPermissionResult.permissionDeniedForever:
          setState(() {
            _statusText = 'Location blocked — Grant in App Settings';
          });
          await Future.delayed(const Duration(milliseconds: 1000));
          break;
        case GpsPermissionResult.unsupported:
          setState(() {
            _statusText = 'GPS not supported on this platform';
          });
          await Future.delayed(const Duration(milliseconds: 500));
          break;
      }
    } catch (e) {
      debugPrint('Error starting GPS during splash: $e');
      setState(() {
        _statusText = 'GPS initialization error';
      });
      await Future.delayed(const Duration(milliseconds: 500));
    }

    setState(() {
      _statusText = 'System Diagnostics Complete. Welcome!';
    });

    await Future.delayed(const Duration(milliseconds: 800));

    if (mounted) {
      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) => const MainShell(),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(
              opacity: animation,
              child: child,
            );
          },
          transitionDuration: const Duration(milliseconds: 800),
        ),
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: VoltRideTheme.backgroundGradient,
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedBuilder(
                animation: _controller,
                builder: (context, child) {
                  return Transform.scale(
                    scale: _scaleAnimation.value,
                    child: Opacity(
                      opacity: _opacityAnimation.value,
                      child: child,
                    ),
                  );
                },
                child: Column(
                  children: [
                    // Outer neon circular glow around lightning icon
                    Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: VoltRideTheme.electricBlue.withOpacity(0.05),
                        border: Border.all(
                          color: VoltRideTheme.electricBlue.withOpacity(0.3),
                          width: 2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: VoltRideTheme.electricBlue.withOpacity(0.2),
                            blurRadius: 30,
                            spreadRadius: 5,
                          ),
                        ],
                      ),
                      child: const Center(
                        child: Icon(
                          Icons.bolt,
                          color: VoltRideTheme.electricBlue,
                          size: 72,
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),
                    // VoltRide neon title
                    Text(
                      'VOLTRIDE',
                      style: GoogleFonts.outfit(
                        fontSize: 44,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 8,
                        color: Colors.white,
                        shadows: [
                          BoxShadow(
                            color: VoltRideTheme.electricBlue.withOpacity(0.8),
                            blurRadius: 15,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    // Subtitle
                    Text(
                      'EV TELEMETRY & SMART DASHBOARD',
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: VoltRideTheme.textSecondary,
                        letterSpacing: 2,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 80),
              // Loading indicator
              const SizedBox(
                width: 40,
                height: 40,
                child: CircularProgressIndicator(
                  strokeWidth: 3,
                  valueColor: AlwaysStoppedAnimation<Color>(VoltRideTheme.neonGreen),
                ),
              ),
              const SizedBox(height: 24),
              // Dynamic status message
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: Text(
                  _statusText,
                  key: ValueKey(_statusText),
                  style: const TextStyle(
                    color: VoltRideTheme.textMuted,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
