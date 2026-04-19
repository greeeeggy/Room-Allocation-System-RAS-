import 'package:onesignal_flutter/onesignal_flutter.dart';
import 'package:flutter/foundation.dart';

class OneSignalService {
  static final OneSignalService _instance = OneSignalService._internal();
  factory OneSignalService() => _instance;
  OneSignalService._internal();

  // ----- CONFIGURATION -----
  // TODO: Replace with your actual OneSignal App ID from the dashboard
  static const String appId = "2aed1639-f07d-4261-a3d6-c706e05f0e3f";
  // -------------------------

  bool _isInitialized = false;

  Future<void> init() async {
    if (_isInitialized) return;

    if (kDebugMode) {
      OneSignal.Debug.setLogLevel(OSLogLevel.verbose);
    }

    // Initialize OneSignal
    OneSignal.initialize(appId);

    // Request permissions
    await OneSignal.Notifications.requestPermission(true);

    _isInitialized = true;
  }

  /// Maps the Firebase userId to OneSignal's external_id.
  /// This allows us to target notifications to specific users (e.g., Conflicts).
  Future<void> login(String userId) async {
    try {
      await OneSignal.login(userId);
      if (kDebugMode) {
        print("OneSignal: User logged in with external_id: $userId");
      }
    } catch (e) {
      if (kDebugMode) {
        print("OneSignal: Error logging in user: $e");
      }
    }
  }

  /// Removes the user mapping on logout.
  Future<void> logout() async {
    try {
      await OneSignal.logout();
    } catch (e) {
      if (kDebugMode) {
        print("OneSignal: Error logging out user: $e");
      }
    }
  }
}
