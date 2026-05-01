// ── Phase 3: Text content ────────────────────────────────────────────────

Future<int> _fetchAndInsertTextContent(ContentDatabase db, _Args args) async {
  final dio = Dio(
    BaseOptions(
      baseUrl: 'https://www.sefaria.org',
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 30),
    ),
  );

  // Resume support: find already-inserted refs so we don't re-fetch them.
  final alreadyFetched = <String>{};
  if (args.resume) {
    final existing = await db.contentTextCacheDao.getAllCachedRefs();
    alreadyFetched.addAll(existing);
    if (alreadyFetched.isNotEmpty) {
      print('  Resume: ${alreadyFetched.length} refs already in DB');
    }
  }

  // Collect all leaf refs from hierarchy JSONs.
  final allLeaves = <({String curriculum, String ref})>[];
  for (final entry in _curricula.entries) {
    if (args.curriculum != null && entry.key != args.curriculum) continue;
    final hierarchyPath = 'assets/content/hierarchy/${entry.value}';
    final file = File(hierarchyPath);
    if (!file.existsSync()) {
      print('  ⚠️  Missing hierarchy: $hierarchyPath — skipping');
      continue;
    }
    final json = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
    final items = (json['items'] as List<dynamic>?) ?? const [];
    for (final item in items.cast<Map<String, dynamic>>()) {
      if (item['isLeaf'] != true) continue;
      final ref = item['sefariaRef'] as String?;
      if (ref == null || ref.isEmpty) continue;
      allLeaves.add((curriculum: entry.key, ref: ref));
    }
  }
  print('  Total leaf items: ${allLeaves.length}');

  final toFetch = allLeaves
      .where((l) => !alreadyFetched.contains(l.ref))
      .toList();
  print('  Remaining to fetch: ${toFetch.length}');

  final errorsLog = File('${args.output}/seed_errors.log');
  var fetched = 0;
  var errors = 0;
  final bufferedInserts = <({String ref, String he, String en})>[];

  // Adaptive concurrency: start at max, reduce on 429s, recover over time.
  var activeConcurrency = _maxConcurrentFetches;
  var consecutiveSuccess = 0;
  final sw = Stopwatch()..start();

  for (var i = 0; i < toFetch.length; i += activeConcurrency) {
    final batch = toFetch.skip(i).take(activeConcurrency).toList();

    final futures = batch.map((leaf) => _fetchWithRetry(dio, leaf.ref, args));
    final results = await Future.wait(futures);

    for (final r in results) {
      if (r.error) {
        errors++;
        errorsLog.writeAsStringSync('${r.ref}\n', mode: FileMode.append);
      } else {
        bufferedInserts.add((ref: r.ref, he: r.he, en: r.en));
        fetched++;
      }
    }

    // Adaptive throttling — only trigger on actual rate limits, not 404s.
    final batchHadRateLimit = results.any((r) => r.rateLimited);
    if (batchHadRateLimit && activeConcurrency > 5) {
      activeConcurrency = (activeConcurrency * 0.6).round();
      consecutiveSuccess = 0;
      if (args.verbose) {
        print('    ⚡ Throttled to $activeConcurrency concurrent');
      }
    } else {
      consecutiveSuccess++;
      if (consecutiveSuccess > 20 &&
          activeConcurrency < _maxConcurrentFetches) {
        activeConcurrency = (activeConcurrency + 2).clamp(
          1,
          _maxConcurrentFetches,
        );
        consecutiveSuccess = 0;
        if (args.verbose) {
          print('    ⚡ Recovered to $activeConcurrency concurrent');
        }
      }
    }

    if (bufferedInserts.length >= _batchFlushSize) {
      await _flushTextBatch(db, bufferedInserts);
      bufferedInserts.clear();
    }

    final progress = fetched + errors;
    if (progress % 500 == 0 || progress == toFetch.length) {
      final elapsed = sw.elapsed;
      final rate = progress > 0 ? elapsed.inSeconds / progress : 0;
      final remaining = (toFetch.length - progress) * rate;
      print(
        '    Progress: $progress/${toFetch.length} '
        '(fetched $fetched, errors $errors, '
        '~${(remaining / 60).toStringAsFixed(0)}m remaining)',
      );
    }

    await Future<void>.delayed(const Duration(milliseconds: _batchDelayMs));
  }

  if (bufferedInserts.isNotEmpty) {
    await _flushTextBatch(db, bufferedInserts);
  }
  dio.close();

  final total = fetched + errors;
  final errorRate = total == 0 ? 0 : errors / total;
  print(
    '  Text fetch complete: $fetched ok, $errors errors '
    '(${(errorRate * 100).toStringAsFixed(2)}%)',
  );
  if (errorRate > _textErrorRateThreshold) {
    stderr.writeln(
      '❌ Text fetch error rate ${(errorRate * 100).toStringAsFixed(2)}% '
      'exceeds ${(_textErrorRateThreshold * 100).toStringAsFixed(1)}% '
      'threshold (see ${errorsLog.path})',
    );
    exit(3);
  }

  return _countRows(db, 'text_cache');
}

/// Fetch a single ref with exponential backoff on 429 / transient errors.
Future<_TextResult> _fetchWithRetry(Dio dio, String ref, _Args args) async {
  for (var attempt = 0; attempt < _maxRetries; attempt++) {
    try {
      final texts = await _fetchBothLanguages(dio, ref);
      return (
        ref: ref,
        he: texts.he,
        en: texts.en,
        error: false,
        rateLimited: false,
      );
    } on DioException catch (e) {
      if (e.response?.statusCode == 429 ||
          e.type == DioExceptionType.connectionTimeout) {
        final delay = _backoffBaseMs * (1 << attempt); // 2s, 4s, 8s
        if (args.verbose) {
          print('    ⏳ 429 on $ref — backoff ${delay}ms (attempt $attempt)');
        }
        await Future<void>.delayed(Duration(milliseconds: delay));
        continue;
      }
      // Non-retryable HTTP error (404, 500, etc.) — don't throttle.
      if (args.verbose) {
        print('    ❌ ${e.response?.statusCode ?? e.type} on $ref');
      }
      return (ref: ref, he: '', en: '', error: true, rateLimited: false);
    } catch (e) {
      if (args.verbose) {
        print('    ❌ $e on $ref');
      }
      return (ref: ref, he: '', en: '', error: true, rateLimited: false);
    }
  }
  // All retries exhausted — was rate limited.
  return (ref: ref, he: '', en: '', error: true, rateLimited: true);
}

Future<void> _flushTextBatch(
  ContentDatabase db,
  List<({String ref, String he, String en})> batch,
) async {
  await db.transaction(() async {
    final now = DateTime.now().toUtc();
    for (final item in batch) {
      await db.customInsert(
        'INSERT OR REPLACE INTO text_cache '
        '(sefaria_ref, hebrew_text, english_text, fetched_at) '
        'VALUES (?, ?, ?, ?)',
        variables: [
          Variable.withString(item.ref),
          Variable.withString(item.he),
          Variable.withString(item.en),
          Variable.withDateTime(now),
        ],
      );
    }
  });
}

/// Fetch Hebrew + English text for a single Sefaria ref.
///
/// The /api/v3/texts endpoint returns all available versions in one call.
/// We pick the first version for each of he and en.
Future<({String he, String en})> _fetchBothLanguages(
  Dio dio,
  String sefariaRef,
) async {
  final encodedRef = Uri.encodeComponent(sefariaRef);
  final response = await dio.get<Map<String, dynamic>>(
    '/api/v3/texts/$encodedRef',
  );
  final data = response.data;
  if (data == null) return (he: '', en: '');
  final versions = data['versions'] as List<dynamic>? ?? const [];
  String? he;
  String? en;
  for (final version in versions) {
    if (version is! Map<String, dynamic>) continue;
    final lang =
        (version['actualLanguage'] as String?) ??
        (version['language'] as String?) ??
        '';
    final text = version['text'];
    if (lang == 'he' && he == null) {
      he = _extractText(text);
    } else if (lang == 'en' && en == null) {
      en = _extractText(text);
    }
  }
  return (he: he ?? '', en: en ?? '');
}

String _extractText(dynamic text) {
  if (text == null) return '';
  if (text is String) return _stripHtml(text);
  if (text is List) {
    return text.map(_extractText).where((s) => s.isNotEmpty).join('\n');
  }
  return '';
}

String _stripHtml(String html) => html.replaceAll(RegExp('<[^>]*>'), '').trim();
