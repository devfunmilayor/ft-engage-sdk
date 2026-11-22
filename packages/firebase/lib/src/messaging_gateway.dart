import 'package:firebase_messaging/firebase_messaging.dart';

enum GatewayPermission { granted, denied, notDetermined }

abstract interface class MessagingGateway {
  Future<GatewayPermission> permission();

  Future<GatewayPermission> requestPermission();

  Future<String?> token();

  Stream<String> get tokenRefreshes;
}

GatewayPermission mapAuthorization(AuthorizationStatus status) =>
    switch (status) {
      AuthorizationStatus.authorized ||
      AuthorizationStatus.provisional => GatewayPermission.granted,
      AuthorizationStatus.denied ||
      AuthorizationStatus.deniedPermanently => GatewayPermission.denied,
      AuthorizationStatus.notDetermined => GatewayPermission.notDetermined,
    };

class FirebaseMessagingGateway implements MessagingGateway {
  FirebaseMessagingGateway({FirebaseMessaging? messaging, this.vapidKey})
    : _messaging = messaging;

  final FirebaseMessaging? _messaging;
  final String? vapidKey;

  FirebaseMessaging get _m => _messaging ?? FirebaseMessaging.instance;

  @override
  Future<GatewayPermission> permission() async => mapAuthorization(
    (await _m.getNotificationSettings()).authorizationStatus,
  );

  @override
  Future<GatewayPermission> requestPermission() async =>
      mapAuthorization((await _m.requestPermission()).authorizationStatus);

  @override
  Future<String?> token() => _m.getToken(vapidKey: vapidKey);

  @override
  Stream<String> get tokenRefreshes => _m.onTokenRefresh;
}
