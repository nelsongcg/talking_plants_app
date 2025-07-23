import 'dart:async';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import '../services/auth_service.dart';        // <-- your AuthService class
import 'package:flutter/services.dart';
import 'package:flutter_esp_ble_prov/flutter_esp_ble_prov.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

import 'package:flutter_blue_plus/flutter_blue_plus.dart'
show FlutterBluePlus, BluetoothAdapterState;

import '../widgets/primary_button.dart';
import '../utils/routes.dart';
import '../services/api.dart';

class ConnectWifiScreen extends StatefulWidget {
  const ConnectWifiScreen({super.key});
  @override
  State<ConnectWifiScreen> createState() => _ConnectWifiScreenState();
}

class _ConnectWifiScreenState extends State<ConnectWifiScreen> {
  // ── high-level provisioning helper ───────────────────────────────────
  final _prov = FlutterEspBleProv();

  // BLE devices called “ITTP_…”
  final List<String> _devices = [];
  // Wi-Fi SSIDs discovered by the module
  final List<String> _networks = [];

  String _selectedDevice = '';
  String _selectedSsid   = '';

  // proof-of-possession – hard-coded for now
  final _popCtl  = TextEditingController(text: 'ABC123');
  final _ssidCtl = TextEditingController();
  final _pwdCtl  = TextEditingController();

  StreamSubscription<List<ScanResult>>? _scanSub;
  bool _scanning = false;
  bool _busy     = false;

  bool get _showWifiStep => _selectedDevice.isNotEmpty;

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _scanSub?.cancel();
    _ssidCtl.dispose();
    _pwdCtl.dispose();
    _popCtl.dispose();
    super.dispose();
  }

  // ───────────────────────────── BLE scan ─────────────────────────────
  Future<void> _waitForBluetooth() async {
  // current state
  var state = await FlutterBluePlus.adapterState.first;
  if (state == BluetoothAdapterState.on) return;        // already ready

  // otherwise wait until it changes to “on”
  await FlutterBluePlus.adapterState
      .firstWhere((s) => s == BluetoothAdapterState.on);
}


  Future<void> _startBleScan() async {
    setState(() {
      _devices.clear();
      _selectedDevice = '';
      _scanning = true;
    });

    try {
      await _waitForBluetooth();
      await FlutterBluePlus.startScan(
        withNames: const ['ITTP'],           // advertise name prefix
        timeout: const Duration(seconds: 5),
      );

      _scanSub?.cancel();                       // restart listener each scan
      _scanSub = FlutterBluePlus.scanResults.listen((results) {
        for (final r in results) {
          final name = r.device.name;
          if (name.startsWith('ITTP') && !_devices.contains(name)) {
            setState(() => _devices.add(name));
          }
        }
      });
    } finally {
      setState(() => _scanning = false);
    }
  }

  // ────────────────────────── Wi-Fi scan via BLE ──────────────────────
  Future<void> _scanWifi() async {
    if (_selectedDevice.isEmpty) return;
    setState(() { _busy = true; _networks.clear(); });

    try {
      final list = await _prov.scanWifiNetworks(
          _selectedDevice, _popCtl.text.trim());

      setState(() => _networks.addAll(list));
    } on PlatformException catch (e) {
      // Code “2” → no networks (not an error)
      if (e.code != '2') _snack('Wi-Fi scan failed: ${e.message}');
    } finally {
      setState(() => _busy = false);
    }
  }


  // ───────────────────────────── Provisioning ─────────────────────────
Future<void> _provision() async {
  final ssid = _selectedSsid.isNotEmpty
      ? _selectedSsid
      : _ssidCtl.text.trim();

  if (ssid.isEmpty) { _snack('Enter SSID'); return; }

  setState(() => _busy = true);
  try {
    // ①  Provision the module over BLE (returns true on success)
    final connected = await _prov
        .provisionWifi(
          _selectedDevice,
          _popCtl.text.trim(),
          ssid,
          _pwdCtl.text.trim(),
        )
        .timeout(const Duration(seconds: 30));
    if (connected != true) throw TimeoutException('wifi');

    // ②  Read device_id & claim_token that the QR screen saved
    final secure  = const FlutterSecureStorage();
    final pending = await secure.read(key: 'deviceForWiFi');
    if (pending != null && pending.contains(',')) {
      final parts  = pending.split(',');
      final id     = parts[0];
      final token  = parts[1];

      // ③  Tell the backend this device is now online
      final auth   = AuthService();
      final jwt    = await auth.getJwt();

      await dio.post(
        '/device/online',
        data: { 'device_id': id, 'claim_token': token },
        options: Options(headers: { 'Authorization': 'Bearer $jwt' }),
      );
    }

    // ④  Move on
    if (mounted) {
      Navigator.pushReplacementNamed(context, Routes.avatarReveal);
    }
      } on TimeoutException {
    _snack('Connection failed – check Wi-Fi name and password.');
    await _resetProvision();
  } catch (e) {
    _snack('Provisioning failed: $e');
    await _resetProvision();
  } finally {
    if (mounted) setState(() => _busy = false);
  }
}

  // ────────────────── helper to clear state & restart BLE scan ────────────
  Future<void> _resetProvision() async {
    setState(() {
      _selectedDevice = '';
      _networks.clear();
      _busy = false;
    });
    // kick off a new BLE scan so the device re-appears
    await _startBleScan();
  }


  // ───────────────────────────── UI / build ───────────────────────────
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final ts = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: cs.background,
      appBar: AppBar(title: const Text('Connect ITTP')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 32),
              Image.asset('assets/images/italktoplantsvertical_v2.png',
                  height: 96),

              // ── Step 1 ────────────────────────────────────────────────
              const SizedBox(height: 40),
              Text('Step 1 · pick device',
                  style: ts.titleMedium, textAlign: TextAlign.center),
              const SizedBox(height: 12),

              if (_scanning) ...[
                const Center(child: CircularProgressIndicator()),
              ] else if (_devices.isEmpty) ...[
                PrimaryButton(label: 'Scan', onPressed: _startBleScan),
              ] else ...[
                DropdownButton<String>(
                  isExpanded: true,
                  hint: const Text('Select ITTP* module'),
                  value: _selectedDevice.isEmpty ? null : _selectedDevice,
                  items: _devices.map((d) =>
                    DropdownMenuItem(value: d, child: Text(d))).toList(),
                  onChanged: (d) {
                    setState(() {
                      _selectedDevice = d!;
                      _selectedSsid   = '';
                      _networks.clear();
                    });
                    _scanWifi();            // auto-scan Wi-Fi for this device
                  },
                ),
              ],

              // ── Step 2 ────────────────────────────────────────────────
              if (_showWifiStep) ...[
                const SizedBox(height: 40),
                Text('Step 2 · Wi-Fi credentials',
                    style: ts.titleMedium, textAlign: TextAlign.center),
                const SizedBox(height: 12),

                // list of SSIDs (if any)
                if (_networks.isNotEmpty) ...[
                  DropdownButton<String>(
                    isExpanded: true,
                    hint: const Text('Select network'),
                    value: _selectedSsid.isEmpty ? null : _selectedSsid,
                    items: _networks.map((s) =>
                      DropdownMenuItem(value: s, child: Text(s))).toList(),
                    onChanged: (v) => setState(() => _selectedSsid = v!),
                  ),
                  const Padding(
                    padding: EdgeInsets.only(top: 8.0),
                    child: Text('or type manually:',
                        textAlign: TextAlign.center),
                  ),
                ],

                TextField(
                  controller: _ssidCtl,
                  decoration: InputDecoration(
                    hintText: 'Wi-Fi SSID',
                    filled: true,
                    fillColor: cs.surfaceVariant,
                  ),
                ),
                const SizedBox(height: 12),

                TextField(
                  controller: _pwdCtl,
                  obscureText: true,
                  decoration: InputDecoration(
                    hintText: 'Password',
                    filled: true,
                    fillColor: cs.surfaceVariant,
                  ),
                ),
                const SizedBox(height: 12),

                TextField(
                  controller: _popCtl,
                  decoration: InputDecoration(
                    hintText: 'POP (Proof-of-Possession)',
                    filled: true,
                    fillColor: cs.surfaceVariant,
                  ),
                ),
                const SizedBox(height: 32),

                PrimaryButton(
                  label: _busy ? 'Working…' : 'Connect',
                  loading: _busy,
                  onPressed: _busy ? null : _provision,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  // helper
  void _snack(String msg) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
}
