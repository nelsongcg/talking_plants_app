import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../widgets/primary_button.dart';
import '../utils/routes.dart';

class CreateAccountScreen extends StatefulWidget {
  const CreateAccountScreen({super.key});
  @override
  State<CreateAccountScreen> createState() => _CreateAccountScreenState();
}

class _CreateAccountScreenState extends State<CreateAccountScreen> {
  final _emailCtl = TextEditingController();
  final _pwCtl    = TextEditingController();

  bool? _emailExists;      // null → asking e-mail, otherwise asking password
  bool  _busy = false;     // spinner flag

  @override
  void dispose() {
    _emailCtl.dispose();
    _pwCtl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final ts = Theme.of(context).textTheme;
    final showPw = _emailExists != null;

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
              Text('Let’s get started!',
                  style: ts.headlineSmall, textAlign: TextAlign.center),
              const SizedBox(height: 32),

              TextField(
                controller: _emailCtl,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(
                  hintText: 'Email',
                  filled: true,
                  fillColor: cs.surfaceVariant,
                ),
              ),
              if (showPw) ...[
                const SizedBox(height: 16),
                TextField(
                  controller: _pwCtl,
                  obscureText: true,
                  decoration: InputDecoration(
                    hintText: 'Password',
                    filled: true,
                    fillColor: cs.surfaceVariant,
                  ),
                ),
              ],

              const SizedBox(height: 32),
              PrimaryButton(
                label: _primaryLabel,
                loading: _busy,
                onPressed: _busy ? null : _handlePrimary,
              ),
            ],
          ),
        ),
      ),
    );
  }

  String get _primaryLabel {
    if (_emailExists == null) return 'Next';
    return _emailExists! ? 'Log in' : 'Sign up';
  }

  Future<void> _handlePrimary() async {
    setState(() => _busy = true);
    final auth = AuthService();

    try {
      // ── STEP 1: check e-mail uniqueness ───────────────────────────────
      if (_emailExists == null) {
        _emailExists = await auth.emailExists(_emailCtl.text.trim().toLowerCase());
        setState(() => _busy = false);          // show password field
        return;
      }

      // ── STEP 2: sign-up or log-in ─────────────────────────────────────
      final email = _emailCtl.text.trim().toLowerCase();
      final pw    = _pwCtl.text.trim();

      if (_emailExists!) {
        await auth.login(email, pw);
      } else {
        await auth.register(email, pw);
      }

      // ── STEP 3: attempt to claim pending device ───────────────────────
      try {
        await auth.claimPendingDevice();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Device claim failed: $e')),
          );
        }
      }

      // ── STEP 4: decide next screen ───────────────────────────────────
      final status = await auth.onboardingStatus();
      String route;
      Object? arg;
      switch (status['step']) {
        case 'photo':
          route = Routes.plantPhoto;
          arg   = status['device_id'];
          break;
        case 'wifi':
          route = Routes.connectWifi;
          break;
        case 'done':
          route = Routes.home;
          break;
        case 'claim':
        default:
          route = Routes.startSetup;
      }

      if (mounted) {
        Navigator.pushReplacementNamed(context, route, arguments: arg);
      }
    } catch (e, st) {
      debugPrintStack(label: e.toString(), stackTrace: st);
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.toString())));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}
