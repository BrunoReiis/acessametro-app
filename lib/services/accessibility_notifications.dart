import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

const _accessibilityCategories = {'ACCESSIBILITY', 'ELEVATOR', 'ESCALATOR'};

List<Map<String, dynamic>> activeAccessibilityIncidents(
  Iterable<Map<String, dynamic>> incidents,
) => incidents.where((incident) {
  final category = incident['category'];
  final status = incident['status'];
  return _accessibilityCategories.contains(category) &&
      (status == 'PENDING' || status == 'IN_PROGRESS');
}).toList();

abstract interface class AccessibilityNotificationService {
  Future<bool> notifyStationIssues({
    required String stationId,
    required String stationName,
    required List<Map<String, dynamic>> incidents,
  });
}

class LocalAccessibilityNotificationService
    implements AccessibilityNotificationService {
  LocalAccessibilityNotificationService({
    FlutterLocalNotificationsPlugin? plugin,
  }) : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  final FlutterLocalNotificationsPlugin _plugin;
  bool _initialized = false;

  @override
  Future<bool> notifyStationIssues({
    required String stationId,
    required String stationName,
    required List<Map<String, dynamic>> incidents,
  }) async {
    final activeIncidents = activeAccessibilityIncidents(incidents);
    if (activeIncidents.isEmpty) return false;

    await _initialize();
    final permissionGranted = await _requestPermission();
    if (!permissionGranted) return false;

    final firstIncident = activeIncidents.first;
    final category = switch (firstIncident['category']) {
      'ELEVATOR' => 'Elevador',
      'ESCALATOR' => 'Escada rolante',
      _ => 'Acessibilidade',
    };
    final title = '$category com problema em $stationName';
    final issueTitle = firstIncident['title'] as String? ?? category;
    final remainingCount = activeIncidents.length - 1;
    final body = remainingCount == 0
        ? issueTitle
        : '$issueTitle e mais $remainingCount problema(s) ativo(s).';

    await _plugin.show(
      id: stationId.hashCode,
      title: title,
      body: body,
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
    return true;
  }

  Future<void> _initialize() async {
    if (_initialized) return;
    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
      ),
    );
    _initialized = true;
  }

  Future<bool> _requestPermission() async {
    if (kIsWeb) return false;
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return await _plugin
                .resolvePlatformSpecificImplementation<
                  AndroidFlutterLocalNotificationsPlugin
                >()
                ?.requestNotificationsPermission() ??
            false;
      case TargetPlatform.iOS:
        return await _plugin
                .resolvePlatformSpecificImplementation<
                  IOSFlutterLocalNotificationsPlugin
                >()
                ?.requestPermissions(alert: true, sound: true) ??
            false;
      default:
        return false;
    }
  }
}
