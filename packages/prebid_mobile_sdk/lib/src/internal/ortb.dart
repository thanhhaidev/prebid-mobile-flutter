import 'dart:convert';

/// [impOrtbConfig] with `ext.gpid` set to [gpid] (unless it already sets
/// one), for ad units without a GPID setter. Unchanged without a [gpid] or
/// when [impOrtbConfig] is not a JSON object.
String? impOrtbWithGpid(String? impOrtbConfig, String? gpid) {
  if (gpid == null) return impOrtbConfig;
  final Object? decoded;
  try {
    decoded = impOrtbConfig == null ? const {} : jsonDecode(impOrtbConfig);
  } on FormatException {
    return impOrtbConfig;
  }
  if (decoded is! Map) return impOrtbConfig;
  final ext = decoded['ext'];
  return jsonEncode({
    ...decoded,
    'ext': {'gpid': gpid, if (ext is Map) ...ext},
  });
}
