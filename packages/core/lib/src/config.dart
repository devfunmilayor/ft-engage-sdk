import 'exceptions.dart';

const sdkVersion = '0.12.0';
const maxBatchSize = 50;

class EngageConfig {
  EngageConfig({
    required this.publicKey,
    required this.endpoint,
    this.requireConsent = false,
    int batchSize = maxBatchSize,
    this.maxQueueSize = 1000,
    this.flushInterval,
    this.appVersion,
    this.appId,
  }) : batchSize = batchSize.clamp(1, maxBatchSize) {
    if (publicKey.startsWith('sk_')) {
      throw const EngageConfigException(
        'A secret key (sk_) must never be placed in an app. Use the public key (pk_).',
      );
    }
    if (!RegExp(r'^pk_(live|test)_[A-Za-z0-9_-]{20,}$').hasMatch(publicKey)) {
      throw const EngageConfigException(
        'publicKey must look like pk_live_... or pk_test_...',
      );
    }
    final id = appId;
    if (id != null && !RegExp(r'^[A-Za-z0-9._-]{1,150}$').hasMatch(id)) {
      throw const EngageConfigException(
        'appId may use letters, digits, dots, dashes and underscores (up to 150).',
      );
    }
    final local = const {'localhost', '127.0.0.1', '10.0.2.2'};
    if (endpoint.scheme != 'https' &&
        !(endpoint.scheme == 'http' && local.contains(endpoint.host))) {
      throw const EngageConfigException(
        'endpoint must be https (http is allowed only for localhost).',
      );
    }
  }

  final String publicKey;
  final Uri endpoint;
  final bool requireConsent;
  final int batchSize;
  final int maxQueueSize;
  final Duration? flushInterval;
  final String? appVersion;
  final String? appId;
}
