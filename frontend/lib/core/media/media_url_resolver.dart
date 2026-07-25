import 'package:hellovietnam/core/config/env.dart';

class MediaUrlResolver {
  const MediaUrlResolver._();

  static String resolve(
    String rawValue, {
    String publicBaseUrl = Env.cloudflareMediaPublicBaseUrl,
  }) {
    String value = rawValue.trim();
    if (value.isEmpty) return '';

    for (int index = 0; index < 2 && value.contains('%'); index += 1) {
      try {
        value = Uri.decodeFull(value);
      } on FormatException {
        break;
      }
    }

    if (_isAbsolute(value) || value.startsWith('assets/')) {
      return value;
    }

    final String base = publicBaseUrl.trim().replaceFirst(RegExp(r'/+$'), '');
    final String key = value.replaceFirst(RegExp(r'^/+'), '');
    if (base.isEmpty || key.isEmpty) return value;

    final String encodedKey = key
        .split('/')
        .where((String segment) => segment.isNotEmpty)
        .map(Uri.encodeComponent)
        .join('/');
    return '$base/$encodedKey';
  }

  static bool isNetwork(String value) {
    final String normalized = value.trim().toLowerCase();
    return normalized.startsWith('http://') ||
        normalized.startsWith('https://') ||
        normalized.startsWith('blob:') ||
        normalized.startsWith('data:');
  }

  static bool _isAbsolute(String value) {
    final Uri? uri = Uri.tryParse(value);
    return uri != null && uri.hasScheme;
  }
}
