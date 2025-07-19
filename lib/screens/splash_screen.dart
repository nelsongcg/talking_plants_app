import 'dart:async';
import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../utils/routes.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});
  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _decideNext();
  }

  Future<void> _decideNext() async {
    final auth = AuthService();

    try {
      // ── optional 5-s timeout so we never hang forever ──
      final result = await Future.any([
        _resolveNextRoute(auth),
        Future.delayed(const Duration(seconds: 5), () => Routes.createAccount),
      ]);

      if (!mounted) return;
      if (result is Map) {
        Navigator.pushReplacementNamed(
          context,
          result['route'] as String,
          arguments: result['arg'],
        );
      } else {
        Navigator.pushReplacementNamed(context, result as String);
      }

    } catch (e) {
      // network or parsing error → fall back to Create-Account
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.toString())));
        Navigator.pushReplacementNamed(context, Routes.createAccount);
      }
    }
  }

  Future<dynamic> _resolveNextRoute(AuthService auth) async {
    if (!await auth.hasJwt()) return Routes.createAccount;

    final status = await auth.onboardingStatus();
    switch (status['step']) {
      case 'claim':
        return Routes.startSetup;
      case 'photo':
        return {'route': Routes.plantPhoto, 'arg': status['device_id']};
      case 'wifi':
        return Routes.connectWifi;
      case 'done':
        return Routes.home;
      default:
        return Routes.createAccount;
    }
  }

  @override
  Widget build(BuildContext context) {
    const kGreen = Color(0xFF00D861);

    return Scaffold(
      backgroundColor: kGreen,
      body: Center(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset(
              'assets/images/italktoplantslogo_v1.png',
              height: 256,
            ),
            const SizedBox(width: 12),
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              // children: const [
              //   Text('I TALK TO',
              //       style:
              //           TextStyle(fontSize: 28, fontWeight: FontWeight.w800)),
              //   Text('PLANTS',
              //       style:
              //           TextStyle(fontSize: 28, fontWeight: FontWeight.w800)),
              // ],
            ),
          ],
        ),
      ),
    );
  }
}
