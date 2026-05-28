import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';

class ApiService {
  static const String baseUrl = 'http://localhost:8000/api';

  // Fallback check to see if Backend is reachable
  static Future<bool> isBackendAvailable() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/employees')).timeout(
        const Duration(seconds: 2),
      );
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }
}

// Model for Sync Queues
class SyncItem {
  final String id;
  final String action; // 'attendance_checkin', 'attendance_checkout', 'leave_request', 'loan_request'
  final Map<String, dynamic> data;
  final DateTime originalTimestamp;

  SyncItem({
    required this.id,
    required this.action,
    required this.data,
    required this.originalTimestamp,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'action': action,
    'data': data,
    'original_timestamp': originalTimestamp.toIso8601String(),
  };

  factory SyncItem.fromJson(Map<String, dynamic> json) => SyncItem(
    id: json['id'],
    action: json['action'],
    data: Map<String, dynamic>.from(json['data']),
    originalTimestamp: DateTime.parse(json['original_timestamp']),
  );
}

// SyncProvider to orchestrate offline queues and connection state
class SyncProvider extends ChangeNotifier {
  List<SyncItem> _queue = [];
  bool _isOffline = false;
  bool _isSyncing = false;

  List<SyncItem> get queue => _queue;
  bool get isOffline => _isOffline;
  bool get isSyncing => _isSyncing;

  SyncProvider() {
    _loadQueue();
    _startConnectionPolling();
  }

  Future<void> _loadQueue() async {
    final prefs = await SharedPreferences.getInstance();
    final String? queueData = prefs.getString('offline_sync_queue');
    if (queueData != null) {
      final List<dynamic> decoded = json.decode(queueData);
      _queue = decoded.map((item) => SyncItem.fromJson(item)).toList();
      notifyListeners();
    }
  }

  Future<void> _saveQueue() async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = json.encode(_queue.map((item) => item.toJson()).toList());
    await prefs.setString('offline_sync_queue', encoded);
  }

  void addToQueue(String action, Map<String, dynamic> data) {
    final newItem = SyncItem(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      action: action,
      data: data,
      originalTimestamp: DateTime.now(),
    );
    _queue.add(newItem);
    _saveQueue();
    notifyListeners();
  }

  Future<void> triggerSync() async {
    if (_queue.isEmpty || _isSyncing) return;
    
    _isSyncing = true;
    notifyListeners();

    // Check if network is available
    bool available = await ApiService.isBackendAvailable();
    if (!available) {
      _isSyncing = false;
      _isOffline = true;
      notifyListeners();
      return;
    }

    _isOffline = false;
    List<SyncItem> succeeded = [];

    for (var item in _queue) {
      try {
        final response = await _sendItemToServer(item);
        if (response) {
          succeeded.add(item);
        }
      } catch (_) {
        break; // Network failed during sync loop
      }
    }

    _queue.removeWhere((item) => succeeded.contains(item));
    await _saveQueue();
    _isSyncing = false;
    notifyListeners();
  }

  Future<bool> _sendItemToServer(SyncItem item) async {
    // Send simulated HTTP request to Laravel server backend
    final url = '${ApiService.baseUrl}/${_getEndpoint(item.action)}';
    try {
      final response = await http.post(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          ...item.data,
          'original_timestamp': DateFormat('yyyy-MM-dd HH:mm:ss').format(item.originalTimestamp),
        }),
      );
      return response.statusCode == 200 || response.statusCode == 201;
    } catch (_) {
      return false;
    }
  }

  String _getEndpoint(String action) {
    if (action.startsWith('attendance')) return 'attendance';
    if (action == 'leave_request') return 'leaves';
    if (action == 'loan_request') return 'loans';
    if (action == 'location_tracking') return 'locations';
    return '';
  }

  void _startConnectionPolling() {
    Future.doWhile(() async {
      await Future.delayed(const Duration(seconds: 8));
      bool available = await ApiService.isBackendAvailable();
      if (_isOffline != !available) {
        _isOffline = !available;
        notifyListeners();
      }
      if (available && _queue.isNotEmpty) {
        await triggerSync();
      }
      return true;
    });
  }

  void forceConnectionState(bool offline) {
    _isOffline = offline;
    notifyListeners();
  }
}

// Model for Visited Tracked Locations
class VisitedLocation {
  final String id;
  final String employeeId;
  final String employeeNameAr;
  final String placeName;
  final double latitude;
  final double longitude;
  final DateTime visitedAt;

  VisitedLocation({
    required this.id,
    required this.employeeId,
    required this.employeeNameAr,
    required this.placeName,
    required this.latitude,
    required this.longitude,
    required this.visitedAt,
  });

  factory VisitedLocation.fromJson(Map<String, dynamic> json) => VisitedLocation(
    id: json['id'],
    employeeId: json['employeeId'],
    employeeNameAr: json['employeeNameAr'] ?? '',
    placeName: json['placeName'] ?? '',
    latitude: json['latitude'] is String ? double.parse(json['latitude']) : (json['latitude'] as num).toDouble(),
    longitude: json['longitude'] is String ? double.parse(json['longitude']) : (json['longitude'] as num).toDouble(),
    visitedAt: DateTime.parse(json['visitedAt'] ?? json['visited_at']),
  );
}

// LocationsProvider to handle registering and fetching tracked places
class LocationsProvider extends ChangeNotifier {
  List<VisitedLocation> _locations = [];
  bool _isLoading = false;
  String _errorMessage = '';

  List<VisitedLocation> get locations => _locations;
  bool get isLoading => _isLoading;
  String get errorMessage => _errorMessage;

  Future<void> fetchLocations(String employeeId) async {
    _isLoading = true;
    _errorMessage = '';
    notifyListeners();

    try {
      final url = '${ApiService.baseUrl}/locations?employee_id=$employeeId';
      final response = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 4));
      
      if (response.statusCode == 200) {
        final List<dynamic> decoded = json.decode(response.body);
        _locations = decoded.map((l) => VisitedLocation.fromJson(l)).toList();
      } else {
        _errorMessage = 'تعذر تحميل المواقع المسجلة من السيرفر.';
      }
    } catch (_) {
      _errorMessage = 'تعذر الاتصال بالخادم، يتم عرض البيانات المسجلة محلياً.';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> fetchAllLocations() async {
    _isLoading = true;
    _errorMessage = '';
    notifyListeners();

    try {
      final url = '${ApiService.baseUrl}/locations';
      final response = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 4));
      
      if (response.statusCode == 200) {
        final List<dynamic> decoded = json.decode(response.body);
        _locations = decoded.map((l) => VisitedLocation.fromJson(l)).toList();
      } else {
        _errorMessage = 'تعذر تحميل سجل المواقع من السيرفر.';
      }
    } catch (_) {
      _errorMessage = 'تعذر الاتصال بالخادم الرئيسي.';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> registerLocation({
    required String employeeId,
    required String placeName,
    required SyncProvider syncProvider,
  }) async {
    _isLoading = true;
    _errorMessage = '';
    notifyListeners();

    try {
      // 1. Get GPS coordinates
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      final now = DateTime.now();
      final data = {
        'employeeId': employeeId,
        'placeName': placeName,
        'latitude': position.latitude,
        'longitude': position.longitude,
      };

      if (syncProvider.isOffline) {
        // Queue it offline
        syncProvider.addToQueue('location_tracking', data);
      } else {
        // Post immediately
        final response = await http.post(
          Uri.parse('${ApiService.baseUrl}/locations'),
          headers: {'Content-Type': 'application/json'},
          body: json.encode({
            ...data,
            'original_timestamp': DateFormat('yyyy-MM-dd HH:mm:ss').format(now),
          }),
        ).timeout(const Duration(seconds: 4));

        if (response.statusCode != 200 && response.statusCode != 201) {
          syncProvider.addToQueue('location_tracking', data);
        }
      }

      // Add to local list to reflect instantly in UI
      _locations.insert(
        0,
        VisitedLocation(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          employeeId: employeeId,
          employeeNameAr: '',
          placeName: placeName,
          latitude: position.latitude,
          longitude: position.longitude,
          visitedAt: now,
        ),
      );
      
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = 'خطأ أثناء تسجيل الموقع الجغرافي: ${e.toString()}';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }
}

// AttendanceProvider for Geolocated Geofencing Check-in
class AttendanceProvider extends ChangeNotifier {
  bool _isCheckedIn = false;
  DateTime? _checkInTime;
  double? _lastDistance;
  bool _isVerifyingGPS = false;
  String _errorMessage = '';

  bool get isCheckedIn => _isCheckedIn;
  DateTime? get checkInTime => _checkInTime;
  double? get lastDistance => _lastDistance;
  bool get isVerifyingGPS => _isVerifyingGPS;
  String get errorMessage => _errorMessage;

  // Branch default Location coordinates (e.g. Cairo Office)
  final double branchLatitude = 30.0444;
  final double branchLongitude = 31.2357;
  final double maxAllowedRadiusMeters = 250.0;

  Future<bool> toggleAttendance(String employeeId, SyncProvider syncProvider) async {
    _isVerifyingGPS = true;
    _errorMessage = '';
    notifyListeners();

    try {
      // 1. Check Location Permission & Get Coordinates
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          _errorMessage = 'يجب تفعيل أذونات الموقع لتسجيل الحضور الجغرافي.';
          _isVerifyingGPS = false;
          notifyListeners();
          return false;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        _errorMessage = 'أذونات الموقع مرفوضة دائماً، يرجى تفعيلها من إعدادات الهاتف.';
        _isVerifyingGPS = false;
        notifyListeners();
        return false;
      }

      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      // 2. Calculate Distance using Haversine formula
      double distanceInMeters = Geolocator.distanceBetween(
        position.latitude,
        position.longitude,
        branchLatitude,
        branchLongitude,
      );

      _lastDistance = distanceInMeters;

      // 3. Validate Geofencing (250m)
      if (distanceInMeters > maxAllowedRadiusMeters) {
        _errorMessage = 'عذراً! أنت خارج النطاق الجغرافي المعتمد للفرع.\n'
            'مسافتك الحالية: ${distanceInMeters.toStringAsFixed(0)} متر.\n'
            'النطاق المسموح به: 250 متر فقط.';
        _isVerifyingGPS = false;
        notifyListeners();
        return false;
      }

      // 4. Register Attendance locally and queue or send to server
      final now = DateTime.now();
      final action = _isCheckedIn ? 'attendance_checkout' : 'attendance_checkin';
      final data = {
        'employee_id': employeeId,
        'latitude': position.latitude,
        'longitude': position.longitude,
        'distance': distanceInMeters,
      };

      if (syncProvider.isOffline) {
        // Queue it offline
        syncProvider.addToQueue(action, data);
      } else {
        // Attempt immediate server post
        try {
          final response = await http.post(
            Uri.parse('${ApiService.baseUrl}/attendance'),
            headers: {'Content-Type': 'application/json'},
            body: json.encode({
              ...data,
              'original_timestamp': DateFormat('yyyy-MM-dd HH:mm:ss').format(now),
            }),
          ).timeout(const Duration(seconds: 4));
          
          if (response.statusCode != 200 && response.statusCode != 201) {
            // Queue on failure
            syncProvider.addToQueue(action, data);
          }
        } catch (_) {
          syncProvider.addToQueue(action, data);
        }
      }

      // Update local state
      _isCheckedIn = !_isCheckedIn;
      _checkInTime = _isCheckedIn ? now : null;
      _isVerifyingGPS = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = 'حدث خطأ أثناء الاتصال بنظام الـ GPS: ${e.toString()}';
      _isVerifyingGPS = false;
      notifyListeners();
      return false;
    }
  }
}
