import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

const kCream = Color(0xFFFEF1D6);

class BottomNav extends StatelessWidget {
  const BottomNav({
    super.key,
    required this.current,
    required this.onTap,
    this.chatKey,
    this.healthKey,
    this.statsKey,
  });
  final int current;
  final ValueChanged<int> onTap;
  final Key? chatKey;
  final Key? healthKey;
  final Key? statsKey;

  static const _icons = [
    'assets/icons/chat_icon.svg',
    'assets/icons/leaf_icon.svg',
    'assets/icons/stats_icon.svg',
  ];
  static const _labels = ['Chat', 'Health', 'Stats'];

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return ColoredBox(
      color: kCream, // colour behind SafeArea
      child: SafeArea(
        top: false,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: List.generate(_icons.length, (i) {
            final active = current == i;
            return InkWell(
              key: switch (i) {
                0 => chatKey,
                1 => healthKey,
                _ => statsKey,
              },
              onTap: () => onTap(i),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SvgPicture.asset(
                      _icons[i],
                      height: 24,
                      colorFilter: ColorFilter.mode(
                        active ? cs.primary : cs.onSurface.withOpacity(.6),
                        BlendMode.srcIn,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _labels[i],
                      style: TextStyle(
                        fontSize: 11,
                        color: active
                            ? cs.primary
                            : cs.onSurface.withOpacity(.6),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
        ),
      ),
    );
  }
}
