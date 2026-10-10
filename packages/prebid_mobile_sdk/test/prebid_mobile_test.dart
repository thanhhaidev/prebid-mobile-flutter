import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:prebid_mobile_sdk/prebid_mobile_sdk.dart';
import 'package:prebid_mobile_sdk/src/generated/prebid_api.g.dart';

import 'mock_host_api.mocks.dart';
import 'platform_events.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockPrebidMobileHostApi api;

  setUp(() {
    api = MockPrebidMobileHostApi();
    PrebidMobile.api = api;
  });

  group('initializeSdk', () {
    void answer(String status, [String? error]) =>
        when(api.initializeSdk(any, any, any)).thenAnswer(
          (_) async => InitializationResult(status: status, error: error),
        );

    test('sends the server URL, account and non-tracking URL', () async {
      answer('succeeded');
      await PrebidMobile.initializeSdk(
        prebidServerUrl: 'https://pbs',
        accountId: 'acc',
        nonTrackingUrl: 'https://pbs-no-track',
      );
      verify(
        api.initializeSdk('https://pbs', 'acc', 'https://pbs-no-track'),
      ).called(1);
    });

    test('reports each status with its error', () async {
      final results = <(PrebidInitializationStatus, String?)>[];
      for (final (status, error) in [
        ('succeeded', null),
        ('serverStatusWarning', 'warn'),
        ('failed', 'down'),
        ('somethingNew', null),
      ]) {
        answer(status, error);
        await PrebidMobile.initializeSdk(
          prebidServerUrl: 'u',
          accountId: 'a',
          completion: (s, e) => results.add((s, e)),
        );
      }
      expect(results, [
        (PrebidInitializationStatus.succeeded, null),
        (PrebidInitializationStatus.serverStatusWarning, 'warn'),
        (PrebidInitializationStatus.failed, 'down'),
        (PrebidInitializationStatus.failed, null),
      ]);
    });

    test('isSdkInitialized is true after a success or a warning', () async {
      answer('failed', 'x');
      await PrebidMobile.initializeSdk(prebidServerUrl: 'u', accountId: 'a');
      expect(PrebidMobile.isSdkInitialized, isFalse);

      answer('serverStatusWarning');
      await PrebidMobile.initializeSdk(prebidServerUrl: 'u', accountId: 'a');
      expect(PrebidMobile.isSdkInitialized, isTrue);

      answer('succeeded');
      await PrebidMobile.initializeSdk(prebidServerUrl: 'u', accountId: 'a');
      expect(PrebidMobile.isSdkInitialized, isTrue);
    });
  });

  group('each setting reaches the platform', () {
    final settings = <String, (Future<void> Function(), void Function())>{
      'setTimeoutMillis': (
        () => PrebidMobile.setTimeoutMillis(5000),
        () => api.setTimeoutMillis(5000),
      ),
      'setShareGeoLocation': (
        () => PrebidMobile.setShareGeoLocation(true),
        () => api.setShareGeoLocation(true),
      ),
      'setPbsDebug': (
        () => PrebidMobile.setPbsDebug(true),
        () => api.setPbsDebug(true),
      ),
      'setCustomHeaders': (
        () => PrebidMobile.setCustomHeaders({'X-Test': 'v'}),
        () => api.setCustomHeaders({'X-Test': 'v'}),
      ),
      'setStoredAuctionResponse': (
        () => PrebidMobile.setStoredAuctionResponse('stored'),
        () => api.setStoredAuctionResponse('stored'),
      ),
      'clearStoredAuctionResponse': (
        PrebidMobile.clearStoredAuctionResponse,
        () => api.clearStoredAuctionResponse(),
      ),
      'addStoredBidResponse': (
        () => PrebidMobile.addStoredBidResponse('rubicon', 'resp'),
        () => api.addStoredBidResponse('rubicon', 'resp'),
      ),
      'clearStoredBidResponses': (
        PrebidMobile.clearStoredBidResponses,
        () => api.clearStoredBidResponses(),
      ),
      'setCreativeFactoryTimeout': (
        () => PrebidMobile.setCreativeFactoryTimeout(7000),
        () => api.setCreativeFactoryTimeout(7000),
      ),
      'setCreativeFactoryTimeoutPreRenderContent': (
        () => PrebidMobile.setCreativeFactoryTimeoutPreRenderContent(20000),
        () => api.setCreativeFactoryTimeoutPreRenderContent(20000),
      ),
      'setPrebidServerAccountId': (
        () => PrebidMobile.setPrebidServerAccountId('acct'),
        () => api.setPrebidServerAccountId('acct'),
      ),
      'setPrebidServerUrl': (
        () => PrebidMobile.setPrebidServerUrl('https://pbs'),
        () => api.setPrebidServerUrl('https://pbs'),
      ),
      'setUseCacheForReportingWithRenderingApi': (
        () => PrebidMobile.setUseCacheForReportingWithRenderingApi(true),
        () => api.setUseCacheForReportingWithRenderingApi(true),
      ),
      'setCustomStatusEndpoint': (
        () => PrebidMobile.setCustomStatusEndpoint('https://status'),
        () => api.setCustomStatusEndpoint('https://status'),
      ),
      'setShouldAssignNativeAssetId': (
        () => PrebidMobile.setShouldAssignNativeAssetId(true),
        () => api.setShouldAssignNativeAssetId(true),
      ),
      'setFilterOutUncachedBids': (
        () => PrebidMobile.setFilterOutUncachedBids(true),
        () => api.setFilterOutUncachedBids(true),
      ),
      'setIncludeWinners': (
        () => PrebidMobile.setIncludeWinners(true),
        () => api.setIncludeWinners(true),
      ),
      'setIncludeBidderKeys': (
        () => PrebidMobile.setIncludeBidderKeys(false),
        () => api.setIncludeBidderKeys(false),
      ),
      'setAuctionSettingsId': (
        () => PrebidMobile.setAuctionSettingsId('settings'),
        () => api.setAuctionSettingsId('settings'),
      ),
      'setAuctionSettingsId(null)': (
        () => PrebidMobile.setAuctionSettingsId(null),
        () => api.setAuctionSettingsId(null),
      ),
      'setDisableStatusCheck': (
        () => PrebidMobile.setDisableStatusCheck(true),
        () => api.setDisableStatusCheck(true),
      ),
      'setLocationUpdatesEnabled': (
        () => PrebidMobile.setLocationUpdatesEnabled(false),
        () => api.setLocationUpdatesEnabled(false),
      ),
      'setDebugLogFileEnabled': (
        () => PrebidMobile.setDebugLogFileEnabled(true),
        () => api.setDebugLogFileEnabled(true),
      ),
      'setSendSharedId': (
        () => PrebidMobile.setSendSharedId(true),
        () => api.setSendSharedId(true),
      ),
      'resetSharedId': (PrebidMobile.resetSharedId, () => api.resetSharedId()),
      'clearExternalUserIds': (
        PrebidMobile.clearExternalUserIds,
        () => api.clearExternalUserIds(),
      ),
    };
    for (final MapEntry(key: name, value: (set, expected))
        in settings.entries) {
      test(name, () async {
        await set();
        verify(expected()).called(1);
      });
    }

    test('log levels travel as their native index', () async {
      for (final (level, wire) in [
        (PrebidLogLevel.debug, 0),
        (PrebidLogLevel.verbose, 1),
        (PrebidLogLevel.info, 2),
        (PrebidLogLevel.warn, 3),
        (PrebidLogLevel.error, 4),
        (PrebidLogLevel.severe, 5),
        (PrebidLogLevel.none, 6),
      ]) {
        await PrebidMobile.setLogLevel(level);
        verify(api.setLogLevel(wire)).called(1);
      }
    });

    test('eids placements travel by name', () async {
      for (final (placement, wire) in [
        (PrebidEidsPlacement.openRtb26, 'openRtb26'),
        (PrebidEidsPlacement.openRtb25, 'openRtb25'),
        (PrebidEidsPlacement.compatible, 'compatible'),
      ]) {
        await PrebidMobile.setEidsPlacement(placement);
        verify(api.setEidsPlacement(wire)).called(1);
      }
    });

    test('an invalid server URL surfaces the platform error', () {
      when(
        api.setPrebidServerUrl(any),
      ).thenThrow(PlatformException(code: 'prebidServerURLInvalid'));
      expect(
        () => PrebidMobile.setPrebidServerUrl('not a url'),
        throwsA(isA<PlatformException>()),
      );
    });
  });

  group('each getter returns the platform value', () {
    final getters =
        <String, (void Function(), Future<Object?> Function(), Object?)>{
          'getTimeoutMillis': (
            () => when(api.getTimeoutMillis()).thenAnswer((_) async => 3000),
            PrebidMobile.getTimeoutMillis,
            3000,
          ),
          'getTimeoutMillisDynamic': (
            () => when(
              api.getTimeoutMillisDynamic(),
            ).thenAnswer((_) async => 1800),
            PrebidMobile.getTimeoutMillisDynamic,
            1800,
          ),
          'getPbsDebug': (
            () => when(api.getPbsDebug()).thenAnswer((_) async => true),
            PrebidMobile.getPbsDebug,
            true,
          ),
          'getShareGeoLocation': (
            () => when(api.getShareGeoLocation()).thenAnswer((_) async => true),
            PrebidMobile.getShareGeoLocation,
            true,
          ),
          'getCustomHeaders': (
            () => when(
              api.getCustomHeaders(),
            ).thenAnswer((_) async => {'X-Test': 'v'}),
            PrebidMobile.getCustomHeaders,
            {'X-Test': 'v'},
          ),
          'getStoredAuctionResponse': (
            () => when(
              api.getStoredAuctionResponse(),
            ).thenAnswer((_) async => 'stored'),
            PrebidMobile.getStoredAuctionResponse,
            'stored',
          ),
          'getStoredBidResponses': (
            () => when(
              api.getStoredBidResponses(),
            ).thenAnswer((_) async => {'rubicon': 'resp'}),
            PrebidMobile.getStoredBidResponses,
            {'rubicon': 'resp'},
          ),
          'getCustomStatusEndpoint': (
            () => when(
              api.getCustomStatusEndpoint(),
            ).thenAnswer((_) async => 'https://status'),
            PrebidMobile.getCustomStatusEndpoint,
            'https://status',
          ),
          'getShouldAssignNativeAssetId': (
            () => when(
              api.getShouldAssignNativeAssetId(),
            ).thenAnswer((_) async => true),
            PrebidMobile.getShouldAssignNativeAssetId,
            true,
          ),
          'getFilterOutUncachedBids': (
            () => when(
              api.getFilterOutUncachedBids(),
            ).thenAnswer((_) async => true),
            PrebidMobile.getFilterOutUncachedBids,
            true,
          ),
          'getIncludeWinners': (
            () => when(api.getIncludeWinners()).thenAnswer((_) async => true),
            PrebidMobile.getIncludeWinners,
            true,
          ),
          'getIncludeBidderKeys': (
            () =>
                when(api.getIncludeBidderKeys()).thenAnswer((_) async => false),
            PrebidMobile.getIncludeBidderKeys,
            false,
          ),
          'getAuctionSettingsId': (
            () => when(
              api.getAuctionSettingsId(),
            ).thenAnswer((_) async => 'settings'),
            PrebidMobile.getAuctionSettingsId,
            'settings',
          ),
          'getDisableStatusCheck': (
            () =>
                when(api.getDisableStatusCheck()).thenAnswer((_) async => true),
            PrebidMobile.getDisableStatusCheck,
            true,
          ),
          'getCreativeFactoryTimeout (ms)': (
            () => when(
              api.getCreativeFactoryTimeout(),
            ).thenAnswer((_) async => 6000),
            PrebidMobile.getCreativeFactoryTimeout,
            6000,
          ),
          'getCreativeFactoryTimeoutPreRenderContent (ms)': (
            () => when(
              api.getCreativeFactoryTimeoutPreRenderContent(),
            ).thenAnswer((_) async => 30000),
            PrebidMobile.getCreativeFactoryTimeoutPreRenderContent,
            30000,
          ),
          'getPrebidServerAccountId': (
            () => when(
              api.getPrebidServerAccountId(),
            ).thenAnswer((_) async => 'acct'),
            PrebidMobile.getPrebidServerAccountId,
            'acct',
          ),
          'getPrebidServerUrl': (
            () => when(
              api.getPrebidServerUrl(),
            ).thenAnswer((_) async => 'https://pbs'),
            PrebidMobile.getPrebidServerUrl,
            'https://pbs',
          ),
          'getPrebidServerUrl, unset': (
            () => when(api.getPrebidServerUrl()).thenAnswer((_) async => null),
            PrebidMobile.getPrebidServerUrl,
            null,
          ),
          'getUseCacheForReportingWithRenderingApi': (
            () => when(
              api.getUseCacheForReportingWithRenderingApi(),
            ).thenAnswer((_) async => true),
            PrebidMobile.getUseCacheForReportingWithRenderingApi,
            true,
          ),
          'getLocationUpdatesEnabled': (
            () => when(
              api.getLocationUpdatesEnabled(),
            ).thenAnswer((_) async => false),
            PrebidMobile.getLocationUpdatesEnabled,
            false,
          ),
          'getDebugLogFileEnabled (Android: null)': (
            () => when(
              api.getDebugLogFileEnabled(),
            ).thenAnswer((_) async => null),
            PrebidMobile.getDebugLogFileEnabled,
            null,
          ),
          'getSdkVersion': (
            () => when(api.getSdkVersion()).thenAnswer((_) async => '3.4.0'),
            PrebidMobile.getSdkVersion,
            '3.4.0',
          ),
          'getOmsdkVersion': (
            () => when(api.getOmsdkVersion()).thenAnswer((_) async => '1.4.1'),
            PrebidMobile.getOmsdkVersion,
            '1.4.1',
          ),
        };
    for (final MapEntry(key: name, value: (stub, get, expected))
        in getters.entries) {
      test(name, () async {
        stub();
        expect(await get(), expected);
      });
    }

    test('getEidsPlacement maps the name, compatible when unknown', () async {
      when(api.getEidsPlacement()).thenAnswer((_) async => 'openRtb26');
      expect(
        await PrebidMobile.getEidsPlacement(),
        PrebidEidsPlacement.openRtb26,
      );
      when(api.getEidsPlacement()).thenAnswer((_) async => 'future');
      expect(
        await PrebidMobile.getEidsPlacement(),
        PrebidEidsPlacement.compatible,
      );
    });
  });

  group('external user IDs', () {
    List<ExternalUserIdData> sent() =>
        verify(api.setExternalUserIds(captureAny)).captured.single
            as List<ExternalUserIdData>;

    test('one ID becomes one eid entry with every field', () async {
      await PrebidMobile.setExternalUserIds([
        ExternalUserId(
          source: 'uidapi.com',
          identifier: 'uid2',
          atype: 3,
          ext: {'k': 1},
          inserter: 'inserter.com',
          matcher: 'matcher.com',
          mm: 3,
        ),
      ]);
      final eid = sent().single;
      expect(eid.source, 'uidapi.com');
      expect(eid.uids.map((u) => (u!.id, u.atype, u.ext)), [('uid2', 3, null)]);
      expect(eid.ext, {'k': 1});
      expect(eid.inserter, 'inserter.com');
      expect(eid.matcher, 'matcher.com');
      expect(eid.mm, 3);
    });

    test('several IDs from one source make one eid entry', () async {
      await PrebidMobile.setExternalUserIds([
        ExternalUserId.withUids(
          source: 'adserver.org',
          uids: const [
            UserUniqueId(id: 'a', atype: 1, ext: {'rtiPartner': 'TDID'}),
            UserUniqueId(id: 'b', atype: 3),
          ],
          ext: const {'stype': 'ppuid'},
        ),
      ]);
      final eid = sent().single;
      expect(eid.source, 'adserver.org');
      expect(eid.ext, {'stype': 'ppuid'});
      expect(eid.uids.map((u) => (u!.id, u.atype)), [('a', 1), ('b', 3)]);
      expect(eid.uids.map((u) => u!.ext), [
        {'rtiPartner': 'TDID'},
        null,
      ]);
    });

    test('the platform IDs are read back, with every field', () async {
      when(api.getExternalUserIds()).thenAnswer(
        (_) async => [
          ExternalUserIdData(
            source: 's',
            uids: [
              UserUniqueIdData(id: 'i', atype: 2, ext: {'u': 2}),
            ],
            ext: {'k': 1, null: 'x'},
            inserter: 'ins',
            matcher: 'mat',
            mm: 1,
          ),
        ],
      );
      final id = (await PrebidMobile.getExternalUserIds()).single;
      expect(id.source, 's');
      expect(id.identifier, 'i');
      expect(id.atype, 2);
      expect(id.uids.single.ext, {'u': 2});
      expect(id.ext, {'k': 1, '': 'x'});
      expect((id.inserter, id.matcher, id.mm), ('ins', 'mat', 1));
    });

    test('an eid entry without IDs is dropped', () async {
      when(api.getExternalUserIds()).thenAnswer(
        (_) async => [
          ExternalUserIdData(source: 's', uids: [null]),
        ],
      );
      expect(await PrebidMobile.getExternalUserIds(), isEmpty);
    });

    test('the SharedID is read back, null when unset', () async {
      when(api.getSharedId()).thenAnswer(
        (_) async => ExternalUserIdData(
          source: 'pubcid.org',
          uids: [UserUniqueIdData(id: 'abc', atype: 1)],
        ),
      );
      final id = await PrebidMobile.getSharedId();
      expect((id?.source, id?.identifier, id?.atype), ('pubcid.org', 'abc', 1));

      when(api.getSharedId()).thenAnswer((_) async => null);
      expect(await PrebidMobile.getSharedId(), isNull);
    });
  });

  group('listeners', () {
    test('the event listener receives bid request / response pairs', () async {
      final received = <(String?, String?)>[];
      await PrebidMobile.setEventListener(
        (req, res) => received.add((req, res)),
      );
      verify(api.setEventDelegateEnabled(true)).called(1);

      await sendBidResponse('{"id":"req"}', '{"id":"res"}');
      expect(received, [('{"id":"req"}', '{"id":"res"}')]);

      await PrebidMobile.setEventListener(null);
      verify(api.setEventDelegateEnabled(false)).called(1);
    });

    test('the log listener receives known levels until removed', () async {
      final logs = <(PrebidLogLevel, String)>[];
      await PrebidMobile.setLogListener((l, m) => logs.add((l, m)));
      verify(api.setLogListenerEnabled(true)).called(1);

      await sendLog(4, 'boom');
      await sendLog(99, 'unknown level');
      expect(logs, [(PrebidLogLevel.error, 'boom')]);

      await PrebidMobile.setLogListener(null);
      verify(api.setLogListenerEnabled(false)).called(1);
      await sendLog(2, 'after');
      expect(logs, hasLength(1));
    });
  });
}
