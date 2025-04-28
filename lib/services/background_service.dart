import 'dart:async';
import 'dart:io';
import 'dart:ui';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as path;

const notificationChannelId = 'Whisp';

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
    await service.setAsForegroundService();
    notificationsPlugin.show(
      notificationId + 1,
      "Whisp",
      "Listening for messages...",
      NotificationDetails(
        android: AndroidNotificationDetails(
          "${notificationChannelId}Service",
          "Whisp Service",
          ongoing: true,
          silent: true,
          channelShowBadge: false,
          playSound: false,
          enableVibration: false,
        ),
      ),
    );
    var dir = await getApplicationCacheDirectory();
    var avatarsDir = Directory(path.join(dir.path, "avatars"));
    if (!avatarsDir.existsSync()) {
      avatarsDir.createSync();
    }
    var channel = client.channel('public:pending_messages');
    channel
        .onPostgresChanges(
          schema: "public",
          table: "pending_messages",
          event: PostgresChangeEvent.insert,
          callback: (payload) async {
            File imgFile = File(
              path.join(
                avatarsDir.path,
                payload.newRecord["avatar_url"].toString().split("/").last,
              ),
            );
            if (!imgFile.existsSync()) {
              var r = await http.get(
                Uri.parse(payload.newRecord["avatar_url"].toString()),
              );
              imgFile.writeAsBytesSync(
                r.bodyBytes,
                mode: FileMode.writeOnly,
                flush: true,
              );
            }
            notificationsPlugin.show(
              notificationId,
              '<b>${payload.newRecord['title']}</b>',
              payload.newRecord['content'],
              NotificationDetails(
                android: AndroidNotificationDetails(
                  notificationChannelId,
                  'Messages',
                  icon: 'ic_bg_service_small',
                  groupKey: "Messages",
                  largeIcon: ByteArrayAndroidBitmap(imgFile.readAsBytesSync()),
                  styleInformation: DefaultStyleInformation(true, true),
                  ongoing: false,
                  category: AndroidNotificationCategory.social,
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
      autoStartOnBoot: true,
      autoStart: true,
      isForegroundMode: false,
      notificationChannelId: "${notificationChannelId}Service",
      initialNotificationTitle: 'Whisp',
      initialNotificationContent: 'Service is running...',
      foregroundServiceNotificationId: notificationId + 1,
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
      ?.createNotificationChannel(
        AndroidNotificationChannel(
          notificationChannelId,
          'Messages',
          importance: Importance.defaultImportance,
        ),
      );
  await notificationsPlugin
      .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin
      >()
      ?.createNotificationChannel(
        AndroidNotificationChannel(
          "${notificationChannelId}Service",
          'Whisp Service',
          importance: Importance.defaultImportance,
        ),
      );
}
