import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as path;
import 'package:url_launcher/url_launcher.dart';
import 'package:whisp/main.dart';
import 'package:whisp/presentation/screens/auth/login_screen.dart';
import 'package:whisp/presentation/screens/auth/signup_screen.dart';
import 'package:whisp/presentation/screens/messages_screen.dart';

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

  bool isStarted = false;

  service.on('startBackground').listen((e) async {
    if (e == null || !e.containsKey("refreshToken") || isStarted) return;
    var res = await client.auth.setSession(e['refreshToken']);
    if (res.session == null) return;
    isStarted = true;
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
              payload: jsonEncode(payload.newRecord),
            );
          },
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: "receiver_id",
            value: client.auth.currentUser!.id,
          ),
        )
        .subscribe((status, error) async {
          if (status == RealtimeSubscribeStatus.subscribed) {
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
          } else {
            print("$status | $error");
          }
        });
  });

  service.on('stopBackground').listen((e) async {
    isStarted = false;
    await client.realtime.disconnect();
    await client.auth.signOut();
    await service.setAsBackgroundService();
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
  if (response.payload == null || response.payload!.isEmpty) return;
  Map<String, dynamic> data = jsonDecode(response.payload!);
  if (navigatorKey.currentContext != null) {
    if (navigatorKey.currentWidget is LoginScreen ||
        navigatorKey.currentWidget is SignupScreen) {
      return;
    }
    Navigator.pushAndRemoveUntil(
      navigatorKey.currentContext!,
      MaterialPageRoute(builder: (context) => HomeScreen()),
      (route) => false,
    );
    Navigator.push(
      navigatorKey.currentContext!,
      MaterialPageRoute(
        builder:
            (context) => MessagesScreen(
              chatId: data["conversation_id"],
              contactName: data["title"],
              contactImage: data["avatar_url"],
            ),
      ),
    );
  } else {
    launchUrl(Uri(scheme: "whisp", host: "messages", queryParameters: data));
  }
}

Future<void> initNotification() async {
  final FlutterLocalNotificationsPlugin notificationsPlugin =
      FlutterLocalNotificationsPlugin();
  var appLaunchDetails =
      await notificationsPlugin.getNotificationAppLaunchDetails();
  if (appLaunchDetails != null && appLaunchDetails.didNotificationLaunchApp) {
    backgroundHandler(appLaunchDetails.notificationResponse!);
  }
  await notificationsPlugin.initialize(
    InitializationSettings(
      android: AndroidInitializationSettings("ic_bg_service_small"),
    ),
    onDidReceiveNotificationResponse: backgroundHandler,
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
