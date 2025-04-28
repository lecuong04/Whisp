import 'dart:async';
import 'dart:ui';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const notificationChannelId = 'WhispChannel';

const notificationId = 1975;

@pragma('vm:entry-point')
Future<void> onStart(ServiceInstance service) async {
  DartPluginRegistrant.ensureInitialized();

  await dotenv.load(fileName: ".env");

  final FlutterLocalNotificationsPlugin notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  var client = SupabaseClient(
    'https://${dotenv.env['SUPABASE_PROJECT_ID']}.supabase.co',
    dotenv.env['SUPABASE_ANON_KEY']!,
  );

  await (service as AndroidServiceInstance).setAsBackgroundService();

  service.on('startBackground').listen((e) async {
    await client.auth.signInAnonymously();
    var channel = client.channel('public:pending_messages');
    channel
        .onPostgresChanges(
          schema: "public",
          table: "pending_messages",
          event: PostgresChangeEvent.insert,
          callback: (payload) {
            notificationsPlugin.show(
              notificationId,
              '${payload.newRecord['title']}',
              payload.newRecord['content'],
              const NotificationDetails(
                android: AndroidNotificationDetails(
                  notificationChannelId,
                  'Whisp',
                  icon: 'ic_bg_service_small',
                  ongoing: false,
                ),
              ),
              payload: payload.newRecord.toString(),
            );
          },
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: "receiver_id",
            value: e!["userId"],
          ),
        )
        .subscribe((status, error) {
          print("$status | $error");
        });
  });

  service.on('stopBackground').listen((e) async {
    await client.realtime.disconnect();
    await client.auth.signOut();
  });
}

Future<void> startBackgroundService() async {
  await initNotification();
  final service = FlutterBackgroundService();
  await service.configure(
    androidConfiguration: AndroidConfiguration(
      onStart: onStart,
      autoStartOnBoot: false,
      autoStart: false,
      isForegroundMode: false,
      notificationChannelId: notificationChannelId,
      initialNotificationTitle: 'Listening for messages',
      initialNotificationContent: 'Service is running...',
      foregroundServiceNotificationId: notificationId,
      foregroundServiceTypes: [AndroidForegroundType.dataSync],
    ),
    iosConfiguration: IosConfiguration(),
  );
  await service.startService();
}

@pragma('vm:entry-point')
void backgroundHandler(NotificationResponse response) {
  print("Payload: ${response.payload}");
}

Future<void> initNotification() async {
  const AndroidNotificationChannel notificationChannel =
      AndroidNotificationChannel(
        notificationChannelId,
        'Whisp',
        description: 'This channel is used for important notifications.',
        importance: Importance.defaultImportance,
      );

  final FlutterLocalNotificationsPlugin notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  await notificationsPlugin.initialize(
    InitializationSettings(
      android: AndroidInitializationSettings("ic_bg_service_small"),
    ),
    onDidReceiveNotificationResponse: (response) async => backgroundHandler,
    onDidReceiveBackgroundNotificationResponse: backgroundHandler,
  );

  await notificationsPlugin
      .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin
      >()
      ?.createNotificationChannel(notificationChannel);
}
