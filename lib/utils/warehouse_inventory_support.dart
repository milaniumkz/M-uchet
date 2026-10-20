import 'inventory_costing_method.dart';
import 'ledger_scope.dart';

String warehouseDisplayName(Map<String, dynamic> item) {
  final raw = (item['warehouse'] ?? '').toString().trim();
  return raw.isEmpty ? 'Не указан' : raw;
}

WarehouseType warehouseBucketTypeFromData(
  Map<String, dynamic> data, {
  Map<String, dynamic>? warehouseMeta,
}) {
  if (warehouseMeta != null && warehouseMeta.isNotEmpty) {
    return warehouseTypeFromData(warehouseMeta);
  }
  return warehouseTypeFromData(data);
}

String warehouseMovementKind(Map<String, dynamic> item) {
  final explicit =
      (item['movement_kind'] ?? '').toString().trim().toLowerCase();
  if (explicit == 'return' || explicit == 'writeoff' || explicit == 'move') {
    return explicit;
  }
  final from = (item['from_warehouse'] ?? '').toString().toLowerCase();
  final to = (item['to_warehouse'] ?? '').toString().toLowerCase();
  if (from.contains('возврат')) return 'return';
  if (to.contains('списан')) return 'writeoff';
  return 'move';
}

Map<String, dynamic> buildWarehouseInventorySummary({
  required List<Map<String, dynamic>> warehouseDocs,
  required List<Map<String, dynamic>> items,
  required List<Map<String, dynamic>> moves,
  required List<String> virtualWarehouses,
}) {
  final rows = _buildWarehouseRows(
    warehouseDocs: warehouseDocs,
    items: items,
    virtualWarehouses: virtualWarehouses,
  );
  final official = _buildWarehouseBucketStats(
    warehouseDocs: warehouseDocs,
    items: items,
    moves: moves,
    official: true,
  );
  final unofficial = _buildWarehouseBucketStats(
    warehouseDocs: warehouseDocs,
    items: items,
    moves: moves,
    official: false,
  );

  return {
    'rows': rows,
    'official': official,
    'unofficial': unofficial,
    'totalWarehouses':
        warehouseDocs.where((d) => d['isVirtual'] != true).length,
    'totalPositions': items.length,
    'totalValue': items.fold<double>(
      0,
      (sum, item) => sum + ((item['stock_value'] ?? 0) as num).toDouble(),
    ),
  };
}

List<Map<String, dynamic>> _buildWarehouseRows({
  required List<Map<String, dynamic>> warehouseDocs,
  required List<Map<String, dynamic>> items,
  required List<String> virtualWarehouses,
}) {
  final map = <String, Map<String, dynamic>>{};
  final metaByName = <String, Map<String, dynamic>>{};
  for (final doc in warehouseDocs) {
    final name = (doc['name'] ?? '').toString().trim();
    if (name.isEmpty) continue;
    metaByName[name] = doc;
  }
  for (final virtualName in virtualWarehouses) {
    map.putIfAbsent(
      virtualName,
      () => {
        'name': virtualName,
        'parent': '',
        'isGroup': true,
        'isHighlighted': false,
        'count': 0,
        'stock': 0.0,
        'value': 0.0,
      },
    );
  }
  for (final entry in metaByName.entries) {
    final name = entry.key;
    final data = entry.value;
    final isVirtual = data['isVirtual'] == true;
    if (isVirtual) {
      map.putIfAbsent(
        name,
        () => {
          'name': name,
          'parent': '',
          'isGroup': true,
          'isHighlighted': false,
          'count': 0,
          'stock': 0.0,
          'value': 0.0,
        },
      );
      continue;
    }
    final parent =
        (data['parentWarehouse'] ?? data['parent'] ?? '').toString().trim();
    if (parent.isNotEmpty) {
      map.putIfAbsent(
        parent,
        () => {
          'name': parent,
          'parent': '',
          'isGroup': true,
          'isHighlighted': false,
          'count': 0,
          'stock': 0.0,
          'value': 0.0,
        },
      );
    }
    map.putIfAbsent(
      name,
      () => {
        'name': name,
        'parent': parent,
        'isGroup': false,
        'isHighlighted': false,
        'count': 0,
        'stock': 0.0,
        'value': 0.0,
      },
    );
  }

  for (final item in items) {
    final name = warehouseDisplayName(item);
    final stock = ((item['stock'] ?? 0) as num).toDouble();
    final stockValue = ((item['stock_value'] ?? 0) as num).toDouble();
    final meta = metaByName[name] ?? const <String, dynamic>{};
    final parent =
        (meta['parentWarehouse'] ?? meta['parent'] ?? '').toString().trim();
    map.putIfAbsent(
      name,
      () => {
        'name': name,
        'parent': parent,
        'isGroup': false,
        'isHighlighted': false,
        'count': 0,
        'stock': 0.0,
        'value': 0.0,
      },
    );
    map[name]!['count'] = (map[name]!['count'] as int) + 1;
    map[name]!['stock'] = (map[name]!['stock'] as double) + stock;
    map[name]!['value'] = (map[name]!['value'] as double) + stockValue;
    if (parent.isNotEmpty) {
      map.putIfAbsent(
        parent,
        () => {
          'name': parent,
          'parent': '',
          'isGroup': true,
          'isHighlighted': false,
          'count': 0,
          'stock': 0.0,
          'value': 0.0,
        },
      );
      map[parent]!['count'] = (map[parent]!['count'] as int) + 1;
      map[parent]!['stock'] = (map[parent]!['stock'] as double) + stock;
      map[parent]!['value'] = (map[parent]!['value'] as double) + stockValue;
    }
  }

  final groups = map.values.where((r) => r['isGroup'] == true).toList()
    ..sort((a, b) =>
        (a['name'] ?? '').toString().compareTo((b['name'] ?? '').toString()));
  final children = map.values.where((r) => r['isGroup'] != true).toList()
    ..sort((a, b) =>
        (a['name'] ?? '').toString().compareTo((b['name'] ?? '').toString()));
  final result = <Map<String, dynamic>>[];
  for (final group in groups) {
    result.add(group);
    final kids = children
        .where((c) => (c['parent'] ?? '').toString() == (group['name'] ?? ''))
        .toList();
    result.addAll(kids);
  }
  final orphanChildren =
      children.where((c) => (c['parent'] ?? '').toString().isEmpty).toList();
  for (final child in orphanChildren) {
    if (!result.any((row) => row['name'] == child['name'])) {
      result.add(child);
    }
  }
  return result;
}

List<Map<String, dynamic>> _buildWarehouseBucketStats({
  required List<Map<String, dynamic>> warehouseDocs,
  required List<Map<String, dynamic>> items,
  required List<Map<String, dynamic>> moves,
  required bool official,
}) {
  final all = <String, Map<String, dynamic>>{};
  final metaByName = <String, Map<String, dynamic>>{};
  for (final doc in warehouseDocs) {
    final name = (doc['name'] ?? '').toString().trim();
    if (name.isEmpty) continue;
    metaByName[name] = doc;
  }

  for (final item in items) {
    final name = warehouseDisplayName(item);
    final meta = metaByName[name] ?? const <String, dynamic>{};
    final parent =
        (meta['parentWarehouse'] ?? meta['parent'] ?? '').toString().trim();
    final bucket = parent.isNotEmpty
        ? parent
        : warehouseBucketTypeFromData(item, warehouseMeta: meta).bucketLabel;
    final stock = ((item['stock'] ?? 0) as num).toDouble();
    final value = ((item['stock_value'] ?? 0) as num).toDouble();
    final stat = all.putIfAbsent(
      name,
      () => {
        'name': name,
        'parent': bucket,
        'positions': 0,
        'stock': 0.0,
        'value': 0.0,
        'incoming': 0.0,
        'outgoing': 0.0,
        'lastMove': null,
        'costing_methods': <String>{},
      },
    );
    stat['positions'] = (stat['positions'] as int) + 1;
    stat['stock'] = (stat['stock'] as double) + stock;
    stat['value'] = (stat['value'] as double) + value;
    (stat['costing_methods'] as Set<String>).add(
      inventoryCostingMethodLabel(
        resolveInventoryCostingMethod(productData: item),
      ),
    );
  }

  for (final doc in warehouseDocs) {
    final name = (doc['name'] ?? '').toString().trim();
    if (name.isEmpty || doc['isVirtual'] == true) continue;
    final parent =
        (doc['parentWarehouse'] ?? doc['parent'] ?? '').toString().trim();
    final bucket = parent.isNotEmpty
        ? parent
        : warehouseBucketTypeFromData(doc).bucketLabel;
    all.putIfAbsent(
      name,
      () => {
        'name': name,
        'parent': bucket,
        'positions': 0,
        'stock': 0.0,
        'value': 0.0,
        'incoming': 0.0,
        'outgoing': 0.0,
        'lastMove': null,
        'costing_methods': <String>{},
      },
    );
  }

  for (final move in moves) {
    final from = (move['from_warehouse'] ?? '').toString().trim();
    final to = (move['to_warehouse'] ?? '').toString().trim();
    final qty = ((move['qty'] ?? 0) as num).toDouble();
    final createdAt = move['created_at'];

    void updateMove(String warehouseName, bool incoming) {
      if (warehouseName.isEmpty || !all.containsKey(warehouseName)) return;
      final row = all[warehouseName]!;
      if (incoming) {
        row['incoming'] = (row['incoming'] as double) + qty;
      } else {
        row['outgoing'] = (row['outgoing'] as double) + qty;
      }
      if (createdAt is DateTime) {
        final lastMove = row['lastMove'];
        if (lastMove == null || createdAt.isAfter(lastMove as DateTime)) {
          row['lastMove'] = createdAt;
        }
      }
      if (createdAt.runtimeType.toString() == 'Timestamp') {
        final dt = createdAt.toDate() as DateTime;
        final lastMove = row['lastMove'];
        if (lastMove == null || dt.isAfter(lastMove as DateTime)) {
          row['lastMove'] = dt;
        }
      }
    }

    updateMove(to, true);
    updateMove(from, false);
  }

  final bucketName = official ? 'Официальные товары' : 'Неофициальные товары';
  final rows = all.values
      .where((e) => (e['parent'] ?? '').toString() == bucketName)
      .toList()
    ..sort((a, b) =>
        (a['name'] ?? '').toString().compareTo((b['name'] ?? '').toString()));
  for (final row in rows) {
    final methods =
        (row['costing_methods'] as Set<String>? ?? <String>{}).toList()..sort();
    row['costing_methods'] = methods;
  }
  return rows;
}
