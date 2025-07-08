// lib/widgets/stats_pane.dart

import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';

const kCream = Color(0xFFFEF1D6);

class StatsPane extends StatefulWidget {
  /// [series]: six lists of FlSpots (one per metric), where each FlSpot.x is
  ///   the index (0..29) of its date in [dateLabels]. Missing days simply
  ///   have no FlSpot at that x value.
  /// [dateLabels]: length=30, the labels for each day in "MM/dd" format.
  const StatsPane({
    Key? key,
    required this.series,
    required this.dateLabels,
  }) : super(key: key);

  final List<List<FlSpot>> series;
  final List<String> dateLabels;

  @override
  State<StatsPane> createState() => _StatsPaneState();
}

class _StatsPaneState extends State<StatsPane> {
  late final PageController _controller;
  int _currentIndex = 0;

  // Titles for each metric (in the same order as widget.series)
  static const List<String> _metricTitles = [
    'Luminosity',
    'Night Hours',
    'Soil Moisture',
    'Day Temperature',
    'Night Temperature',
    'Relative Humidity',
  ];

  // Y‐axis unit labels for each metric
  static const List<String> _metricUnits = [
    'Lumens',
    'Number of hours',
    'Moisture %',
    'Celsius',
    'Celsius',
    'Humidity %',
  ];

  @override
  void initState() {
    super.initState();
    _controller = PageController(viewportFraction: 0.95);
    _controller.addListener(() {
      final page = _controller.page?.round() ?? 0;
      if (page != _currentIndex && page < widget.series.length) {
        setState(() => _currentIndex = page);
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: kCream,
        borderRadius: BorderRadius.circular(16),
      ),
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
      child: Column(
        children: [
          // Expanded PageView: one chart per metric
          Expanded(
            child: PageView.builder(
              controller: _controller,
              itemCount: widget.series.length,
              itemBuilder: (context, i) {
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: _LineChartCard(
                    title: _metricTitles[i],
                    yAxisLabel: _metricUnits[i],
                    spots: widget.series[i],
                    dateLabels: widget.dateLabels,
                    color: cs.primary,
                  ),
                );
              },
            ),
          ),

          const SizedBox(height: 12),

          // Row of dots indicating the current page
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(widget.series.length, (i) {
              final isActive = i == _currentIndex;
              return AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                margin: const EdgeInsets.symmetric(horizontal: 4),
                width: isActive ? 12 : 8,
                height: isActive ? 12 : 8,
                decoration: BoxDecoration(
                  color: isActive 
                      ? cs.primary 
                      : cs.onBackground.withOpacity(0.3),
                  shape: BoxShape.circle,
                ),
              );
            }),
          ),
        ],
      ),
    );
  }
}

class _LineChartCard extends StatelessWidget {
  const _LineChartCard({
    required this.title,
    required this.yAxisLabel,
    required this.spots,
    required this.dateLabels,
    required this.color,
  });

  final String title;
  final String yAxisLabel;
  final List<FlSpot> spots;
  final List<String> dateLabels; // length = 30
  final Color color;

  @override
  Widget build(BuildContext context) {
    // Determine maxY as 1.2× the highest y-value (or 1.0 if empty)
    final maxY = spots.isEmpty
        ? 1.0
        : spots.map((s) => s.y).reduce((a, b) => a > b ? a : b) * 1.2;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 1) Plot title (centered)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Center(
            child: Text(
              title,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ),
        ),

        const SizedBox(height: 8),

        // 2) Chart with a rotated Y‐axis label on the left
        Expanded(
          child: Row(
            children: [
              // Rotated Y‐axis label
              Padding(
                padding: const EdgeInsets.only(right: 4),
                child: RotatedBox(
                  quarterTurns: 3, // 270°
                  child: Text(
                    yAxisLabel,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),

              // The line chart itself
              Expanded(
                child: LineChart(
                  LineChartData(
                    // Always show X‐axis from 0 to 29 (30 days)
                    minX: 0,
                    maxX: 29,

                    // Y from 0 up to computed maxY
                    minY: 0,
                    maxY: maxY,

                    // Enable touch interactions to show a custom tooltip
                    lineTouchData: LineTouchData(
                      touchTooltipData: LineTouchTooltipData(
                        tooltipBgColor: Colors.grey.shade800,
                        getTooltipItems: (List<LineBarSpot> touchedSpots) {
                          return touchedSpots.map((barSpot) {
                            final idx = barSpot.x.toInt();
                            if (idx < 0 || idx >= dateLabels.length) {
                              return null;
                            }
                            final date = dateLabels[idx];
                            final value = barSpot.y.toStringAsFixed(0);
                            return LineTooltipItem(
                              '$date : $value',
                              const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            );
                          }).whereType<LineTooltipItem>().toList();
                        },
                      ),
                    ),

                    titlesData: FlTitlesData(
                      // Remove any top titles
                      topTitles: AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),

                      // Left titles: numeric Y ticks
                      leftTitles: AxisTitles(
                        sideTitles: SideTitles(
                          reservedSize: 32,
                          showTitles: true,
                          interval: maxY / 5, // adjust as needed
                          getTitlesWidget: (value, _) {
                            return Text(
                              value.toStringAsFixed(0),
                              style: const TextStyle(fontSize: 10),
                            );
                          },
                        ),
                      ),

                      // Remove right titles
                      rightTitles: AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),

                      // Bottom titles: show label only every 5 days to avoid overlap
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          reservedSize: 28,
                          showTitles: true,
                          interval: 1, // step by 1, but skip most below
                          getTitlesWidget: (value, _) {
                            final idx = value.toInt();
                            if (idx < 0 ||
                                idx >= dateLabels.length ||
                                idx % 5 != 0) {
                              return const SizedBox.shrink();
                            }
                            return Text(
                              dateLabels[idx],
                              style: const TextStyle(fontSize: 10),
                            );
                          },
                        ),
                      ),
                    ),

                    // Show only horizontal grid lines
                    gridData: const FlGridData(
                      show: true,
                      drawVerticalLine: false,
                    ),

                    // Border around the chart
                    borderData: FlBorderData(
                      show: true,
                      border: Border.all(color: color.withOpacity(.4)),
                    ),

                    // The single line series
                    lineBarsData: [
                      LineChartBarData(
                        spots: spots,
                        isCurved: true,
                        color: color,
                        barWidth: 3,
                        dotData: const FlDotData(show: true),
                        isStrokeCapRound: true,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
