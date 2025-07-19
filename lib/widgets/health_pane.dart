import 'dart:math' show pi;
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:confetti/confetti.dart';
import 'package:vibration/vibration.dart';

const kCream = Color(0xFFFEF1D6);

enum PlantStatus { verySad, sad, neutral, happy, veryHappy }

extension PlantStatusExtension on PlantStatus {
  double get progress {
    switch (this) {
      case PlantStatus.verySad:  return 0;
      case PlantStatus.sad:      return .25;
      case PlantStatus.neutral:  return .5;
      case PlantStatus.happy:    return .75;
      case PlantStatus.veryHappy:return 1;
    }
  }

  String get label {
    switch (this) {
      case PlantStatus.verySad:  return 'Very Sad';
      case PlantStatus.sad:      return 'Sad';
      case PlantStatus.neutral:  return 'Neutral';
      case PlantStatus.happy:    return 'Happy';
      case PlantStatus.veryHappy:return 'Very Happy';
    }
  }
}

class HealthPane extends StatefulWidget {
  /// `null` indicates no data is available yet
  final List<PlantStatus>? statuses;
  final bool statusChecked;
  final bool streakClaimed;
  final VoidCallback? onAllRevealed;
  final VoidCallback? onClaim;

  const HealthPane({
    super.key,
    required this.statuses,
    required this.statusChecked,
    required this.streakClaimed,
    this.onAllRevealed,
    this.onClaim,
  });

  @override
  State<HealthPane> createState() => _HealthPaneState();
}

class _HealthPaneState extends State<HealthPane> with TickerProviderStateMixin {
  static const _icons = [
    'assets/icons/sun_icon.svg',
    'assets/icons/water_icon.svg',
    'assets/icons/moon_icon.svg',
    'assets/icons/day_temperature_icon.svg',
    'assets/icons/night_temperature_icon.svg',
    'assets/icons/humidity_icon.svg',
  ];
  static const _labels = [
    'Luminosity','Soil Moisture','Moonlight',
    'Day Temperature','Night Temperature','Humidity',
  ];

  late final List<bool> _revealed;
  late final ConfettiController _smallConfetti;
  late final ConfettiController _bigConfetti;
  late final AnimationController _pulseController;
  bool _allRevealed = false;

  @override
  void initState() {
    super.initState();
    // handle null statuses safely
    final count = widget.statuses?.length ?? 0;
    _revealed = List.generate(count, (_) => widget.statusChecked);
    _allRevealed = widget.statusChecked;
    _smallConfetti = ConfettiController(duration: const Duration(seconds: 2));
    _bigConfetti   = ConfettiController(duration: const Duration(seconds: 2));
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _smallConfetti.dispose();
    _bigConfetti.dispose();
    super.dispose();
  }

  void _handleTap(int index) async {
    if (widget.statuses == null) return;
    if (_revealed[index] || _allRevealed) return;

    if (await Vibration.hasVibrator() ?? false) {
      Vibration.vibrate(duration: 50);
    }
    setState(() => _revealed[index] = true);
    _smallConfetti.play();

    if (_revealed.every((v) => v)) {
      if (await Vibration.hasCustomVibrationsSupport() ?? false) {
        Vibration.vibrate(pattern: [0, 100, 50, 100]);
      } else {
        Vibration.vibrate(duration: 100);
      }
      setState(() => _allRevealed = true);
      widget.onAllRevealed?.call();
      _bigConfetti.play();
    }
  }

  @override
  Widget build(BuildContext context) {
    // No data placeholder
    if (widget.statuses == null || widget.statuses!.isEmpty) {
      return Center(
        child: Text(
          'No data to display yet',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      );
    }

    final cs = Theme.of(context).colorScheme;
    final statuses = widget.statuses!;

    return Stack(
      alignment: Alignment.topCenter,
      children: [
        Container(
          decoration: BoxDecoration(color: kCream, borderRadius: BorderRadius.circular(16)),
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text("Your plant's health",
                  style: Theme.of(context).textTheme.bodyMedium!
                      .copyWith(fontWeight: FontWeight.w600, fontSize: 18)),
              const SizedBox(height: 12),
              Visibility(
                visible: _allRevealed,
                maintainSize: true,
                maintainAnimation: true,
                maintainState: true,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      textStyle: const TextStyle(fontSize: 16),
                    ),
                    onPressed: widget.streakClaimed ? null : widget.onClaim,
                    child: const Text('Claim your streak!'),
                  ),
                ),
              ),
              ...List.generate(statuses.length, (i) {
                final status = statuses[i];
                final isRevealed = _revealed[i] || _allRevealed;
                final scale = isRevealed
                    ? 1.0
                    : 1.0 + (_pulseController.value * 0.05);
                return Padding(
                  padding: EdgeInsets.only(bottom: i == statuses.length - 1 ? 0 : 20),
                  child: GestureDetector(
                    onTap: () => _handleTap(i),
                    child: Row(
                      children: [
                        SvgPicture.asset(_icons[i],
                            height: 24, width: 24, color: cs.onBackground),
                        const SizedBox(width: 16),
                        Expanded(
                          flex: 3,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(_labels[i],
                                  style: Theme.of(context).textTheme.bodyMedium!
                                      .copyWith(fontSize: 16)),
                              const SizedBox(height: 8),
                              TweenAnimationBuilder<double>(
                                tween: Tween(
                                    begin: 0,
                                    end: isRevealed ? status.progress : 0),
                                duration: isRevealed
                                    ? const Duration(milliseconds: 800)
                                    : Duration.zero,
                                builder: (_, value, __) => LinearProgressIndicator(
                                  value: value,
                                  minHeight: 16,
                                  backgroundColor: cs.surfaceVariant,
                                  color: isRevealed ? cs.primary : cs.surfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          flex: 1,
                          child: AnimatedScale(
                            scale: scale,
                            duration: const Duration(milliseconds: 200),
                            child: Container(
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                color: isRevealed
                                    ? Colors.transparent
                                    : Theme.of(context).colorScheme.primary,
                                shape: BoxShape.circle,
                                boxShadow: isRevealed
                                    ? []
                                    : [BoxShadow(color: Colors.black26, blurRadius: 4)],
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                isRevealed ? status.label : '?',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: isRevealed
                                      ? Theme.of(context).colorScheme.onBackground
                                      : Colors.white,
                                  fontSize: isRevealed ? 14 : 24,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),
            ],
          ),
        ),
        // SMALL leaf-shaped confetti
        ConfettiWidget(
          confettiController: _smallConfetti,
          blastDirectionality: BlastDirectionality.explosive,
          blastDirection: -pi/2,
          emissionFrequency: 0,
          gravity: 0.35,
          minimumSize: const Size(16, 16),
          maximumSize: const Size(24, 24),
          colors: const [Colors.green, Colors.lightGreen, Colors.teal],
          createParticlePath: (size) {
            final path = Path();
            path.moveTo(0, size.height / 2);
            path.quadraticBezierTo(size.width / 2, 0, size.width, size.height / 2);
            path.quadraticBezierTo(size.width / 2, size.height, 0, size.height / 2);
            path.close();
            return path;
          },
        ),
        // BIG leaf-shaped confetti
        ConfettiWidget(
          confettiController: _bigConfetti,
          blastDirectionality: BlastDirectionality.explosive,
          blastDirection: -pi/2,
          emissionFrequency: 0,
          gravity: 0.35,
          minimumSize: const Size(24, 24),
          maximumSize: const Size(32, 32),
          colors: const [Colors.green, Colors.lightGreen, Colors.teal],
          createParticlePath: (size) {
            final path = Path();
            path.moveTo(0, size.height / 2);
            path.quadraticBezierTo(size.width / 2, 0, size.width, size.height / 2);
            path.quadraticBezierTo(size.width / 2, size.height, 0, size.height / 2);
            path.close();
            return path;
          },
        ),
      ],
    );
  }
}
