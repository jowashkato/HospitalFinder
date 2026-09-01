// lib/main.dart
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'app_theme.dart';
import 'home.dart';

// Global notifications plugin
final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    // Initialize Supabase
    await Supabase.initialize(
      url: 'https://klwvscymnspnzxvgbkoc.supabase.co',
      anonKey:
          'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imtsd3ZzY3ltbnNwbnp4dmdia29jIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTgzNjMxODIsImV4cCI6MjA3MzkzOTE4Mn0.M5Is7tN0VPvpmKtFCyw2yGF0icYls1xhfJWUnxqDTPU',
    );

    // Timezone: load the database, then pin it to the device's zone so the
    // daily notification fires at 10 AM *local* time (not UTC).
    tzdata.initializeTimeZones();
    if (!kIsWeb) {
      try {
        // flutter_timezone returns a String on v3 and a TimezoneInfo (with an
        // `identifier` field) on v4 — handle both.
        final dynamic result = await FlutterTimezone.getLocalTimezone();
        final String localZone =
            result is String ? result : (result.identifier as String);
        tz.setLocalLocation(tz.getLocation(localZone));
      } catch (_) {
        // Fall back to the package default (UTC) if the platform lookup fails.
      }
    }

    // Configure notifications (Android + iOS)
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const DarwinInitializationSettings initializationSettingsIOS =
        DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    const InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsIOS,
    );

    // Only initialize notifications on mobile (not web/desktop)
    if (!kIsWeb) {
      await flutterLocalNotificationsPlugin.initialize(initializationSettings);
      await _requestNotificationPermissions();

      // Respect the signed-in user's preference (defaults to on for guests).
      bool wantDaily = true;
      final session = Supabase.instance.client.auth.currentSession;
      if (session != null) {
        try {
          final row = await Supabase.instance.client
              .from('profiles')
              .select('daily_notifications_enabled')
              .eq('id', session.user.id)
              .maybeSingle();
          if (row != null && row['daily_notifications_enabled'] == false) {
            wantDaily = false;
          }
        } catch (_) {
          // Offline / table missing — fall back to scheduling.
        }
      }

      if (wantDaily) {
        await scheduleDailyNotification();
      } else {
        await cancelDailyNotification();
      }
    }
  } catch (e) {
    debugPrint('Initialization error: $e');
  }

  runApp(const MyApp());
}

/// Ask for the notification permission (Android 13+ and iOS).
Future<void> _requestNotificationPermissions() async {
  try {
    await flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();

    await flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin>()
        ?.requestPermissions(alert: true, badge: true, sound: true);
  } catch (e) {
    debugPrint('Notification permission request failed: $e');
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'HospitalFinder',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      home: const HomePage(),
    );
  }
}

/// Schedules a daily wellness notification at 10 AM local time.
Future<void> scheduleDailyNotification() async {
  try {
    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'daily_channel',
      'Daily Health Tips',
      channelDescription: 'A wellness tip every morning',
      importance: Importance.max,
      priority: Priority.high,
    );

    const DarwinNotificationDetails iosDetails = DarwinNotificationDetails();

    const NotificationDetails platformDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await flutterLocalNotificationsPlugin.zonedSchedule(
      0,
      'Daily Health Tip',
      'Stay hydrated! Drink at least 8 glasses of water today.',
      _nextInstanceOfTenAM(),
      platformDetails,
      // Inexact avoids the restricted SCHEDULE_EXACT_ALARM permission; a daily
      // tip does not need to-the-minute precision.
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  } catch (e) {
    debugPrint("Notification scheduling failed: $e");
  }
}

/// Cancels the daily wellness notification (used when a user opts out).
Future<void> cancelDailyNotification() async {
  try {
    await flutterLocalNotificationsPlugin.cancel(0);
  } catch (e) {
    debugPrint("Notification cancel failed: $e");
  }
}

/// Helper to calculate next 10 AM in the device's local zone.
tz.TZDateTime _nextInstanceOfTenAM() {
  final tz.TZDateTime now = tz.TZDateTime.now(tz.local);
  tz.TZDateTime scheduledDate =
      tz.TZDateTime(tz.local, now.year, now.month, now.day, 10);
  if (scheduledDate.isBefore(now)) {
    scheduledDate = scheduledDate.add(const Duration(days: 1));
  }
  return scheduledDate;
}
