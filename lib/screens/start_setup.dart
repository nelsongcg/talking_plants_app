import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import '../widgets/primary_button.dart';
import '../utils/routes.dart';

class StartSetupScreen extends StatefulWidget {
  const StartSetupScreen({super.key});

  @override
  State<StartSetupScreen> createState() => _StartSetupScreenState();
}

class _StartSetupScreenState extends State<StartSetupScreen> {
  String? _deviceId;          // null  = no device claimed yet
  bool    _busy = true;       // show spinner until we know

  @override
  void initState() {
    super.initState();
    _loadDevice();
  }

  Future<void> _loadDevice() async {
    final auth = AuthService();
    _deviceId  = await auth.currentDeviceId();   // <- key set after claim
    if (mounted) {
      setState(() => _busy = false);
      if (_deviceId != null) {
        // we already have a claimed device → skip QR, go to photo
        Navigator.pushReplacementNamed(
          context,
          Routes.plantPhoto,
          arguments: _deviceId,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final ts = Theme.of(context).textTheme;

    if (_busy) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: cs.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 32),
              Image.asset('assets/images/italktoplantsvertical_v2.png',
                  height: 96),
              const SizedBox(height: 40),
              Text(
                'We can see that you don’t have any device linked '
                'to this account yet.',
                style: ts.headlineSmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              PrimaryButton(
                label: 'Start setup',
                onPressed: () {
                  // open your QR-scanner screen so the user can scan the device
                  Navigator.pushNamed(context, Routes.scanQr);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
