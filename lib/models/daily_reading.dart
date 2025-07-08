// lib/models/daily_reading.dart

class DailyReading {
  final DateTime date;
  final double luminosity;
  final double nightHours;
  final double soilMoisture;
  final double dayTemperature;
  final double nightTemperature;
  final double relativeHumidity;

  DailyReading({
    required this.date,
    required this.luminosity,
    required this.nightHours,
    required this.soilMoisture,
    required this.dayTemperature,
    required this.nightTemperature,
    required this.relativeHumidity,
  });

  factory DailyReading.fromJson(Map<String, dynamic> json) {
    return DailyReading(
      date: DateTime.parse(json['date'] as String),
      luminosity: (json['luminosity'] as num).toDouble(),
      nightHours: (json['night_hours'] as num).toDouble(),
      soilMoisture: (json['soil_moisture'] as num).toDouble(),
      dayTemperature: (json['day_temperature'] as num).toDouble(),
      nightTemperature: (json['night_temperature'] as num).toDouble(),
      relativeHumidity: (json['relative_humidity'] as num).toDouble(),
    );
  }
}
