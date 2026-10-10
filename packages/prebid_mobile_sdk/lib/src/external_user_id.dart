/// An external user ID from a third-party identity module: one OpenRTB
/// `user.eids` entry.
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
///   // Several IDs from one source go in one entry:
///   ExternalUserId.withUids(
///     source: 'adserver.org',
///     uids: [
///       UserUniqueId(id: 'tdid-1', atype: 1, ext: {'rtiPartner': 'TDID'}),
///       UserUniqueId(id: 'tdid-2', atype: 3),
///     ],
///   ),
/// ]);
/// ```
class ExternalUserId {
  /// Creates an entry with a single ID from [source].
  ExternalUserId({
    required String source,
    required String identifier,
    required int atype,
    Map<String, Object?>? ext,
    String? inserter,
    String? matcher,
    int? mm,
  }) : this.withUids(
         source: source,
         uids: [UserUniqueId(id: identifier, atype: atype)],
         ext: ext,
         inserter: inserter,
         matcher: matcher,
         mm: mm,
       );

  /// Creates an entry with every ID in [uids] from [source].
  ExternalUserId.withUids({
    required this.source,
    required List<UserUniqueId> uids,
    this.ext,
    this.inserter,
    this.matcher,
    this.mm,
  }) : assert(uids.isNotEmpty, 'An external user ID needs at least one uid'),
       uids = List.unmodifiable(uids);

  /// The identity module source (e.g., `"uidapi.com"`).
  final String source;

  /// The IDs from [source]; never empty.
  final List<UserUniqueId> uids;

  /// The entry's `ext` (`user.eids[].ext`). Vendor data for a single ID
  /// goes in [UserUniqueId.ext].
  final Map<String, Object?>? ext;

  /// OpenRTB 2.6 EID `inserter`: the canonical domain of the entity that
  /// inserted the ID into the request.
  final String? inserter;

  /// OpenRTB 2.6 EID `matcher`: the canonical domain of the entity that
  /// matched (resolved) the ID.
  final String? matcher;

  /// OpenRTB 2.6 EID `mm`: match method (e.g. `1` = no match, `2` = browser
  /// cookie sync, `3` = authenticated, …).
  final int? mm;

  /// The value of the first ID in [uids].
  String get identifier => uids.first.id;

  /// The type of the first ID in [uids].
  int get atype => uids.first.atype;
}

/// One ID of an [ExternalUserId] (`user.eids[].uids[]`).
class UserUniqueId {
  /// Creates a [UserUniqueId].
  const UserUniqueId({required this.id, required this.atype, this.ext});

  /// The user ID value from the identity module.
  final String id;

  /// The ID type per the OpenRTB Extended Identifiers spec.
  ///
  /// Common values:
  /// - `1` — Device ID
  /// - `2` — Person (cross-device)
  /// - `3` — User (single device)
  final int atype;

  /// Vendor-specific extensions for this ID.
  final Map<String, Object?>? ext;
}
