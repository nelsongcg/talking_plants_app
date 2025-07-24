import 'dart:async';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../services/auth_service.dart';
import '../utils/routes.dart';

class ScanQrScreen extends StatefulWidget {
  const ScanQrScreen({super.key});

  @override
  State<ScanQrScreen> createState() => _ScanQrScreenState();
}

class _ScanQrScreenState extends State<ScanQrScreen> {
  final _controller = MobileScannerController();
  final _secure     = const FlutterSecureStorage();

  bool _processing = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /* ───────────────────────────────────────────────────── */
/* ─── called every time the scanner sees barcodes ─── */
Future<void> _onDetect(BarcodeCapture cap) async {
  if (_processing) return;
  _processing = true;          // lock immediately
  _controller.stop();          // freeze camera so no more frames arrive

  final raw = cap.barcodes.first.rawValue;
  if (raw == null) {
    _controller.start();
    _processing = false;
    return;
  }

  Uri uri;
  try {
    uri = Uri.parse(raw);
  } catch (_) {
    _show('Unsupported QR code');
    _controller.start();
    _processing = false;
    return;
  }

  if (uri.scheme != 'plantpet' || uri.host != 'claim') {
    _show('Unsupported QR code');
    _controller.start();
    _processing = false;
    return;
  }

  final d = uri.queryParameters['d'];
  final t = uri.queryParameters['t'];
  if (d == null || t == null) {
    _show('Incomplete QR code');
    _controller.start();
    _processing = false;
    return;
  }

  try {
    await _secure.write(key: 'pendingDevice', value: '$d,$t');

    final auth     = AuthService();
    final jwt      = await auth.getJwt();
    final loggedIn = jwt != null && jwt.isNotEmpty;

    if (loggedIn) {
      await _secure.write(key: 'deviceForWiFi', value: '$d,$t');
      await auth.claimPendingDevice().timeout(const Duration(seconds: 10));
    }

    if (!mounted) return;

    final nextRoute = loggedIn ? Routes.plantPhoto : Routes.createAccount;
    final argId     = loggedIn ? await auth.currentDeviceId() : null;

    Navigator.pushReplacementNamed(context, nextRoute, arguments: argId);
  } on TimeoutException {
    _show('Claim timed out. Please try again.');
    _controller.start();
  } catch (e) {
    _show('Claim error: $e');
    _controller.start();
  } finally {
    _processing = false;
  }
}

  void _show(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  /* ─── UI ───────────────────────────────────────────── */
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final ts = Theme.of(context).textTheme;

    return PopScope(
      canPop: false,
      child: Scaffold(
      backgroundColor: cs.background,
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 24),
            Image.asset('assets/images/italktoplantsvertical_v2.png', height: 80),
            const SizedBox(height: 32),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text('Scan the QR code on your ITTP device', style: ts.bodyMedium, textAlign: TextAlign.center),
            ),
            const SizedBox(height: 24),
            Expanded(
              child: Stack(
                alignment: Alignment.center,
                children: [
                  MobileScanner(controller: _controller, onDetect: _onDetect),
                  Container(
                    width: 240,
                    height: 240,
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.white, width: 2),
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            if (_processing)
              const Padding(
                padding: EdgeInsets.only(bottom: 16),
                child: CircularProgressIndicator(),
              ),
          ],
        ),
      ),
    ),
  );
  }
}
