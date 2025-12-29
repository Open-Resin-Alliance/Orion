class NanoManualResult {
  NanoManualResult({required this.ok, this.message});

  final bool ok;
  final String? message;

  Map<String, dynamic> toMap() => {
        'ok': ok,
        if (message != null) 'message': message,
      };

  @override
  String toString() => 'NanoManualResult(ok: $ok, message: $message)';

  static NanoManualResult fromDynamic(dynamic src) {
    if (src == null) return NanoManualResult(ok: true);
    if (src is NanoManualResult) return src;
    if (src is Map<String, dynamic>) {
      final m = src;
      final ok = m['ok'] is bool ? m['ok'] as bool : (m['result'] == 'ok');
      final message = m['message']?.toString();
      return NanoManualResult(ok: ok, message: message);
    }
    if (src is String) {
      // Some NanoDLP endpoints return plain text
      final s = src.trim();
      if (s.isEmpty) return NanoManualResult(ok: true);
      return NanoManualResult(ok: true, message: s);
    }
    if (src is bool) return NanoManualResult(ok: src);
    return NanoManualResult(ok: true);
  }
}
