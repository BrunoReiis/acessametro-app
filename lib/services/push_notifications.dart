import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

abstract interface class PushTokenProvider {
  Future<String?> initialize({
    required void Function(String token) onTokenRefresh,
  });

  Future<void> dispose();
}

class FirebasePushTokenProvider implements PushTokenProvider {
  FirebasePushTokenProvider({
    FirebaseMessaging? messaging,
    FlutterLocalNotificationsPlugin? localNotifications,
  }) : _messaging = messaging,
       _localNotifications =
           localNotifications ?? FlutterLocalNotificationsPlugin();

  static const _projectId = String.fromEnvironment('FIREBASE_PROJECT_ID');
  static const _apiKey = String.fromEnvironment('FIREBASE_API_KEY');
  static const _senderId = String.fromEnvironment(
    'FIREBASE_MESSAGING_SENDER_ID',
  );
  static const _androidAppId = String.fromEnvironment(
    'FIREBASE_ANDROID_APP_ID',
  );
  static const _iosAppId = String.fromEnvironment('FIREBASE_IOS_APP_ID');
  static const _iosBundleId = String.fromEnvironment('FIREBASE_IOS_BUNDLE_ID');
  static const _storageBucket = String.fromEnvironment(
    'FIREBASE_STORAGE_BUCKET',
  );

  FirebaseMessaging? _messaging;
  FirebaseMessaging get _firebaseMessaging =>
      _messaging ??= FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications;
  StreamSubscription<String>? _tokenSubscription;
  StreamSubscription<RemoteMessage>? _messageSubscription;
  bool _initialized = false;

  @override
  Future<String?> initialize({
    required void Function(String token) onTokenRefresh,
  }) async {
    if (kIsWeb ||
        (defaultTargetPlatform != TargetPlatform.android &&
            defaultTargetPlatform != TargetPlatform.iOS)) {
      return null;
    }

    final options = _firebaseOptions;
    if (options == null) {
      debugPrint(
        'Push notifications disabled: Firebase compile-time settings are missing.',
      );
      return null;
    }

    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(options: options);
    }

    final settings = await _firebaseMessaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    if (settings.authorizationStatus != AuthorizationStatus.authorized &&
        settings.authorizationStatus != AuthorizationStatus.provisional) {
      return null;
    }

    await _initializeLocalNotifications();
    if (!_initialized) {
      // The Admin SDK needs FCM registration tokens, rather than Firebase FIDs.
      // ignore: deprecated_member_use
      _tokenSubscription = _firebaseMessaging.onTokenRefresh.listen(
        onTokenRefresh,
        onError: (Object error) =>
            debugPrint('FCM token refresh failed: $error'),
      );
      _messageSubscription = FirebaseMessaging.onMessage.listen(
        _showForegroundNotification,
        onError: (Object error) =>
            debugPrint('Foreground push handling failed: $error'),
      );
      _initialized = true;
    }

    // ignore: deprecated_member_use
    return _firebaseMessaging.getToken();
  }

  @override
  Future<void> dispose() async {
    await _tokenSubscription?.cancel();
    await _messageSubscription?.cancel();
    _tokenSubscription = null;
    _messageSubscription = null;
    _initialized = false;
  }

  FirebaseOptions? get _firebaseOptions {
    final appId = switch (defaultTargetPlatform) {
      TargetPlatform.android => _androidAppId,
      TargetPlatform.iOS => _iosAppId,
      _ => '',
    };
    if (_projectId.isEmpty ||
        _apiKey.isEmpty ||
        _senderId.isEmpty ||
        appId.isEmpty) {
      return null;
    }
    return FirebaseOptions(
      apiKey: _apiKey,
      appId: appId,
      messagingSenderId: _senderId,
      projectId: _projectId,
      storageBucket: _storageBucket.isEmpty ? null : _storageBucket,
      iosBundleId:
          defaultTargetPlatform == TargetPlatform.iOS && _iosBundleId.isNotEmpty
          ? _iosBundleId
          : null,
    );
  }

  Future<void> _initializeLocalNotifications() async {
    await _localNotifications.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
      ),
    );
  }

  Future<void> _showForegroundNotification(RemoteMessage message) async {
    final notification = message.notification;
    if (notification == null) return;
    await _localNotifications.show(
      id: message.messageId.hashCode,
      title: notification.title,
      body: notification.body,
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          'accessibility_issues',
          'Problemas de acessibilidade',
          channelDescription:
              'Avisos sobre problemas ativos nas estações favoritas.',
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(presentAlert: true, presentSound: true),
      ),
    );
  }
}
