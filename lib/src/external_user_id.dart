/// An external user ID from a third-party identity module.
///
/// Used with [PrebidMobile.setExternalUserIds] to pass user identity
/// information to bidders for improved ad targeting and fill rates.
///
/// ## Supported Identity Modules
///
/// | Module | Source |
/// |---|---|
/// | UID2 | `"uidapi.com"` |
/// | SharedID | `"sharedid.org"` |
/// | LiveRamp | `"liveramp.com"` |
/// | Criteo | `"criteo.com"` |
/// | NetID | `"netid.de"` |
///
/// ## Example
///
/// ```dart
/// await PrebidMobile.setExternalUserIds([
///   ExternalUserId(source: 'uidapi.com', identifier: 'uid2-abc-123', atype: 3),
///   ExternalUserId(source: 'sharedid.org', identifier: 'shared-xyz', atype: 1),
/// ]);
/// ```
class ExternalUserId {
  /// The identity module source (e.g., `"uidapi.com"`).
  final String source;

  /// The user ID value from the identity module.
  final String identifier;

  /// The ID type per OpenRTB Extended Identifiers spec.
  ///
  /// Common values:
  /// - `1` — Device ID
  /// - `2` — Person (cross-device)
  /// - `3` — User (single device)
  final int? atype;

  /// Optional extra data to include with this user ID.
  final Map<String, dynamic>? ext;

  /// Creates an [ExternalUserId].
  const ExternalUserId({
    required this.source,
    required this.identifier,
    this.atype,
    this.ext,
  });
}
