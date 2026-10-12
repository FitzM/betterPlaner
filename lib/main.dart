import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Graceful Firebase initialization
  try {
    if (kIsWeb) {
      // If configured for web, initialize
      // await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
    } else {
      // await Firebase.initializeApp();
    }
  } catch (e) {
    if (kDebugMode) {
      print('Firebase initialization skipped or not configured: $e');
    }
  }

  runApp(
    const ProviderScope(
      child: PlanApp(),
    ),
  );
}
