import 'dart:async';
import 'package:flutter/material.dart';
import 'package:uni_links/uni_links.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'theme/theme.dart';
import 'utils/routes.dart';

/* ─── screens ───────────────────────────────────────────── */
import 'screens/splash_screen.dart';
import 'screens/create_account.dart';
import 'screens/start_setup.dart';
import 'screens/plant_photo.dart';
import 'screens/scan_qr.dart';
import 'screens/connect_wifi.dart';
import 'screens/place_device.dart';
import 'screens/avatar_reveal.dart';
import 'screens/home_screen.dart';

/* ─── global link listener ─────────────────────────────── */
final _secure = const FlutterSecureStorage();
StreamSubscription? _linkSub;



Future<void> _handleIncoming(Uri? uri) async {
  if (uri == null) return;
  if (uri.scheme == 'plantpet' && uri.host == 'claim') {
    final d = uri.queryParameters['d'];
    final t = uri.queryParameters['t'];
    if (d != null && t != null) {
      await _secure.write(key: 'pendingDevice', value: '$d,$t');
      debugPrint('🟢 stored pendingDevice $d'); 
    }
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // listen for links even when app is in foreground
  _linkSub = uriLinkStream.listen(_handleIncoming, onError: (_) {});
  // handle a link that launched the app
  try {
    final initial = await getInitialUri();
    await _handleIncoming(initial);
  } catch (_) {}

  runApp(const PlantPetApp());
}

/* ─── root widget ───────────────────────────────────────── */
class PlantPetApp extends StatefulWidget {
  const PlantPetApp({super.key});
  @override
  State<PlantPetApp> createState() => _PlantPetAppState();
}

class _PlantPetAppState extends State<PlantPetApp> {
  @override
  void dispose() {
    _linkSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'I Talk to Plants',
      debugShowCheckedModeBanner: false,
      theme: appTheme,
      initialRoute: Routes.splash,
      routes: {
        Routes.splash        : (_) => const SplashScreen(),
        Routes.createAccount : (_) => const CreateAccountScreen(),
        Routes.startSetup    : (_) => const StartSetupScreen(),
        Routes.plantPhoto    : (ctx) {
          final id = ModalRoute.of(ctx)!.settings.arguments as String;
          return PlantPhotoScreen(deviceId: id);
        },
        Routes.scanQr        : (_) => const ScanQrScreen(),
        Routes.connectWifi   : (_) => const ConnectWifiScreen(),
        Routes.placeDevice   : (_) => const PlaceDeviceScreen(),
        Routes.avatarReveal  : (_) => const AvatarRevealScreen(),
        Routes.home          : (_) => const HomeScreen(),
      },
    );
  }
}
