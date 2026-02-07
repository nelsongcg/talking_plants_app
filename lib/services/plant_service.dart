import 'package:dio/dio.dart';
import 'package:talking_plants/services/api.dart';          // your Dio instance
import 'package:talking_plants/services/auth_service.dart'; // your AuthService
import '../models/daily_reading.dart';

class ChatMessage {
  final int? id;
  final String text;
  final bool isUser;
  final DateTime createdAt;
  ChatMessage({
    required this.id,
    required this.text,
    required this.isUser,
    required this.createdAt,
  });
}

class PlantService {
  /// Fetch the last‐30‐days of readings for the currently‐saved device.
  /// Returns a List<DailyReading>.
  static Future<List<DailyReading>> fetchLast30DaysReadings() async {
    final jwt = await AuthService().getJwt();
    if (jwt == null) {
      throw Exception('No JWT found; user is not authenticated.');
    }

    final deviceId = await AuthService().currentDeviceId();
    if (deviceId == null) {
      throw Exception('No device_id found; user has no linked device.');
    }

    final response = await dio.get(
      '/api/personality-evolution',
      queryParameters: {'device_id': deviceId},
      options: Options(
        headers: {'Authorization': 'Bearer $jwt'},
      ),
    );

    if (response.statusCode != 200) {
      throw Exception(
        'Failed to load readings (status ${response.statusCode}): ${response.data}',
      );
    }

    final data = response.data;
    if (data is! List) {
      throw Exception('Unexpected payload: not a List');
    }

    final readings = <DailyReading>[];
    const requiredKeys = [
      'date',
      'luminosity',
      'night_hours',
      'soil_moisture',
      'day_temperature',
      'night_temperature',
      'relative_humidity',
    ];

    for (final raw in data.cast<Map<String, dynamic>>()) {
      final hasAllKeys = requiredKeys.every(raw.containsKey);
      if (!hasAllKeys) continue;

      final numsOk = [
        raw['luminosity'],
        raw['night_hours'],
        raw['soil_moisture'],
        raw['day_temperature'],
        raw['night_temperature'],
        raw['relative_humidity'],
      ].every((v) => v is num);
      if (!numsOk) continue;

      try {
        readings.add(DailyReading.fromJson(raw));
      } catch (_) {
        // Skip malformed rows instead of failing the whole chart.
      }
    }

    return readings;
  }

  /// Fetch the latest plant health JSON, status_checked, and streak_claimed.
  /// Returns a Map with keys:
  ///  - 'current_mood': Map<String, dynamic>
  ///  - 'status_checked': int (0 or 1)
  ///  - 'streak_claimed': int (0 or 1)
  static Future<Map<String, dynamic>> fetchLatestMood() async {
    final jwt = await AuthService().getJwt();
    if (jwt == null) {
      throw Exception('No JWT found; user is not authenticated.');
    }

    final deviceId = await AuthService().currentDeviceId();
    if (deviceId == null) {
      throw Exception('No device_id found; user has no linked device.');
    }

    final response = await dio.get(
      '/api/health/latest',
      queryParameters: {'device_id': deviceId},
      options: Options(
        headers: {'Authorization': 'Bearer $jwt'},
      ),
    );

    if (response.statusCode == 404) {
      // no data yet — return defaults
      return {
        'current_mood': {},
        'status_checked': 0,
        'streak_claimed': 0,
      };
    }
    if (response.statusCode != 200) {
      throw Exception(
        'Failed to load latest mood (status ${response.statusCode}): ${response.data}',
      );
    }

    final data = response.data;
    if (data is! Map<String, dynamic> || !data.containsKey('current_mood')) {
      throw Exception('Unexpected payload: $data');
    }

    return {
      'current_mood': Map<String, dynamic>.from(data['current_mood']),
      'status_checked': data['status_checked'] as int? ?? 0,
      'streak_claimed': data['streak_claimed'] as int? ?? 0,
    };
  }

  /// Call backend to set today's personality_evolution.status_checked = 1
  static Future<void> markMoodChecked() async {
    final jwt = await AuthService().getJwt();
    if (jwt == null) {
      throw Exception('No JWT found; user is not authenticated.');
    }

    final deviceId = await AuthService().currentDeviceId();
    if (deviceId == null) {
      throw Exception('No device_id found; user has no linked device.');
    }

    final response = await dio.post(
      '/api/health/mark-checked',
      data: {'device_id': deviceId},
      options: Options(
        headers: {'Authorization': 'Bearer $jwt'},
      ),
    );

    if (response.statusCode != 200) {
      throw Exception(
        'Failed to mark mood checked (status ${response.statusCode}): ${response.data}',
      );
    }
  }

  /// Call backend to set today's personality_evolution.streak_claimed = 1
  static Future<void> claimStreak() async {
    final jwt = await AuthService().getJwt();
    if (jwt == null) {
      throw Exception('No JWT found; user is not authenticated.');
    }

    final deviceId = await AuthService().currentDeviceId();
    if (deviceId == null) {
      throw Exception('No device_id found; user has no linked device.');
    }

    final response = await dio.post(
      '/api/health/claim-streak',
      data: {'device_id': deviceId},
      options: Options(
        headers: {'Authorization': 'Bearer $jwt'},
      ),
    );

    if (response.statusCode != 200) {
      throw Exception(
        'Failed to claim streak (status ${response.statusCode}): ${response.data}',
      );
    }
  }

  /// Returns the current streak count for the given device.
  static Future<int> fetchCurrentStreak(String deviceId) async {
    final jwt = await AuthService().getJwt();
    final resp = await dio.get(
      '/api/health/current-streak',
      queryParameters: {'device_id': deviceId},
      options: Options(headers: {'Authorization': 'Bearer $jwt'}),
    );
    return resp.data['current_streak'] as int;
  }

  static String _resolveApiUrl(String urlOrPath) {
    if (urlOrPath.startsWith('http://') || urlOrPath.startsWith('https://')) {
      return urlOrPath;
    }
    final base = dio.options.baseUrl;
    if (base.isEmpty) return urlOrPath;
    return Uri.parse(base).resolve(urlOrPath).toString();
  }

  /// Fetch the plant photo URL for the given device (if available).
  static Future<String?> fetchPlantPhotoUrl(String deviceId) async {
    final jwt = await AuthService().getJwt();
    if (jwt == null) {
      throw Exception('No JWT found; user is not authenticated.');
    }

    final resp = await dio.get(
      '/api/devices',
      options: Options(headers: {'Authorization': 'Bearer $jwt'}),
    );

    if (resp.statusCode != 200) {
      throw Exception(
        'Failed to load devices (status ${resp.statusCode}): ${resp.data}',
      );
    }

    final data = resp.data;
    if (data is! List) {
      throw Exception('Unexpected payload: not a List');
    }

    for (final raw in data) {
      if (raw is Map<String, dynamic> && raw['device_id'] == deviceId) {
        final url = raw['photo_url'] as String?;
        if (url == null || url.isEmpty) return null;
        return _resolveApiUrl(url);
      }
    }

    return null;
  }

  /// Fetch the full chat history for this plant (user inferred by JWT).
  static Future<List<ChatMessage>> fetchChatHistory({
    required String deviceId,
  }) async {
    // grab JWT
    final jwt = await AuthService().getJwt();

    final resp = await dio.get(
      '/api/chat/history',
      queryParameters: {'device_id': deviceId},
      options: Options(headers: {'Authorization': 'Bearer $jwt'}),
    );

    if (resp.statusCode != 200) {
      throw Exception('Failed to load chat history (${resp.statusCode})');
    }

    // Expect: [ { text: "...", is_user: 1, created_at: "..." }, … ]
    final data = resp.data as List<dynamic>;
    return data.map((e) {
      final rawId = e['id'];
      int? id;
      if (rawId is int) {
        id = rawId;
      } else if (rawId is String) {
        id = int.tryParse(rawId);
      }

      final createdAtRaw = e['created_at'];
      DateTime createdAt;
      if (createdAtRaw is String) {
        createdAt = DateTime.tryParse(createdAtRaw) ??
            DateTime.fromMillisecondsSinceEpoch(0);
      } else if (createdAtRaw is int) {
        createdAt = DateTime.fromMillisecondsSinceEpoch(createdAtRaw);
      } else if (createdAtRaw is double) {
        createdAt = DateTime.fromMillisecondsSinceEpoch(
            createdAtRaw.round());
      } else if (createdAtRaw is DateTime) {
        createdAt = createdAtRaw;
      } else {
        createdAt = DateTime.fromMillisecondsSinceEpoch(0);
      }

      return ChatMessage(
        id: id,
        text: e['text'] as String,
        isUser: (e['is_user'] is bool)
          ? e['is_user'] as bool
          : (e['is_user'] as int) == 1,
        createdAt: createdAt,
      );
    }).toList();
  }

  /// Fetch tutorial flags for the given device.
  /// Returns { tutorial_onboarding_seen: int, tutorial_onboarding_eligible: int }
  static Future<Map<String, int>> fetchTutorialFlags(String deviceId) async {
    final jwt = await AuthService().getJwt();
    final resp = await dio.get(
      '/api/tutorial-flags',
      queryParameters: {'device_id': deviceId},
      options: Options(headers: {'Authorization': 'Bearer $jwt'}),
    );
    return {
      'tutorial_onboarding_seen': resp.data['tutorial_onboarding_seen'] as int? ?? 0,
      'tutorial_onboarding_eligible': resp.data['tutorial_onboarding_eligible'] as int? ?? 0,
    };
  }

  /// Update tutorial flags for current user.
  static Future<void> updateTutorialFlags(
      String deviceId, {int? seen, int? eligible}) async {
    final jwt = await AuthService().getJwt();
    await dio.post(
      '/api/tutorial-flags',
      data: {
        'device_id': deviceId,
        if (seen != null) 'tutorial_onboarding_seen': seen,
        if (eligible != null) 'tutorial_onboarding_eligible': eligible,
      },
      options: Options(headers: {'Authorization': 'Bearer $jwt'}),
    );
  }
 
}
