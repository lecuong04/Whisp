import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:whisp/custom_cache_manager.dart';
import 'package:whisp/main.dart';
import 'package:whisp/presentation/screens/auth/login_screen.dart';
import 'package:whisp/presentation/screens/auth/signup_screen.dart';
import 'package:whisp/presentation/screens/video_call_screen.dart';
import 'package:whisp/services/call_service.dart';

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
    if (e == null ||
        !e.containsKey("refreshToken") ||
        client.auth.currentSession != null) {
      return;
    }
    var res = await client.auth.setSession(e['refreshToken']);
    if (res.session == null) return;
    await service.setAsForegroundService();
    var channel = client.channel('public:pending_messages');
    channel
        .onPostgresChanges(
          schema: "public",
          table: "pending_messages",
          event: PostgresChangeEvent.insert,
          callback: (payload) async {
            await _showNotification(
              client,
              notificationsPlugin,
              payload.newRecord,
            );
          },
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: "receiver_id",
            value: client.auth.currentUser?.id,
          ),
        )
        .subscribe((status, error) async {
          if (status != RealtimeSubscribeStatus.subscribed) {
            print("$status | $error");
          }
        });
    var messages = await client.rpc(
      "get_pending_messages",
      params: {"_user_id": client.auth.currentUser?.id},
    );
    (messages as List<dynamic>);
    for (var msg in messages) {
      await _showNotification(client, notificationsPlugin, msg);
    }
    do {
      await client.rpc(
        "online_user",
        params: {"user_id": client.auth.currentUser?.id},
      );
      await Future.delayed(Duration(minutes: 2));
    } while (client.auth.currentUser != null);
  });

  service.on('stopBackground').listen((e) async {
    await client.realtime.disconnect();
    await client.auth.signOut();
    await service.setAsBackgroundService();
  });
}

Future<Uint8List?> _getAvatar(String avatarUrl) async {
  var info = await CustomCacheManager().downloadFile(avatarUrl);
  if (info.file.lengthSync() > 0) {
    return info.file.readAsBytesSync();
  } else {
    return null;
  }
}

Future<void> _showNotification(
  SupabaseClient client,
  FlutterLocalNotificationsPlugin notificationsPlugin,
  Map<String, dynamic> payload,
) async {
  var conversation =
      await client
          .rpc(
            "get_conversation_info",
            params: {
              "_conversation_id": payload["conversation_id"],
              "_user_id": payload["receiver_id"],
            },
          )
          .single();
  if (conversation.isEmpty) return;
  var sender =
      await client
          .rpc('get_user', params: {'user_id': payload["sender_id"]})
          .single();
  var senderAvatar = await _getAvatar(sender["avatar_url"]);
  var data = payload;
  data.removeWhere((k, v) => k == "is_group");
  data["title"] = conversation['title'];
  if (conversation['is_group']) {
    data["avatar_url"] = conversation["avatar_url"];
    var groupAvatar = await _getAvatar(conversation["avatar_url"]);
    notificationsPlugin.show(
      notificationId,
      '',
      '',
      NotificationDetails(
        android: AndroidNotificationDetails(
          notificationChannelId,
          'Messages',
          groupKey: payload["conversation_id"],
          tag: payload["conversation_id"],
          icon: 'ic_bg_service_small',
          largeIcon:
              groupAvatar != null ? ByteArrayAndroidBitmap(groupAvatar) : null,
          styleInformation: MessagingStyleInformation(
            Person(name: conversation['title']),
            groupConversation: true,
            messages: [
              Message(
                _buildMessageContent(payload['type'], payload["content"]),
                DateTime.parse(payload['sent_at']),
                Person(
                  name: sender['full_name'],
                  icon:
                      senderAvatar != null
                          ? ByteArrayAndroidIcon(senderAvatar)
                          : null,
                ),
              ),
            ],
            conversationTitle: conversation['title'],
            htmlFormatContent: true,
            htmlFormatTitle: true,
          ),
          ongoing: false,
          category: AndroidNotificationCategory.social,
        ),
      ),
      payload: jsonEncode(data),
    );
  } else {
    const int insistentFlag = 4;
    data["avatar_url"] = sender["avatar_url"];
    notificationsPlugin.show(
      notificationId,
      '<b>${conversation['title']}</b>',
      _buildMessageContent(payload['type'], payload["content"]),
      NotificationDetails(
        android: AndroidNotificationDetails(
          notificationChannelId,
          'Messages',
          largeIcon:
              senderAvatar != null
                  ? ByteArrayAndroidBitmap(senderAvatar)
                  : null,
          groupKey: payload["conversation_id"],
          tag: payload["conversation_id"],
          icon: 'ic_bg_service_small',
          priority:
              payload['type'] == 'call'
                  ? Priority.high
                  : Priority.defaultPriority,
          styleInformation: DefaultStyleInformation(true, true),
          category: AndroidNotificationCategory.social,
          additionalFlags:
              payload['type'] == 'call'
                  ? Int32List.fromList(<int>[insistentFlag])
                  : null,
        ),
      ),
      payload: jsonEncode(data),
    );
  }

  await client.rpc(
    "update_is_delivered",
    params: {
      "_message_id": payload["message_id"],
      "_user_id": payload["receiver_id"],
    },
  );
}

String _buildMessageContent(String type, String content) => switch (type) {
  "text" => content,
  "call" => "<i>Có cuộc gọi đến...</i>",
  "image" => "<i>Hình ảnh</i>",
  "video" => "<i>Video</i>",
  "file" => "<i>File</i>",
  "audio" => "<i>Âm thanh</i>",
  _ => "",
};

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
      initialNotificationTitle: 'Whisp Service',
      initialNotificationContent: 'Service is running...',
      foregroundServiceNotificationId: notificationId + 1,
      foregroundServiceTypes: [
        AndroidForegroundType.remoteMessaging,
        AndroidForegroundType.microphone,
      ],
    ),
    iosConfiguration: IosConfiguration(),
  );
  await service.startService();
}

@pragma('vm:entry-point')
void backgroundHandler(NotificationResponse response) async {
  if (response.payload == null || response.payload!.isEmpty) return;
  Map<String, dynamic> data = jsonDecode(response.payload!);
  if (navigatorKey.currentContext != null) {
    if (navigatorKey.currentWidget is LoginScreen ||
        navigatorKey.currentWidget is SignupScreen) {
      return;
    }
    Navigator.pushAndRemoveUntil(
      navigatorKey.currentContext!,
      MaterialPageRoute(builder: (context) => const AuthWrapper()),
      (route) => false,
    );
    var callInfo = await CallService().getCallInfo(data["content"]);
    if (callInfo != null) {
      Navigator.push(
        navigatorKey.currentContext!,
        MaterialPageRoute(
          builder: (context) => VideoCallScreen(callInfo: callInfo),
        ),
      );
    }
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
          importance: Importance.high,
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
          importance: Importance.low,
        ),
      );
}
