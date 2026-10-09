// A minimal pub repository (hosted API v2) for scoring packages with pana
// before their dependencies are on pub.dev.
//
// Serves the given packages from local tarballs and proxies every other
// request to pub.dev, so a companion's `prebid_mobile_sdk: ^1.0.0` resolves to
// the core package as it is in this checkout. Used by tool/score.sh.
//
//   dart run tool/fake_pub_server.dart <port> <package dir>=<tarball> ...
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:yaml/yaml.dart';

const _upstream = 'https://pub.dev';

class _LocalPackage {
  _LocalPackage(this.pubspec, this.archive);

  final Map<String, Object?> pubspec;
  final List<int> archive;

  String get name => pubspec['name']! as String;
  String get version => pubspec['version']! as String;
}

Future<void> main(List<String> args) async {
  final port = int.parse(args.first);
  final packages = <String, _LocalPackage>{};
  for (final spec in args.skip(1)) {
    final [dir, tarball] = spec.split('=');
    final yaml = loadYaml(File('$dir/pubspec.yaml').readAsStringSync());
    // Round-trip through JSON to turn YamlMaps into plain maps.
    final pubspec = jsonDecode(jsonEncode(yaml)) as Map<String, Object?>;
    final package = _LocalPackage(pubspec, File(tarball).readAsBytesSync());
    packages[package.name] = package;
  }

  final client = HttpClient();
  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, port);
  stdout.writeln(
    'fake pub server on http://localhost:$port '
    '(${packages.values.map((p) => '${p.name} ${p.version}').join(', ')})',
  );

  await for (final request in server) {
    final segments = request.uri.pathSegments;
    final response = request.response;
    try {
      // GET /api/packages/<name>[/advisories]
      if (segments.length >= 3 &&
          segments[0] == 'api' &&
          segments[1] == 'packages' &&
          packages.containsKey(segments[2])) {
        final package = packages[segments[2]]!;
        final Object body;
        if (segments.length == 4 && segments[3] == 'advisories') {
          body = {'advisories': <Object>[]};
        } else {
          final version = {
            'version': package.version,
            'pubspec': package.pubspec,
            'archive_url':
                'http://localhost:$port/archives/${package.name}-${package.version}.tar.gz',
            'archive_sha256': sha256.convert(package.archive).toString(),
          };
          body = {
            'name': package.name,
            'latest': version,
            'versions': [version],
          };
        }
        response.headers.contentType = ContentType(
          'application',
          'vnd.pub.v2+json',
        );
        response.write(jsonEncode(body));
        continue;
      }

      // GET /archives/<name>-<version>.tar.gz
      if (segments.length == 2 && segments[0] == 'archives') {
        final match = packages.values.where(
          (p) => segments[1] == '${p.name}-${p.version}.tar.gz',
        );
        if (match.isNotEmpty) {
          response.headers.contentType = ContentType.binary;
          response.add(match.first.archive);
          continue;
        }
      }

      // Everything else comes from pub.dev; archive URLs in its responses
      // point at pub.dev's storage, so downloads go there directly.
      final upstream = await client.getUrl(
        Uri.parse('$_upstream${request.uri}'),
      );
      final accept = request.headers.value(HttpHeaders.acceptHeader);
      if (accept != null) {
        upstream.headers.set(HttpHeaders.acceptHeader, accept);
      }
      final reply = await upstream.close();
      response.statusCode = reply.statusCode;
      final type = reply.headers.contentType;
      if (type != null) response.headers.contentType = type;
      await response.addStream(reply);
    } catch (error) {
      response.statusCode = HttpStatus.badGateway;
      response.write('$error');
    } finally {
      await response.close();
    }
  }
}
