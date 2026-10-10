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

/// The plugin's name in the `app.ext.prebid.wrapper` record of every bid
/// request.
const pluginName = 'prebid_mobile_sdk';

/// The plugin's version in that record; a test keeps it equal to the
/// pubspec version.
const pluginVersion = '1.0.0';

/// [globalOrtbConfig] with the plugin's `app.ext.prebid.wrapper` record (its
/// name and version), so Prebid Server hosts and bidders can tell plugin
/// traffic from native app traffic. The native SDK's `app.ext.prebid.source`
/// and `version` are left alone: both SDKs deep-merge the global config into
/// the request they build. Unchanged when [globalOrtbConfig] is not a JSON
/// object.
String? withWrapperRecord(String? globalOrtbConfig) {
  final root = _jsonObject(globalOrtbConfig ?? '{}');
  if (root == null) return globalOrtbConfig;
  final prebid = _child(_child(_child(root, 'app'), 'ext'), 'prebid');
  prebid['wrapper'] = const {'name': pluginName, 'version': pluginVersion};
  return jsonEncode(root);
}

/// [globalOrtbConfig] without the record [withWrapperRecord] adds, nor the
/// objects left empty without it: the app's own config, or `null` when it set
/// none.
String? withoutWrapperRecord(String? globalOrtbConfig) {
  if (globalOrtbConfig == null) return null;
  final root = _jsonObject(globalOrtbConfig);
  if (root case {
    'app':
        final Map<String, Object?> app &&
        {
          'ext':
              final Map<String, Object?> ext &&
              {'prebid': final Map<String, Object?> prebid},
        },
  } when prebid.containsKey('wrapper')) {
    prebid.remove('wrapper');
    if (prebid.isEmpty) ext.remove('prebid');
    if (ext.isEmpty) app.remove('ext');
    if (app.isEmpty) root.remove('app');
    return root.isEmpty ? null : jsonEncode(root);
  }
  return globalOrtbConfig;
}

Map<String, Object?>? _jsonObject(String json) {
  try {
    final decoded = jsonDecode(json);
    return decoded is Map<String, Object?> ? decoded : null;
  } on FormatException {
    return null;
  }
}

/// [parent]'s object at [key], created (or replacing a non-object) if needed.
Map<String, Object?> _child(Map<String, Object?> parent, String key) {
  final value = parent[key];
  if (value is Map<String, Object?>) return value;
  return parent[key] = <String, Object?>{};
}
