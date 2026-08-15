import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:path/path.dart' as p;

import 'package:retrofront/data/downloads/libretro_downloader.dart';

void main() {
  group('coreBaseName', () {
    test('extrai o nome base do comando padrão do ES-DE', () {
      expect(
        LibretroDownloader.coreBaseName(
          '%EMULATOR_RETROARCH% -L %CORE_RETROARCH%/genesis_plus_gx_libretro.so %ROM%',
        ),
        'genesis_plus_gx',
      );
    });

    test('extrai cores com hífen e caminho absoluto', () {
      expect(
        LibretroDownloader.coreBaseName(
          'retroarch -L /cores/bsnes-jg_libretro.so rom',
        ),
        'bsnes-jg',
      );
    });

    test('extrai o nome base do sufixo _android', () {
      expect(
        LibretroDownloader.coreBaseName('-L mesen_libretro_android.so'),
        'mesen',
      );
    });

    test('devolve null sem core definido', () {
      expect(LibretroDownloader.coreBaseName(null), isNull);
      expect(LibretroDownloader.coreBaseName(''), isNull);
      expect(
        LibretroDownloader.coreBaseName('%EMULATOR_RETROARCH% %ROM%'),
        isNull,
      );
    });
  });

  group('coreFileName/coreUrl', () {
    test('monta o nome do arquivo por plataforma', () {
      expect(
        LibretroDownloader.coreFileName(
          coreBase: 'genesis_plus_gx',
          platform: 'android',
        ),
        'genesis_plus_gx_libretro_android.so.zip',
      );
      expect(
        LibretroDownloader.coreFileName(
          coreBase: 'genesis_plus_gx',
          platform: 'linux',
        ),
        'genesis_plus_gx_libretro.so.zip',
      );
    });

    test('monta a URL do buildbot por plataforma/arquitetura', () {
      expect(
        LibretroDownloader.coreUrl(
          coreBase: 'genesis_plus_gx',
          platform: 'android',
          arch: 'arm64-v8a',
        ),
        'http://buildbot.libretro.com/nightly/android/latest/arm64-v8a/'
        'genesis_plus_gx_libretro_android.so.zip',
      );
      expect(
        LibretroDownloader.coreUrl(
          coreBase: 'mesen',
          platform: 'linux',
          arch: 'x86_64',
        ),
        'http://buildbot.libretro.com/nightly/linux/x86_64/latest/'
        'mesen_libretro.so.zip',
      );
    });

    test('bundles do Online Updater apontam para o frontend do buildbot', () {
      for (final b in LibretroDownloader.bundles) {
        expect(b.url, startsWith('${LibretroDownloader.bundleBase}/'));
        expect(b.url, endsWith('.zip'));
      }
    });
  });

  group('downloadAndExtract', () {
    test('baixa, extrai e limpa o zip temporário', () async {
      final destRoot = await Directory.systemTemp.createTemp('rf-dest-');
      final cache = await Directory.systemTemp.createTemp('rf-cache-');
      addTearDown(() async {
        await destRoot.delete(recursive: true);
        await cache.delete(recursive: true);
      });

      final payload = Uint8List.fromList(List.generate(64, (i) => i));
      final zipBytes = _zip({
        'sub/pasta/jogo.so': payload,
        'ignorar.txt': Uint8List.fromList([1, 2, 3]),
      });

      final client = MockClient(
        (_) async => http.Response.bytes(zipBytes, 200),
      );
      final downloader = LibretroDownloader(
        client: client,
        cacheDir: () async => cache,
        destRoot: () async => destRoot,
      );

      final error = await downloader.downloadAndExtract(
        url: 'http://buildbot.libretro.com/teste.zip',
        destFolder: 'cores',
      );

      expect(error, isNull);
      final extracted = File(
        p.join(destRoot.path, 'cores', 'sub', 'pasta', 'jogo.so'),
      );
      expect(await extracted.exists(), isTrue);
      expect(await extracted.readAsBytes(), payload);
      expect(await cache.list().toList(), isEmpty,
          reason: 'o zip temporário deve ser removido');
    });

    test('falha com HTTP diferente de 200 e não extrai nada', () async {
      final destRoot = await Directory.systemTemp.createTemp('rf-dest2-');
      final cache = await Directory.systemTemp.createTemp('rf-cache2-');
      addTearDown(() async {
        await destRoot.delete(recursive: true);
        await cache.delete(recursive: true);
      });

      final client = MockClient((_) async => http.Response('erro', 404));
      final downloader = LibretroDownloader(
        client: client,
        cacheDir: () async => cache,
        destRoot: () async => destRoot,
      );

      final error = await downloader.downloadAndExtract(
        url: 'http://buildbot.libretro.com/inexistente.zip',
        destFolder: 'cores',
      );

      expect(error, contains('HTTP 404'));
      expect(
        Directory(p.join(destRoot.path, 'cores')).listSync(),
        isEmpty,
      );
    });

    test('ignora entradas com path traversal (../)', () async {
      final destRoot = await Directory.systemTemp.createTemp('rf-dest3-');
      final cache = await Directory.systemTemp.createTemp('rf-cache3-');
      addTearDown(() async {
        await destRoot.delete(recursive: true);
        await cache.delete(recursive: true);
      });

      final zipBytes = _zip({
        '../malicioso.txt': Uint8List.fromList([9, 9, 9]),
        'ok.txt': Uint8List.fromList([1, 2, 3]),
      });

      final client = MockClient(
        (_) async => http.Response.bytes(zipBytes, 200),
      );
      final downloader = LibretroDownloader(
        client: client,
        cacheDir: () async => cache,
        destRoot: () async => destRoot,
      );

      final error = await downloader.downloadAndExtract(
        url: 'http://buildbot.libretro.com/teste.zip',
        destFolder: 'dest',
      );

      expect(error, isNull);
      expect(File(p.join(destRoot.path, 'dest', 'ok.txt')).existsSync(), isTrue);
      expect(
        File(p.join(destRoot.path, 'malicioso.txt')).existsSync(),
        isFalse,
        reason: 'entrada fora da pasta deve ser ignorada',
      );
    });

    test('relata progresso durante download e extração', () async {
      final destRoot = await Directory.systemTemp.createTemp('rf-dest4-');
      final cache = await Directory.systemTemp.createTemp('rf-cache4-');
      addTearDown(() async {
        await destRoot.delete(recursive: true);
        await cache.delete(recursive: true);
      });

      final zipBytes = _zip({
        'a.bin': Uint8List.fromList(List.filled(32, 7)),
        'b.bin': Uint8List.fromList(List.filled(32, 8)),
      });
      final client = MockClient(
        (_) async => http.Response.bytes(zipBytes, 200),
      );
      final downloader = LibretroDownloader(
        client: client,
        cacheDir: () async => cache,
        destRoot: () async => destRoot,
      );

      final progress = <double>[];
      await downloader.downloadAndExtract(
        url: 'http://buildbot.libretro.com/teste.zip',
        destFolder: 'dest',
        onProgress: progress.add,
      );

      expect(progress, isNotEmpty);
      expect(progress.first, greaterThan(0));
      expect(progress.last, 1.0);
      expect(progress, everyElement(inInclusiveRange(0.0, 1.0)));
    });
  });
}

/// Monta um zip em memória com os arquivos informados (nome -> conteúdo).
Uint8List _zip(Map<String, Uint8List> files) {
  final archive = Archive();
  files.forEach((name, content) {
    archive.add(ArchiveFile(name, content.length, content));
  });
  return Uint8List.fromList(ZipEncoder().encode(archive));
}
