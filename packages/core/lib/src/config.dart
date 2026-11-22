import 'exceptions.dart';

const sdkVersion = '0.1.0';
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
}
