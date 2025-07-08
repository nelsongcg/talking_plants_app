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
      await Future.any([
        _resolveNextRoute(auth),
        Future.delayed(const Duration(seconds: 5), () => Routes.createAccount),
      ]).then((route) {
        if (!mounted) return;
        Navigator.pushReplacementNamed(context, route as String);
      });
    } catch (e) {
      // network or parsing error → fall back to Create-Account
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.toString())));
        Navigator.pushReplacementNamed(context, Routes.createAccount);
      }
    }
  }

  Future<String> _resolveNextRoute(AuthService auth) async {
    if (await auth.isDeviceSynced()) return Routes.home;
    final hasJwt = await auth.hasJwt();
    return hasJwt ? Routes.startSetup : Routes.createAccount;
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
