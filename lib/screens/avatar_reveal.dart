import 'package:flutter/material.dart';
import '../widgets/primary_button.dart';
import '../utils/routes.dart';

/// Avatar-reveal screen with a “Talk to <name>” CTA that
/// navigates straight to the Chat Home page.
class AvatarRevealScreen extends StatelessWidget {
  const AvatarRevealScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Get the plant’s name from the route arguments
    final String plantName =
        ModalRoute.of(context)?.settings.arguments as String? ?? 'Your plant';

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

              // ── Logo ─────────────────────────────────────
              Image.asset(
                'assets/images/italktoplantsvertical_v2.png',
                height: 80,
              ),

              const SizedBox(height: 40),

              // ── Intro text ──────────────────────────────
              Text(
                'Meet ….',
                style: ts.bodyMedium,
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 24),

              // ── Avatar image ────────────────────────────
              ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: Image.asset(
                  'assets/images/gajumaru_v1.png',
                  height: 260,
                  fit: BoxFit.cover,
                ),
              ),

              const SizedBox(height: 40),

              // ── Plant name ──────────────────────────────
              Text(
                '$plantName!',
                style: ts.headlineSmall!.copyWith(fontSize: 36),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 40),

              // ── “Talk to …” primary button ──────────────
              PrimaryButton(
                label: 'Talk to $plantName',
                onPressed: () =>
                    Navigator.pushNamed(context, Routes.home),
              ),
            ],
          ),
        ),
      ),
    ),
  );
  }
}
