// lib/main.dart
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:go_router/go_router.dart';
import 'core/constants.dart';
import 'screens/home_screen.dart';
import 'screens/call_detail_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/ai_reply_screen.dart';
import 'services/notification_service.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  print("Handling a background message: ${message.messageId}");
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase
  await Firebase.initializeApp();

  // Initialize Supabase
  await Supabase.initialize(
    url: AppConstants.supabaseUrl,
    anonKey: AppConstants.supabaseAnonKey,
  );

  // Initialize notifications
  await NotificationService.initialize();

  // Request FCM token and save to Supabase
  final fcmToken = await FirebaseMessaging.instance.getToken();
  if (fcmToken != null) {
    try {
      await Supabase.instance.client.from('fcm_tokens').upsert({
        'fcm_token': fcmToken,
        'device_id': 'android_device_${DateTime.now().millisecondsSinceEpoch}',
      });
    } catch (e) {
      print('Error saving FCM token: $e');
    }
  }

  // Set up background message handler
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  runApp(const ProviderScope(child: MyApp()));
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  late GoRouter _router;

  @override
  void initState() {
    super.initState();
    _router = GoRouter(
      routes: [
        GoRoute(path: '/', builder: (context, state) => const HomeScreen()),
        GoRoute(
          path: '/call/:id',
          builder: (context, state) {
            final id = state.pathParameters['id']!;
            return CallDetailScreen(callLogId: id);
          },
        ),
        GoRoute(
          path: '/settings',
          builder: (context, state) => const SettingsScreen(),
        ),
        GoRoute(
          path: '/ai-reply',
          builder: (context, state) => const AIReplyScreen(),
        ),
      ],
      redirect: (context, state) {
        // Handle notification deep links
        final callLogId = state.uri.queryParameters['call_log_id'];
        if (callLogId != null && state.matchedLocation == '/') {
          return '/call/$callLogId';
        }
        return null;
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'AI Call Assistant',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
        fontFamily: 'Inter',
      ),
      routerDelegate: _router.routerDelegate,
      routeInformationParser: _router.routeInformationParser,
      routeInformationProvider: _router.routeInformationProvider,
    );
  }
}
