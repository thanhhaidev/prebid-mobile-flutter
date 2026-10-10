import 'dart:collection';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:prebid_mobile_sdk/prebid_mobile_sdk.dart';

/// One Prebid Server round trip captured through `PrebidEventDelegate`
/// ([PrebidMobile.setEventListener]).
class BidRecord {
  BidRecord({required this.time, this.request, this.response});
  final DateTime time;
  final String? request;
  final String? response;

  late final Map<String, dynamic>? requestJson = _decode(request);
  late final Map<String, dynamic>? responseJson = _decode(response);

  /// Stored-request (config) ids of the request's impressions.
  List<String> get configIds {
    final imps = requestJson?['imp'];
    if (imps is! List) return const [];
    return [
      for (final imp in imps)
        if (imp is Map)
          switch (imp) {
            {'ext': {'prebid': {'storedrequest': {'id': final Object id}}}} =>
              '$id',
            _ => '?',
          },
    ];
  }

  /// Formats requested by the first impression (banner / video / native).
  List<String> get formats {
    final imps = requestJson?['imp'];
    if (imps is! List || imps.isEmpty || imps.first is! Map) return const [];
    final imp = imps.first as Map;
    return [
      for (final f in const ['banner', 'video', 'native'])
        if (imp.containsKey(f)) f,
    ];
  }

  /// Bids in the response as `(bidder, price)`.
  List<(String, num?)> get bids {
    final seatbids = responseJson?['seatbid'];
    if (seatbids is! List) return const [];
    return [
      for (final seat in seatbids)
        if (seat is Map && seat['bid'] is List)
          for (final bid in seat['bid'] as List)
            if (bid is Map)
              (seat['seat']?.toString() ?? '?', bid['price'] as num?),
    ];
  }

  /// `true` when no response body came back (timeout / network error).
  bool get failed => response == null || response!.isEmpty;

  static Map<String, dynamic>? _decode(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    try {
      final v = jsonDecode(raw);
      return v is Map<String, dynamic> ? v : null;
    } catch (_) {
      return null;
    }
  }

  /// Pretty-printed JSON, or the raw text when it isn't JSON.
  static String pretty(String? raw) {
    if (raw == null || raw.isEmpty) return '(empty)';
    try {
      return const JsonEncoder.withIndent('  ').convert(jsonDecode(raw));
    } catch (_) {
      return raw;
    }
  }
}

/// App-wide store of captured bid requests / responses, fed by
/// [PrebidMobile.setEventListener]. Keeps the most recent [capacity] records.
class BidInspector extends ChangeNotifier {
  BidInspector._();

  static final BidInspector instance = BidInspector._();

  static const capacity = 50;

  final List<BidRecord> _records = [];
  bool _enabled = false;

  /// Newest first.
  UnmodifiableListView<BidRecord> get records =>
      UnmodifiableListView(_records.reversed);

  bool get enabled => _enabled;

  BidRecord? get latest => _records.isEmpty ? null : _records.last;

  Future<void> setEnabled(bool enabled) async {
    _enabled = enabled;
    await PrebidMobile.setEventListener(enabled ? _onBid : null);
    notifyListeners();
  }

  void _onBid(String? request, String? response) {
    _records.add(
      BidRecord(time: DateTime.now(), request: request, response: response),
    );
    if (_records.length > capacity) _records.removeAt(0);
    notifyListeners();
  }

  void clear() {
    _records.clear();
    notifyListeners();
  }
}
