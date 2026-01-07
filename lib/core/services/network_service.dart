import 'dart:async';
import 'package:http/http.dart' as http;

class NetworkService {
  static final NetworkService _instance = NetworkService._internal();
  factory NetworkService() => _instance;
  NetworkService._internal();

  final _client = http.Client();
  final _cache = <String, dynamic>{};
  final _cacheDuration = const Duration(minutes: 5);
  final _cacheTimestamps = <String, DateTime>{};

  // Generic GET request with caching
  Future<T> get<T>({
    required String url,
    required T Function(Map<String, dynamic>) fromJson,
    bool useCache = true,
    Duration? cacheDuration,
  }) async {
    if (useCache) {
      final cachedData = _getCachedData<T>(url, fromJson);
      if (cachedData != null) {
        return cachedData;
      }
    }

    try {
      final response = await _client.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final data = fromJson(response.body as Map<String, dynamic>);
        if (useCache) {
          _cacheData(url, data, cacheDuration);
        }
        return data;
      } else {
        throw Exception('Failed to load data: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Network error: $e');
    }
  }

  // Generic POST request
  Future<T> post<T>({
    required String url,
    required Map<String, dynamic> body,
    required T Function(Map<String, dynamic>) fromJson,
  }) async {
    try {
      final response = await _client.post(
        Uri.parse(url),
        body: body,
      );
      if (response.statusCode == 200 || response.statusCode == 201) {
        return fromJson(response.body as Map<String, dynamic>);
      } else {
        throw Exception('Failed to post data: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Network error: $e');
    }
  }

  // Cache management
  void _cacheData(String key, dynamic data, Duration? duration) {
    _cache[key] = data;
    _cacheTimestamps[key] = DateTime.now().add(duration ?? _cacheDuration);
  }

  T? _getCachedData<T>(String key, T Function(Map<String, dynamic>) fromJson) {
    if (_cache.containsKey(key)) {
      final timestamp = _cacheTimestamps[key];
      if (timestamp != null && timestamp.isAfter(DateTime.now())) {
        return _cache[key] as T;
      } else {
        _cache.remove(key);
        _cacheTimestamps.remove(key);
      }
    }
    return null;
  }

  // Clear cache
  void clearCache() {
    _cache.clear();
    _cacheTimestamps.clear();
  }

  // Dispose
  void dispose() {
    _client.close();
  }
} 