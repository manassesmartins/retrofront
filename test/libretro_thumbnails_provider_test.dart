import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:path/path.dart' as p;
import 'package:retrofront/core/app_dirs.dart';
import 'package:retrofront/data/scraping/libretro_thumbnails_provider.dart';
import 'package:retrofront/data/scraping/scrap_provider.dart';
import 'package:retrofront/models/system.dart';

void main() {
  group('LibretroThumbnailsProvider.repoFor', () {
    test('deriva o nome do repo trocando espacos por underscore', () {
      expect(
        LibretroThumbnailsProvider.repoFor(
          'Nintendo - Nintendo Entertainment System',
        ),
        'Nintendo_-_Nintendo_Entertainment_System',
      );
      expect(
        LibretroThumbnailsProvider.repoFor('Sega - Mega Drive - Genesis'),
        'Sega_-_Mega_Drive_-_Genesis',
      );
    });

    test('casos especiais de repositorios nao derivaveis', () {
      expect(LibretroThumbnailsProvider.repoFor('Bomberman Game Clone'),
          'MrBoom');
      expect(LibretroThumbnailsProvider.repoFor("Jump 'n Bump"),
          'Jump_n_Bump');
      expect(
        LibretroThumbnailsProvider.repoFor('Nintendo - Nintendo 3DS (DLC)'),
        'Nintendo_-_Nintendo_3DS_DLC',
      );
      expect(LibretroThumbnailsProvider.repoFor('Philips - Videopac+'),
          'Philips_-_Videopac');
      expect(
        LibretroThumbnailsProvider.repoFor(
          'Sony - PlayStation 3 (Downloadable)',
        ),
        'Sony_-_PlayStation_3_Downloadable',
      );
    });
  });

  group('LibretroThumbnailsProvider.scrap', () {
    late Directory base;

    setUp(() {
      base = Directory.systemTemp.createTempSync('retrofront_libretro');
      AppDirs.useRomsOverride(p.join(base.path, 'Retrofront', 'ROMs'));
    });

    tearDown(() {
      AppDirs.useRomsOverride(null);
      base.deleteSync(recursive: true);
    });

    const system = SystemDefinition(
      name: 'nes',
      fullName: 'Nintendo Entertainment System',
      libretroThumbnails: 'Nintendo - Nintendo Entertainment System',
      extensions: ['.nes'],
    );

    test('baixa do repositório do submodule (caminho rápido)', () async {
      final requested = <String>[];
      final client = MockClient((request) async {
        requested.add(request.url.toString());
        return http.Response.bytes(
          Uint8List.fromList([0x89, 0x50, 0x4E, 0x47]),
          200,
        );
      });

      final provider = LibretroThumbnailsProvider(client: client);
      final result = await provider.scrap(
        const ScrapContext(system: system, gameName: 'Super Mario Bros. (USA)'),
      );

      expect(result.coverDownloaded, isTrue);
      expect(result.metadata?.coverPath, isNotNull);
      expect(
        File(result.metadata!.coverPath!).existsSync(),
        isTrue,
        reason: 'capa salva em disco',
      );

      expect(requested.first, startsWith(
        'https://raw.githubusercontent.com/libretro-thumbnails/'
        'Nintendo_-_Nintendo_Entertainment_System/Named_Boxarts/',
      ));
      expect(
        requested.first,
        isNot(contains('libretro-thumbnails/libretro-thumbnails/')),
        reason: 'nao pode usar o repo principal (submodule retorna 404)',
      );
    });

    test('fallback lista o repo do submodule e faz match fuzzy', () async {
      final listingJson = jsonEncode([
        {
          'name': 'Super Mario Bros. (World).png',
          'download_url': 'https://exemplo/ignorado.png',
        },
      ]);
      final requested = <String>[];
      var listingCalled = false;

      final client = MockClient((request) async {
        requested.add(request.url.toString());
        if (request.url.path.endsWith('/contents/Named_Boxarts')) {
          listingCalled = true;
          return http.Response(listingJson, 200);
        }
        // Caminho rapido com o nome exato falha; o download do match fuzzy
        // ("(World)") responde 200.
        if (request.url.path.endsWith('/Super%20Mario%20Bros..png')) {
          return http.Response('not found', 404);
        }
        return http.Response.bytes(
          Uint8List.fromList([0x89, 0x50, 0x4E, 0x47]),
          200,
        );
      });

      final provider = LibretroThumbnailsProvider(client: client);
      final result = await provider.scrap(
        const ScrapContext(system: system, gameName: 'Super Mario Bros.'),
      );

      expect(listingCalled, isTrue, reason: 'deve listar o diretorio');
      expect(result.coverDownloaded, isTrue);
      expect(requested, contains(
        'https://api.github.com/repos/libretro-thumbnails/'
        'Nintendo_-_Nintendo_Entertainment_System/contents/Named_Boxarts',
      ));
    });

    test('sem pasta libretroThumbnails retorna sem resultado', () async {
      final provider = LibretroThumbnailsProvider(client: MockClient((_) async {
        return http.Response('', 500);
      }));
      final result = await provider.scrap(
        const ScrapContext(
          system: SystemDefinition(
            name: 'atomiswave',
            fullName: 'Atomiswave',
            extensions: ['.bin'],
          ),
          gameName: 'jogo',
        ),
      );
      expect(result.coverDownloaded, isFalse);
      expect(result.hasResult, isFalse);
    });
  });
}
