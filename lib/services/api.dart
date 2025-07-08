// lib/services/api.dart
import 'package:dio/dio.dart';

final dio = Dio(
  BaseOptions(
    baseUrl: 'http://57.182.33.61.nip.io',           
    connectTimeout: const Duration(seconds: 20),
    receiveTimeout: const Duration(seconds: 60),
    validateStatus: (_) => true, 
  ),
);
