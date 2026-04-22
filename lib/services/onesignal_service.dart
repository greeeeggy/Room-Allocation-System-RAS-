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

    // OneSignal Flutter SDK currently has limited support/complex setup for Web.
    // We skip it on Web for now to ensure the app runs.
    if (kIsWeb) {
      debugPrint("OneSignal: Skipping initialization on Web platform.");
      return;
    }

    try {
      if (kDebugMode) {
        OneSignal.Debug.setLogLevel(OSLogLevel.verbose);
      }

      // Initialize OneSignal
      OneSignal.initialize(appId);

      // Request permissions
      await OneSignal.Notifications.requestPermission(true);

      _isInitialized = true;
    } catch (e) {
      debugPrint("OneSignal: Initialization failed: $e");
    }
  }

  /// Maps the Firebase userId to OneSignal's external_id.
  /// This allows us to target notifications to specific users (e.g., Conflicts).
  Future<void> login(String userId) async {
    if (kIsWeb) return;
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
    if (kIsWeb) return;
    try {
      await OneSignal.logout();
    } catch (e) {
      if (kDebugMode) {
        print("OneSignal: Error logging out user: $e");
      }
    }
  }
}
