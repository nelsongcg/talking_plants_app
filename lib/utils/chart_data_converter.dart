// lib/utils/chart_data_converter.dart

import 'package:fl_chart/fl_chart.dart';
import '../models/daily_reading.dart';
import 'package:intl/intl.dart';

class ChartDataConverter {
  /// Builds a 30‐day window ending on the last available reading date.
  ///
  /// For each of those 30 dates (index 0 → 29), if a reading exists, emits a FlSpot;
  /// otherwise skips that date (so the line will connect across gaps).
  ///
  /// Returns a Map containing:
  ///  • "series": List<List<FlSpot>> (six metrics, each with spots only on dates that have data)
  ///  • "dateLabels": List<String> of length 30, formatted "MM/dd"
  static Map<String, dynamic> toSeriesWithDates(List<DailyReading> readings) {
    // 1) Determine the "last date" among readings (or today if no readings)
    DateTime latestDate;
    if (readings.isEmpty) {
      final now = DateTime.now();
      latestDate = DateTime(now.year, now.month, now.day);
    } else {
      latestDate = readings
          .map((r) => r.date)
          .reduce((a, b) => a.isAfter(b) ? a : b);
      latestDate = DateTime(latestDate.year, latestDate.month, latestDate.day);
    }

    // 2) Build a list of 30 consecutive dates ending on latestDate:
    //    index 0 => latestDate -29 days, index 29 => latestDate
    final List<DateTime> dateList = List.generate(
      30,
      (i) => latestDate.subtract(Duration(days: 29 - i)),
    );

    // 3) Create a map from "yyyy-MM-dd" => DailyReading for quick lookup
    final dateKeyFormatter = DateFormat('yyyy-MM-dd');
    final Map<String, DailyReading> readingMap = {};
    for (final r in readings) {
      final d = DateTime(r.date.year, r.date.month, r.date.day);
      final key = dateKeyFormatter.format(d);
      readingMap[key] = r;
    }

    // 4) Prepare six lists of FlSpot (only where data exists)
    final List<FlSpot> luminositySpots = [];
    final List<FlSpot> nightHoursSpots = [];
    final List<FlSpot> soilMoistureSpots = [];
    final List<FlSpot> dayTempSpots = [];
    final List<FlSpot> nightTempSpots = [];
    final List<FlSpot> relHumiditySpots = [];

    // 5) Prepare dateLabels in "MM/dd" format for each of the 30 days
    final dateLabelFormatter = DateFormat('MM/dd');
    final List<String> dateLabels = dateList
        .map((d) => dateLabelFormatter.format(d))
        .toList();

    // 6) Iterate over the 30 days; if a reading exists, append a FlSpot at x=i
    for (var i = 0; i < dateList.length; i++) {
      final key = dateKeyFormatter.format(dateList[i]);
      final r = readingMap[key];
      if (r != null) {
        final x = i.toDouble();
        luminositySpots.add(FlSpot(x, r.luminosity));
        nightHoursSpots.add(FlSpot(x, r.nightHours));
        soilMoistureSpots.add(FlSpot(x, r.soilMoisture));
        dayTempSpots.add(FlSpot(x, r.dayTemperature));
        nightTempSpots.add(FlSpot(x, r.nightTemperature));
        relHumiditySpots.add(FlSpot(x, r.relativeHumidity));
      }
      // If no reading for that date, skip adding any FlSpot for that x
    }

    return {
      'series': [
        luminositySpots,
        nightHoursSpots,
        soilMoistureSpots,
        dayTempSpots,
        nightTempSpots,
        relHumiditySpots,
      ],
      'dateLabels': dateLabels,
    };
  }
}
