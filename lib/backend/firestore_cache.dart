import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';

class FirestoreQueryCache {
  FirestoreQueryCache._();
  static final FirestoreQueryCache instance = FirestoreQueryCache._();

  final Map<String, _CacheEntry<QuerySnapshot>> _queryCache = {};
  final Map<String, _CacheEntry<int>> _countCache = {};
  final Map<String, Future<QuerySnapshot>> _pendingQueries = {};
  final Map<String, Future<int>> _pendingCounts = {};
  final Map<String, StreamSubscription<QuerySnapshot>> _queryListeners = {};
  final Map<String, StreamSubscription<QuerySnapshot>> _countListeners = {};
  final StreamController<void> _changes = StreamController.broadcast();

  Duration defaultTtl = const Duration(minutes: 2);
  Duration defaultRefreshInterval = Duration.zero;

  Stream<void> get changes => _changes.stream;

  Future<QuerySnapshot> getQuery(
    Query query, {
    String? key,
    Duration? ttl,
    Duration? refreshInterval,
  }) async {
    final cacheKey = key ?? query.toString();
    final now = DateTime.now();
    final entry = _queryCache[cacheKey];
    final effectiveTtl = ttl ?? defaultTtl;
    final effectiveRefresh = refreshInterval ?? defaultRefreshInterval;

    if (entry != null) {
      _ensureTimer(cacheKey, entry, effectiveRefresh, () async {
        await _refreshQuery(cacheKey, query, entry);
      });
      if (now.difference(entry.timestamp) <= effectiveTtl) {
        return entry.data;
      }
    }

    final pending = _pendingQueries[cacheKey];
    if (pending != null) {
      return pending;
    }

    final request = _fetchQuery(
      cacheKey: cacheKey,
      query: query,
      now: now,
      entry: entry,
      refreshInterval: effectiveRefresh,
    );
    _pendingQueries[cacheKey] = request;

    try {
      return await request;
    } catch (_) {
      if (entry != null) return entry.data;
      rethrow;
    } finally {
      if (identical(_pendingQueries[cacheKey], request)) {
        _pendingQueries.remove(cacheKey);
      }
    }
  }

  Future<int> getCount(
    AggregateQuery query, {
    String? key,
    Duration? ttl,
    Duration? refreshInterval,
  }) async {
    final cacheKey = key ?? query.toString();
    final now = DateTime.now();
    final entry = _countCache[cacheKey];
    final effectiveTtl = ttl ?? defaultTtl;
    final effectiveRefresh = refreshInterval ?? defaultRefreshInterval;

    if (entry != null) {
      _ensureTimer(cacheKey, entry, effectiveRefresh, () async {
        await _refreshCount(cacheKey, query, entry);
      });
      if (now.difference(entry.timestamp) <= effectiveTtl) {
        return entry.data;
      }
    }

    final pending = _pendingCounts[cacheKey];
    if (pending != null) {
      return pending;
    }

    final request = _fetchCount(
      cacheKey: cacheKey,
      query: query,
      now: now,
      entry: entry,
      refreshInterval: effectiveRefresh,
    );
    _pendingCounts[cacheKey] = request;

    try {
      return await request;
    } catch (_) {
      if (entry != null) return entry.data;
      rethrow;
    } finally {
      if (identical(_pendingCounts[cacheKey], request)) {
        _pendingCounts.remove(cacheKey);
      }
    }
  }

  Future<QuerySnapshot> _fetchQuery({
    required String cacheKey,
    required Query query,
    required DateTime now,
    required _CacheEntry<QuerySnapshot>? entry,
    required Duration refreshInterval,
  }) async {
    final snapshot = await query.get(
      const GetOptions(source: Source.serverAndCache),
    );
    final target = entry ?? _CacheEntry<QuerySnapshot>(snapshot, now);
    target
      ..data = snapshot
      ..timestamp = DateTime.now();
    _queryCache[cacheKey] = target;
    _ensureTimer(cacheKey, target, refreshInterval, () async {
      await _refreshQuery(cacheKey, query, target);
    });
    return snapshot;
  }

  Future<int> _fetchCount({
    required String cacheKey,
    required AggregateQuery query,
    required DateTime now,
    required _CacheEntry<int>? entry,
    required Duration refreshInterval,
  }) async {
    final snapshot = await query.get();
    final nextValue = snapshot.count ?? 0;
    final target = entry ?? _CacheEntry<int>(nextValue, now);
    target
      ..data = nextValue
      ..timestamp = DateTime.now();
    _countCache[cacheKey] = target;
    _ensureTimer(cacheKey, target, refreshInterval, () async {
      await _refreshCount(cacheKey, query, target);
    });
    return nextValue;
  }

  void watchCountQuery(
    Query query, {
    String? key,
  }) {
    final cacheKey = key ?? query.toString();
    if (_countListeners.containsKey(cacheKey)) return;
    _countListeners[cacheKey] = query.snapshots().listen((snapshot) {
      final existing = _countCache[cacheKey];
      if (existing != null) {
        existing
          ..data = snapshot.size
          ..timestamp = DateTime.now();
      } else {
        _countCache[cacheKey] = _CacheEntry(snapshot.size, DateTime.now());
      }
      _changes.add(null);
    });
  }

  Future<void> _refreshQuery(
    String key,
    Query query,
    _CacheEntry<QuerySnapshot> entry,
  ) async {
    if (entry.refreshing) return;
    entry.refreshing = true;
    try {
      final snapshot = await query.get(
        const GetOptions(source: Source.serverAndCache),
      );
      entry
        ..data = snapshot
        ..timestamp = DateTime.now();
      _changes.add(null);
    } catch (_) {
      // Keep stale data.
    } finally {
      entry.refreshing = false;
    }
  }

  Future<void> _refreshCount(
    String key,
    AggregateQuery query,
    _CacheEntry<int> entry,
  ) async {
    if (entry.refreshing) return;
    entry.refreshing = true;
    try {
      final snapshot = await query.get();
      entry
        ..data = snapshot.count ?? 0
        ..timestamp = DateTime.now();
      _changes.add(null);
    } catch (_) {
      // Keep stale data.
    } finally {
      entry.refreshing = false;
    }
  }

  void _ensureTimer(
    String key,
    _CacheEntry entry,
    Duration refreshInterval,
    Future<void> Function() refresh,
  ) {
    if (refreshInterval.inSeconds <= 0) return;
    entry.timer ??= Timer.periodic(refreshInterval, (_) {
      refresh();
    });
  }

  void invalidatePrefix(String prefix) {
    final queryKeys = _queryCache.keys.where((k) => k.startsWith(prefix)).toList();
    for (final key in queryKeys) {
      _queryCache.remove(key)?.timer?.cancel();
      _queryListeners.remove(key)?.cancel();
    }
    final countKeys = _countCache.keys.where((k) => k.startsWith(prefix)).toList();
    for (final key in countKeys) {
      _countCache.remove(key)?.timer?.cancel();
      _countListeners.remove(key)?.cancel();
    }
  }

  void invalidateCollection(String collectionPath) {
    final queryKeys = _queryCache.keys
        .where((k) => k.contains(collectionPath))
        .toList();
    for (final key in queryKeys) {
      _queryCache.remove(key)?.timer?.cancel();
      _queryListeners.remove(key)?.cancel();
    }
    final countKeys = _countCache.keys
        .where((k) => k.contains(collectionPath))
        .toList();
    for (final key in countKeys) {
      _countCache.remove(key)?.timer?.cancel();
      _countListeners.remove(key)?.cancel();
    }
  }

  void invalidateCompanyCollection(String collectionPath, String companyId) {
    if (companyId.isEmpty) {
      invalidateCollection(collectionPath);
      return;
    }
    final queryKeys = _queryCache.keys
        .where((k) =>
            k.contains(collectionPath) && k.contains(companyId))
        .toList();
    for (final key in queryKeys) {
      _queryCache.remove(key)?.timer?.cancel();
      _queryListeners.remove(key)?.cancel();
    }
    final countKeys = _countCache.keys
        .where((k) =>
            k.contains(collectionPath) && k.contains(companyId))
        .toList();
    for (final key in countKeys) {
      _countCache.remove(key)?.timer?.cancel();
      _countListeners.remove(key)?.cancel();
    }
  }

  void clear() {
    for (final entry in _queryCache.values) {
      entry.timer?.cancel();
    }
    for (final entry in _countCache.values) {
      entry.timer?.cancel();
    }
    for (final sub in _queryListeners.values) {
      sub.cancel();
    }
    for (final sub in _countListeners.values) {
      sub.cancel();
    }
    _queryCache.clear();
    _countCache.clear();
    _pendingQueries.clear();
    _pendingCounts.clear();
    _queryListeners.clear();
    _countListeners.clear();
  }
}

class _CacheEntry<T> {
  _CacheEntry(this.data, this.timestamp);

  T data;
  DateTime timestamp;
  Timer? timer;
  bool refreshing = false;
}

extension CachedQueryExtension on Query {
  Future<QuerySnapshot> getCached({
    Duration? ttl,
    Duration? refreshInterval,
    String? key,
  }) {
    return FirestoreQueryCache.instance.getQuery(
      this,
      ttl: ttl,
      refreshInterval: refreshInterval,
      key: key,
    );
  }
}
