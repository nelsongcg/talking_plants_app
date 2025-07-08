// lib/screens/home_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:dio/dio.dart' show Options;

import '../services/auth_service.dart';
import '../services/api.dart';
import '../services/plant_service.dart';      // <-- NEW
import '../utils/chart_data_converter.dart';   // <-- NEW
import '../widgets/chat_pane.dart';
import '../widgets/health_pane.dart';
import '../widgets/stats_pane.dart';
import '../widgets/bottom_nav.dart';
import '../widgets/side_menu.dart';

const kCream = Color(0xFFFEF1D6);

/// Helper to map fetched string labels to our PlantStatus enum.
PlantStatus statusFromString(String s) {
  switch (s.toLowerCase()) {
    case 'very sad':   return PlantStatus.verySad;
    case 'sad':        return PlantStatus.sad;
    case 'neutral':    return PlantStatus.neutral;
    case 'happy':      return PlantStatus.happy;
    case 'very happy': return PlantStatus.veryHappy;
    default:           return PlantStatus.neutral;
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  int _tab = 0;

  /// NEW: holds the async streak fetch
  Future<int>? _streakFuture;

  // ─── Chat state ───────────────────────────────────────────
  List<Msg> _messages = [];

  final _controller = TextEditingController();
  String? _deviceId;
  bool _sending = false;

  // ─── Chart state ──────────────────────────────────────────────────────
  /// Holds: { "series": List<List<FlSpot>>, "dateLabels": List<String> }
  late Future<Map<String, dynamic>> _chartDataFuture;

  @override
  void initState() {
    super.initState();
    _loadDeviceId();
    _chartDataFuture = _loadChartData();
  }

  Future<void> _loadDeviceId() async {
    final auth = AuthService();
    _deviceId = await auth.currentDeviceId();
    if (_deviceId != null) {
    // Fire the request (and keep the Future so UI can listen)
    _streakFuture = PlantService.fetchCurrentStreak(_deviceId!);
    _loadChatHistory();
    }
    setState(() {});
  }
  /// Pulls chat history from server and updates [_messages].
  Future<void> _loadChatHistory() async {
    if (_deviceId == null) return;
    try {
      final history = await PlantService.fetchChatHistory(
        deviceId: _deviceId!,
      );

      // server sends oldest-first; we want newest @ index 0
      final msgs = history
          .map((m) => Msg(m.text, m.isUser))
          .toList()
          .toList();

      setState(() => _messages = msgs);
    } catch (e) {
      debugPrint('⚠️ Could not load chat history: $e');
      // _messages stays empty if there's an error or no history
    }
  }

  /// Fetches the last‐30‐days readings via PlantService,
  /// then converts into { series, dateLabels } with ChartDataConverter.
  Future<Map<String, dynamic>> _loadChartData() async {
    final readings = await PlantService.fetchLast30DaysReadings();
    return ChartDataConverter.toSeriesWithDates(readings);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  // ─── send message & fetch reply (unchanged) ───────────────────────────
  Future<void> _sendMessage(String txt) async {
    final message = txt.trim();
    if (message.isEmpty || _sending) return;
    if (_deviceId == null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('No device linked')));
      return;
    }

    setState(() {
      _sending = true;
      _messages.insert(0, Msg(message, true));
      _controller.clear();
    });

    try {
      final auth = AuthService();
      final jwt = await auth.getJwt();
      final r = await dio.post(
        '/api/chat',
        data: {'device_id': _deviceId, 'text': message},
        options: Options(headers: {'Authorization': 'Bearer $jwt'}),
      );

      final reply = r.data['reply'] as String? ?? '';
      if (mounted && reply.isNotEmpty) {
        setState(() => _messages.insert(0, Msg(reply, false)));
      }
    } catch (e) {
      if (mounted) {
        setState(() => _messages.add(Msg('⚠️ $e', false)));
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _refreshStreak() async {
    if (_deviceId == null) return;
    _streakFuture = PlantService.fetchCurrentStreak(_deviceId!);
    setState(() {});           // re-build header → new value shows
  }

/// Fetches statuses, checked flag, and streakClaimed
Future<Map<String, dynamic>> _loadHealthData() async {
  final data = await PlantService.fetchLatestMood();
  

  // ── 1) Is there any payload at all?
  final rawMood = data['current_mood'];
  if (rawMood == null || (rawMood is Map && rawMood.isEmpty)) {
    // Tell the widget there’s nothing to render yet
    return {'hasData': false};
  }

  final moodMap = Map<String, dynamic>.from(data['current_mood'] as Map);


  final checked = (data['status_checked'] as int? ?? 0) == 1;
  final streakClaimed = (data['streak_claimed'] as int? ?? 0) == 1;

  const keys = [
    'luminosity',
    'soil_moisture',
    'moonlight',
    'day_temperature',
    'night_temperature',
    'relative_humidity',
  ];
  final statuses = keys.map((k) {
    final arr = moodMap[k] as List<dynamic>?;
    final label = arr?.first as String? ?? 'neutral';
    return statusFromString(label);
  }).toList();

  return {
    'hasData'      : true,
    'statuses': statuses,
    'checked': checked,
    'streakClaimed': streakClaimed,
  };
}



  
  // ─── UI build ─────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final ts = Theme.of(context).textTheme;
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: Theme.of(context).colorScheme.background,
      endDrawer: const SideMenu(),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            _Header(onBurgerTap: () => _scaffoldKey.currentState?.openEndDrawer()),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                children: [
                  FutureBuilder<int>(
                    future: _streakFuture,
                    builder: (ctx, snap) {
                      if (snap.connectionState == ConnectionState.waiting) {
                        // small spinner while loading
                        return const SizedBox(
                          width: 20, height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        );
                      }
                      if (snap.hasError || !snap.hasData) {
                        return Text('—', style: ts.headlineSmall); // show dash on error
                      }
                      return Text('${snap.data}', style: ts.headlineSmall);
                    },
                  ),

                  const SizedBox(width: 4),
                  const Icon(Icons.trending_up),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Expanded(child: _buildMiddle()),
            const SizedBox(height: 8),
          ],
        ),
      ),
      bottomNavigationBar:
          BottomNav(current: _tab, onTap: (i) {
        setState(() {
          _tab = i;
          // Whenever we switch to Stats (index 2), refresh the data:
          if (_tab == 2) {
            _chartDataFuture = _loadChartData();
          }
        });
      }),
    );
  }


  Widget _buildMiddle() => switch (_tab) {
        0 => ChatPane(
              messages: _messages,
              controller: _controller,
              onSend: _sendMessage,
              isProcessing: _sending,
            ),
        1 => FutureBuilder<Map<String, dynamic>>(
          future: _loadHealthData(),
          builder: (ctx, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (snap.hasError) {
              return Center(child: Text('Error: ${snap.error}'));
            }
            final data = snap.data!;
            final hasData = data['hasData'] as bool? ?? false;

            final statuses = hasData
                ? data['statuses'] as List<PlantStatus>
                : null;
            final wasChecked = hasData && data.containsKey('checked')
                ? data['checked'] as bool
                : false;
            final wasStreakClaimed = hasData && data.containsKey('streakClaimed')
                ? data['streakClaimed'] as bool
                : false;

            return HealthPane(
              statuses: statuses,
              statusChecked: wasChecked,
              streakClaimed: wasStreakClaimed,
              onAllRevealed: () async {
                await PlantService.markMoodChecked();
              },
              onClaim: () async {
                await PlantService.claimStreak();
                await _refreshStreak();
              },
            );

          },
        ),



        _ => _buildStatsPane(),
      };

  /// Displays a FutureBuilder: spinner → error → StatsPane(series, dateLabels)
  Widget _buildStatsPane() {
    return FutureBuilder<Map<String, dynamic>>(
      future: _chartDataFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Error loading data:\n${snapshot.error}'));
        }

        final data = snapshot.data!;
        final series = data['series'] as List<List<FlSpot>>;
        final dateLabels = data['dateLabels'] as List<String>;

        if (series.isEmpty || series.first.isEmpty) {
          return const Center(child: Text('No data available.'));
        }

        return Padding(
          padding: const EdgeInsets.all(16),
          child: StatsPane(series: series, dateLabels: dateLabels),
        );
      },
    );
  }
}

// ─── HEADER widget (unchanged) ─────────────────────────────────────────
class _Header extends StatelessWidget {
  const _Header({required this.onBurgerTap});
  final VoidCallback? onBurgerTap;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Align(
          alignment: Alignment.topCenter,
          child: ClipRRect(
            borderRadius: const BorderRadius.only(
              bottomLeft: Radius.circular(120),
              bottomRight: Radius.circular(120),
            ),
            child: Container(
              color: Colors.white.withOpacity(.9),
              width: 160,
              height: 160,
              alignment: Alignment.bottomCenter,
              child: Image.asset(
                'assets/images/gajumaru_v1.png',
                height: 115,
                fit: BoxFit.contain,
              ),
            ),
          ),
        ),
        Positioned(
          left: 16,
          top: MediaQuery.of(context).padding.top + 8,
          child: Image.asset(
            'assets/images/italktoplantsvertical_v2.png',
            height: 56,
          ),
        ),
        Positioned(
          right: 16,
          top: MediaQuery.of(context).padding.top + 16,
          child: IconButton(
            icon: SvgPicture.asset('assets/icons/burger_menu_icon.svg', height: 28),
            onPressed: onBurgerTap,
          ),
        ),
      ],
    );
  }
}
