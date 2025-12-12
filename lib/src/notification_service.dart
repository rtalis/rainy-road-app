import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Global navigator key for navigating from notification callbacks
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  // Callback to be set by main app when notification is tapped
  static VoidCallback? onNotificationTapped;

  Future<void> initialize() async {
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('ic_stat_rr');

    const InitializationSettings initializationSettings =
        InitializationSettings(android: initializationSettingsAndroid);

    await flutterLocalNotificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );

    // Check if app was launched from notification
    final NotificationAppLaunchDetails? launchDetails =
        await flutterLocalNotificationsPlugin.getNotificationAppLaunchDetails();
    if (launchDetails?.didNotificationLaunchApp ?? false) {
      // App was launched from notification, we'll handle this after the app is ready
      _pendingNotificationPayload =
          launchDetails?.notificationResponse?.payload;
    }
  }

  static String? _pendingNotificationPayload;

  /// Check if there's a pending notification that launched the app
  static String? get pendingNotificationPayload {
    final payload = _pendingNotificationPayload;
    _pendingNotificationPayload = null; // Clear after reading
    return payload;
  }

  void _onNotificationTapped(NotificationResponse response) {
    // When notification is tapped, trigger the callback
    if (onNotificationTapped != null) {
      onNotificationTapped!();
    }
  }

  Future<void> showNotification(String title, String body, String icon) async {
    AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
      icon: icon,
      fullScreenIntent: true,
      'high_importance_channel',
      'This channel is used for important notifications.',
      importance: Importance.high,
      priority: Priority.high,
    );

    NotificationDetails platformChannelSpecifics =
        NotificationDetails(android: androidPlatformChannelSpecifics);

    await flutterLocalNotificationsPlugin.show(
      1,
      title,
      body,
      platformChannelSpecifics,
      payload: 'show_last_map',
    );
  }

  /// Save the last map HTML to SharedPreferences
  static Future<void> saveLastMapHtml(String html) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('last_map_html', html);
  }

  /// Load the last map HTML from SharedPreferences
  static Future<String?> loadLastMapHtml() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('last_map_html');
  }
}
