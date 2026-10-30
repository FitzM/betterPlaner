import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app.dart';
import 'core/utils/ticktick_parser.dart';
import 'firebase_options.dart';
import 'repositories/mock_data.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load TickTick CSV backup from bundled assets if present
  try {
    final csvString = await rootBundle.loadString('assets/ticktick_backup.csv');
    if (csvString.trim().isNotEmpty) {
      final result = TickTickParser.parseCsv(csvString);
      if (result.projects.isNotEmpty || result.tasks.isNotEmpty) {
        MockData.loadTickTickData(result.projects, result.tasks);
        if (kDebugMode) {
          print('Loaded TickTick CSV: ${result.projects.length} lists, ${result.tasks.length} tasks (${result.subtaskCount} subtasks)');
        }
      }
    }
  } catch (e) {
    if (kDebugMode) {
      print('Notice: assets/ticktick_backup.csv could not be loaded: $e');
    }
  }

  // Graceful Firebase initialization
  try {
    if (DefaultFirebaseOptions.isConfigured) {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      if (kDebugMode) {
        print('Firebase initialized successfully (${Firebase.app().name})');
      }
    } else {
      if (kDebugMode) {
        print('Firebase running in Local-First mode (unconfigured placeholder credentials).');
      }
    }
  } catch (e) {
    if (kDebugMode) {
      print('Firebase initialization skipped or error: $e');
    }
  }

  runApp(
    const ProviderScope(
      child: PlanApp(),
    ),
  );
}
