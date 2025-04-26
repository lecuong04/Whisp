import 'dart:async';
import 'dart:ui';
import 'package:flutter_background_service/flutter_background_service.dart';

const notificationChannelId = 'WhispChannel';

const notificationId = 1975;

@pragma('vm:entry-point')
void onStart(ServiceInstance service) async {
  DartPluginRegistrant.ensureInitialized();

  service.on('stopService').listen((event) {
    service.stopSelf();
  });
  if (service is AndroidServiceInstance &&
      !(await service.isForegroundService())) {
    service.setAsForegroundService();
  }
}

Future<void> startBackgroundService() async {
  final service = FlutterBackgroundService();
  // const AndroidNotificationChannel channel = AndroidNotificationChannel(
  //   notificationChannelId, // id
  //   'Whisp', // title
  //   description: 'This channel is used for important notifications.',
  //   importance:
  //       Importance
  //           .defaultImportance, // importance must be at low or higher level
  // );
  // final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
  //     FlutterLocalNotificationsPlugin();
  // await flutterLocalNotificationsPlugin
  //     .resolvePlatformSpecificImplementation<
  //       AndroidFlutterLocalNotificationsPlugin
  //     >()
  //     ?.createNotificationChannel(channel);
  await service.configure(
    androidConfiguration: AndroidConfiguration(
      onStart: onStart,
      autoStart: false, // we'll start manually after login
      isForegroundMode: true,
      notificationChannelId: notificationChannelId,
      initialNotificationTitle: 'Listening for messages',
      initialNotificationContent: 'Service is running...',
      foregroundServiceNotificationId: notificationId,
      foregroundServiceTypes: [AndroidForegroundType.dataSync],
    ),
    iosConfiguration: IosConfiguration(), // Optional for iOS
  );
  service.startService();
}
