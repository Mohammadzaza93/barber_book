import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import 'shop_manager.dart';

class NotificationService {
  NotificationService._();
  static final instance = NotificationService._();

  final FlutterLocalNotificationsPlugin _local =
      FlutterLocalNotificationsPlugin();
  // Lazy on purpose: `NotificationService.instance` is reachable from the
  // provider tree, and `FirebaseMessaging.instance` throws [core/no-app] when
  // Firebase failed to initialize.
  FirebaseMessaging get _messaging => FirebaseMessaging.instance;
  bool _initialized = false;

  /// Timezone used to schedule local reminder notifications. Matches the
  /// server-side default offset in `functions/src/lib/time.js`.
  static const String _shopTimeZone = 'Asia/Riyadh';

  Future<void> init() async {
    if (_initialized) return;
    tzdata.initializeTimeZones();
    try {
      tz.setLocalLocation(tz.getLocation(_shopTimeZone));
    } catch (e) {
      // Previously silent: every reminder then fired at device-local
      // wall-clock time instead of the shop's timezone, with no signal that
      // the fallback had been taken.
      debugPrint(
        'NotificationService: failed to load $_shopTimeZone ($e); '
        'falling back to device timezone for reminders',
      );
      tz.setLocalLocation(tz.local);
    }

    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const ios = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    const settings = InitializationSettings(android: android, iOS: ios);
    await _local.initialize(settings);
    final androidPlugin = _local.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    await androidPlugin?.requestNotificationsPermission();

    await _messaging.requestPermission(alert: true, badge: true, sound: true);
    _messaging.setForegroundNotificationPresentationOptions(
      alert: true, badge: true, sound: true,
    );

    FirebaseMessaging.onMessage.listen(
      (RemoteMessage message) {
        final n = message.notification;
        if (n != null) {
          show(n.title ?? '', n.body ?? '');
        }
      },
      onError: (Object e, StackTrace _) =>
          debugPrint('NotificationService: foreground stream error: $e'),
    );

    _initialized = true;
  }

  Future<String?> getToken() => _messaging.getToken();

  Future<void> subscribeToShop() async {
    if (ShopManager.shopId != null) {
      await _messaging.subscribeToTopic(ShopManager.shopId!);
    }
  }

  Future<void> unsubscribeFromShop() async {
    if (ShopManager.shopId != null) {
      await _messaging.unsubscribeFromTopic(ShopManager.shopId!);
    }
  }

  Future<void> show(String title, String body) async {
    const android = AndroidNotificationDetails(
      'reminders',
      'Reminders & appointments',
      channelDescription: 'Appointment reminders and notifications',
      importance: Importance.high,
      priority: Priority.high,
    );
    const ios = DarwinNotificationDetails();
    const details = NotificationDetails(android: android, iOS: ios);
    await _local.show(
      DateTime.now().millisecondsSinceEpoch.remainder(100000),
      title,
      body,
      details,
    );
  }

  Future<void> scheduleReminder(
      int id, DateTime when, String title, String body) async {
    final tzWhen = tz.TZDateTime.from(when, tz.local);
    final now = tz.TZDateTime.now(tz.local);
    if (!tzWhen.isAfter(now)) return;

    const android = AndroidNotificationDetails(
      'reminders',
      'Reminders & appointments',
      channelDescription: 'Appointment reminders',
      importance: Importance.high,
      priority: Priority.high,
    );
    const ios = DarwinNotificationDetails();
    const details = NotificationDetails(android: android, iOS: ios);

    await _local.zonedSchedule(
      id,
      title,
      body,
      tzWhen,
      details,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  Future<void> cancel(int id) => _local.cancel(id);
}
