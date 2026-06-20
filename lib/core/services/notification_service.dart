import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:uuid/uuid.dart';
import '../../domain/entities/notification_entity.dart';
import '../db/hive_setup.dart';
import 'dart:math';
import 'dart:ui';


class NotificationService {
  static final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  static bool _initialized = false;

  static Future<void> init() async {
    if (_initialized) return;

    const AndroidInitializationSettings androidSettings = AndroidInitializationSettings('@mipmap/launcher_icon');
    const DarwinInitializationSettings iosSettings = DarwinInitializationSettings();
    
    const InitializationSettings initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _plugin.initialize(initSettings);
    _initialized = true;
  }

  static Future<void> showNotification({
    required String title,
    required String message,
  }) async {
    if (!_initialized) await init();

    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'harshpay_channel_id',
      'Harsh Pay Notifications',
      channelDescription: 'Notifications for Harsh Pay transactions',
      importance: Importance.max,
      priority: Priority.high,
      icon: '@mipmap/launcher_icon',
      color: Color(0xFF10B981), // AppColors.primary
    );

    const NotificationDetails details = NotificationDetails(
      android: androidDetails,
      iOS: DarwinNotificationDetails(),
    );

    final int notificationId = Random().nextInt(100000);
    
    await _plugin.show(
      notificationId,
      title,
      message,
      details,
    );

    // Save to Hive
    final entity = NotificationEntity(
      id: const Uuid().v4(),
      userId: 'offline_user',
      title: title,
      message: message,
      timestamp: DateTime.now().toIso8601String(),
    );

    await HiveSetup.saveNotification(entity);
  }
}
