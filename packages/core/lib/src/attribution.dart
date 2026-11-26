class AttributionResult {
  const AttributionResult({
    required this.attributed,
    this.source,
    this.medium,
    this.campaign,
    this.method,
    this.deepLink,
    this.retry = false,
  });

  factory AttributionResult.fromJson(Map<String, dynamic> json) =>
      AttributionResult(
        attributed: json['attributed'] == true,
        source: json['source'] as String?,
        medium: json['medium'] as String?,
        campaign: json['campaign'] as String?,
        method: json['method'] as String?,
        deepLink: json['deepLink'] as String?,
        retry: json['retry'] == true,
      );

  final bool attributed;
  final String? source;
  final String? medium;
  final String? campaign;
  final String? method;
  final String? deepLink;
  final bool retry;

  Map<String, Object?> toJson() => {
    'attributed': attributed,
    'source': source,
    'medium': medium,
    'campaign': campaign,
    'method': method,
    'deepLink': deepLink,
  };
}
