import 'dart:async';

import 'package:ft_engage_flutter/ft_engage_flutter.dart';

import 'messaging_gateway.dart';

const _minTokenLength = 20;

class FirebasePushSource implements PushSource, PushChanges, PushPermission {
  FirebasePushSource({MessagingGateway? gateway, String? vapidKey})
    : _gateway = gateway ?? FirebaseMessagingGateway(vapidKey: vapidKey);

  final MessagingGateway _gateway;

  @override
  Future<PushState> read() => _state(_gateway.permission);

  @override
  Future<PushState> request() => _state(_gateway.requestPermission);

  @override
  Stream<void> get changes => _gateway.tokenRefreshes.map((_) {});

  Future<PushState> _state(Future<GatewayPermission> Function() ask) async {
    final GatewayPermission permission;
    try {
      permission = await ask();
    } on Object {
      return PushState.unknown;
    }
    switch (permission) {
      case GatewayPermission.denied:
        return const PushState(status: 'denied');
      case GatewayPermission.notDetermined:
        return PushState.unknown;
      case GatewayPermission.granted:
        return PushState(status: 'granted', token: await _token());
    }
  }

  Future<String?> _token() async {
    try {
      final token = await _gateway.token();
      return token != null && token.length >= _minTokenLength ? token : null;
    } on Object {
      return null;
    }
  }
}
