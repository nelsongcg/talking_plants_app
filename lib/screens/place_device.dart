import 'package:flutter/material.dart';
import '../utils/routes.dart';

/// Screen · Place ITTP near your phone
///
/// • Vertical logo  
/// • Multi-line instruction text  
/// • Large rounded-rect placeholder image (shows where the “connect” button is)  
/// • No buttons here—user will press the physical button on the device
class PlaceDeviceScreen extends StatelessWidget {
  const PlaceDeviceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final ts = Theme.of(context).textTheme;

    return PopScope(
      canPop: false,
      child: Scaffold(
      backgroundColor: cs.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 24),

              // ── Logo ──────────────────────────────────────
              Image.asset(
                'assets/images/italktoplantsvertical_v2.png',
                height: 80,
              ),

              const SizedBox(height: 32),

              // ── Instruction (multi-line) ─────────────────
              Text(
                'Place the ITTP near your phone and\n'
                'press “connect” button as shown in the\n'
                'picture below',
                style: ts.bodyMedium,
              ),

              const SizedBox(height: 24),

              // ── Image / video placeholder  ───────────────
              Container(
                height: 320,
                decoration: BoxDecoration(
                  color: cs.surfaceVariant,
                  borderRadius: BorderRadius.circular(20),
                ),
              ),

              // Optionally add “Continue” button if you need
              // to confirm this step:
              //
              // const SizedBox(height: 40),
              // PrimaryButton(
              //   label: 'Continue',
              //   onPressed: () {
              //     Navigator.pushNamed(context, Routes.chatHome);
              //   },
              // ),
            ],
          ),
        ),
      ),
    ),
  );
  }
}
