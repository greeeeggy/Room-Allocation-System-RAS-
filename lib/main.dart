import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'firebase_options.dart';
import 'core/theme.dart';
import 'core/router.dart';
import 'core/utils/status_engine.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  // Run auto-release and no-show detection on startup
  // Wrapped in try-catch: a Firestore permission error (or any other failure)
  // must NOT crash main() before runApp() is reached — that causes a black screen.
  final statusEngine = StatusEngine();
  try {
    await statusEngine.runOnAppLoad();
  } catch (e) {
    // StatusEngine failure is non-fatal; the app should still launch.
    debugPrint('[StatusEngine] runOnAppLoad failed: $e');
  }
  // Keep checking every minute so rooms auto-release while the app is open.
  statusEngine.startPeriodicCheck();
  runApp(const ProviderScope(child: RoomAvailabilityApp()));
}

class RoomAvailabilityApp extends ConsumerWidget {
  const RoomAvailabilityApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    return MaterialApp.router(
      title: 'Room Availability',
      theme: AppTheme.light,
      routerConfig: router,
      debugShowCheckedModeBanner: false,
    );
  }
}
