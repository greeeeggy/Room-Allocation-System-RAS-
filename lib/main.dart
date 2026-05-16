import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'firebase_options.dart';
import 'core/theme.dart';
import 'core/router.dart';
import 'core/utils/status_engine.dart';
import 'services/onesignal_service.dart';
import 'services/version_service.dart';
import 'providers/auth_provider.dart';
import 'widgets/update_dialog.dart';

void main() async {
  WidgetsBinding widgetsBinding = WidgetsFlutterBinding.ensureInitialized();
  FlutterNativeSplash.preserve(widgetsBinding: widgetsBinding);

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  
  // Initialize OneSignal Push Notifications in the background
  OneSignalService().init().catchError((e) {
    debugPrint('OneSignal initialization failed: $e');
  });

  // Run auto-release and no-show detection on startup in the background
  final statusEngine = StatusEngine();
  statusEngine.runOnAppLoad().catchError((e) {
    debugPrint('[StatusEngine] runOnAppLoad failed: $e');
  });
  statusEngine.startPeriodicCheck();
  
  runApp(const ProviderScope(child: RoomAvailabilitySystemApp()));
}

void _checkForUpdates(WidgetRef ref) async {
  final versionService = VersionService();
  final versionInfo = await versionService.checkForUpdates();
  
  if (versionInfo != null && versionInfo.isUpdateAvailable) {
    final router = ref.read(routerProvider);
    final context = router.routerDelegate.navigatorKey.currentContext;

    if (context != null && context.mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => UpdateDialog(
          version: versionInfo.latestVersion,
          releaseNotes: versionInfo.releaseNotes,
          downloadUrl: versionInfo.downloadUrl,
        ),
      );
    }
  }
}

class RoomAvailabilitySystemApp extends ConsumerWidget {
  const RoomAvailabilitySystemApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Sync user to OneSignal when logged in
    ref.listen(authStateProvider, (prev, next) {
      final user = next.valueOrNull;
      if (user != null) {
        OneSignalService().login(user.userId);
      } else {
        OneSignalService().logout();
      }
    });

    final router = ref.watch(routerProvider);
    
    // Check for updates after the first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkForUpdates(ref);
    });

    return MaterialApp.router(
      title: 'Room Availability System',
      theme: AppTheme.light,
      routerConfig: router,
      debugShowCheckedModeBanner: false,
    );
  }
}
