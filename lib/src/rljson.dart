// @license
// Copyright (c) 2019 - 2024 Dr. Gabriel Gatzsche. All Rights Reserved.
//
// Use of this source code is governed by terms that can be
// found in the LICENSE file in the root of this package.

import 'package:gg_json_hash/gg_json_hash.dart';

/// A simple json map
typedef Rlmap = Map<String, dynamic>;

/// A map of layers
typedef Rllayers = Map<String, Rlmap>;

/// Manages a normalized JSON data structure
///
/// composed of layers '@layerA', '@layerB', etc.
/// Each layer contains an _data array, which contains data items.
/// Each data item has an hash calculated using gg_json_hash.
class Rljson {
  /// Creates a new json containing the given data
  factory Rljson.fromData(Rlmap data) {
    return const Rljson._private(originalData: {}, data: {}).addData(data);
  }

  // ...........................................................................
  /// The json data managed by this object
  final Rlmap originalData;

  /// Returns a map of layers containing a map of items for fast access
  final Rllayers data;

  // ...........................................................................
  /// Creates a new json containing the given data
  Rljson addData(Rlmap addedData) {
    _checkData(addedData);
    _checkLayerNames(addedData);
    addedData = addHashes(addedData);
    final addedDataAsMap = _toMap(addedData);

    if (originalData.isEmpty) {
      return Rljson._private(originalData: addedData, data: addedDataAsMap);
    }

    final mergedData = {...originalData};
    final mergedMap = {...data};

    if (originalData.isNotEmpty) {
      for (final layer in addedData.keys) {
        if (layer == '_hash') {
          continue;
        }

        final oldLayer = originalData[layer];
        final newLayer = addedData[layer];

        // Layer does not exist yet. Insert all
        if (oldLayer == null) {
          mergedData[layer] = newLayer;
          mergedMap[layer] = addedDataAsMap[layer]!;
          continue;
        }

        final oldMap = data[layer] as Rlmap;

        // Layer exists. Merge data
        final mergedLayerData = [...oldLayer['_data'] as List<dynamic>];
        final mergedLayerMap = {...oldMap};
        final newData = newLayer['_data'] as List<dynamic>;

        for (final item in newData) {
          final hash = item['_hash'] as String;
          final exists = mergedLayerMap[hash] != null;

          if (!exists) {
            mergedLayerData.add(item);
            mergedLayerMap[hash] = item;
          }
        }

        newLayer['_data'] = mergedLayerData;
        mergedData[layer] = newLayer;
        mergedMap[layer] = mergedLayerMap;
      }
    }

    return Rljson._private(originalData: mergedData, data: mergedMap);
  }

  // ...........................................................................
  /// Returns the layer with the given name. Throws when name is not found.
  Rllayers layer(String layer) {
    final layerData = data[layer] as Rllayers?;
    if (layerData == null) {
      throw Exception('Layer not found: $layer');
    }

    return layerData;
  }

  // ...........................................................................
  /// Allows to query data from the json
  List<Rlmap> items({
    required String layer,
    required bool Function(Rlmap item) where,
  }) {
    final layerData = this.layer(layer);
    final items = layerData.values.where(where).toList();
    return items;
  }

  // ...........................................................................
  /// Allows to query data from the json
  Rlmap item(
    String layer,
    String hash,
  ) {
    // Get layer
    final layerData = data[layer];
    if (layerData == null) {
      throw Exception('Layer not found: $layer');
    }

    // Get item
    final item = layerData[hash] as Rlmap?;
    if (item == null) {
      throw Exception(
        'Item not found with hash "$hash" in layer "$layer"',
      );
    }

    return item;
  }

  // ...........................................................................
  /// Queries a value from data. Throws when layer or hash is not found.
  dynamic value({
    required String layer,
    required String itemHash,
    String? key,
    String? key2,
    String? key3,
    String? key4,
  }) {
    // Get item
    final resultItem = item(layer, itemHash);

    // If no key is given, return the complete item
    if (key == null) {
      return resultItem;
    }

    // Get item value
    final itemValue = resultItem[key];
    if (itemValue == null) {
      throw Exception(
        'Key "$key" not found in item with hash "$itemHash" in layer "$layer"',
      );
    }

    // Return item value when no link or links are not followed
    if (!key.startsWith('@')) {
      if (key2 != null) {
        throw Exception('Invalid key "$key2". '
            'Additional keys are only allowed for links. '
            'But key "$key" points to a value.');
      }

      return itemValue;
    }

    // Follow links
    final targetLayer = key;
    final targetHash = itemValue as String;

    return value(
      layer: targetLayer,
      itemHash: targetHash,
      key: key2,
      key2: key3,
      key3: key4,
    );
  }

  // ...........................................................................
  /// Returns all pathes found in data
  List<String> ls() {
    final List<String> result = [];
    for (final layerEntry in data.entries) {
      final layer = layerEntry.key;
      final layerData = layerEntry.value;

      for (final itemEntry in layerData.entries) {
        final item = itemEntry.value as Rlmap;
        final hash = item['_hash'];
        for (final key in item.keys) {
          if (key == '_hash') {
            continue;
          }
          result.add('$layer/$hash/$key');
        }
      }
    }
    return result;
  }

  // ...........................................................................
  /// Throws if a link is not available
  void checkLinks() {
    for (final layer in data.keys) {
      final layerData = data[layer] as Rlmap;

      for (final entry in layerData.entries) {
        final item = entry.value as Rlmap;
        for (final key in item.keys) {
          if (key == '_hash') continue;

          if (key.startsWith('@')) {
            // Check if linked layer exists
            final linkLayer = data[key];
            final hash = item['_hash'];

            if (linkLayer == null) {
              throw Exception(
                'Layer "$layer" has an item "$hash" which links to not '
                'existing layer "$key".',
              );
            }

            // Check if linked item exists
            final targetHash = item[key];
            final linkedItem = linkLayer[targetHash];

            if (linkedItem == null) {
              throw Exception(
                'Layer "$layer" has an item "$hash" which links to '
                'not existing item "$targetHash" in layer "$key".',
              );
            }
          }
        }
      }
    }
  }

  // ...........................................................................
  /// An example object
  static final Rljson example = Rljson.fromData({
    '@layerA': {
      '_data': [
        {
          'keyA0': 'a0',
          '_hash': 'KFQrf4mEz0UPmUaFHwH4T6',
        },
        {
          'keyA1': 'a1',
          '_hash': 'YPw-pxhqaUOWRFGramr4B1',
        }
      ],
    },
    '@layerB': {
      '_data': [
        {
          'keyB0': 'b0',
        },
        {
          'keyB1': 'b1',
        }
      ],
    },
  });

  // ...........................................................................
  /// An example object
  static final Rljson exampleWithLink = Rljson.fromData({
    '@layerA': {
      '_data': [
        {
          '_hash': 'KFQrf4mEz0UPmUaFHwH4T6',
          'keyA0': 'a0',
        },
        {
          '_hash': 'YPw-pxhqaUOWRFGramr4B1',
          'keyA1': 'a1',
        }
      ],
    },
    '@linkToLayerA': {
      '_data': [
        {
          '@layerA': 'KFQrf4mEz0UPmUaFHwH4T6',
          '_hash': 'Cr5kvgDz5NGgbnuHu-Z05N',
        },
      ],
    },
  });

  // ...........................................................................
  /// An example object
  static final Rljson exampleWithDeepLink = Rljson.fromData({
    '@a': {
      '_data': [
        {
          '@b': 'Ji-ftHLbqQehV4aV0FlEO6',
          'value': 'a',
          '_hash': 'Q-oaM7xctsuFg_faf1lkhC',
        }
      ],
      '_hash': 'GnSVp1CmoAo3rPiiGl44p-',
    },
    '@b': {
      '_data': [
        {
          '@c': 'tlmxwmwJvFMyBYIYoA2k4K',
          'value': 'b',
          '_hash': 'ks2Zy5nlXx91deccdZtjvK',
        }
      ],
      '_hash': 'uHEtXhILctvNH6zk6k4vDi',
    },
    '@c': {
      '_data': [
        {
          '@d': '0tlKQklLrHoIhHZxdtcbmS',
          'value': 'c',
          '_hash': '3AzQ8kTQ-PjmW0FwY5mirx',
        }
      ],
      '_hash': 'PE0bzvER5q3D-DgxswKzQM',
    },
    '@d': {
      '_data': [
        {
          'value': 'd',
          '_hash': '0tlKQklLrHoIhHZxdtcbmS',
        },
      ],
      '_hash': 'WNq8zriiKUM_vn9DwrwAf0',
    },
    '_hash': '8_qxUEjOkDIq8Um7Z8OCt6',
  });

  // ######################
  // Private
  // ######################

  /// Constructor
  const Rljson._private({required this.originalData, required this.data});

  // ...........................................................................
  void _checkLayerNames(Rlmap data) {
    for (final key in data.keys) {
      if (key == '_hash') continue;

      if (key.startsWith('@')) {
        continue;
      }

      throw Exception('Layer name must start with @: $key');
    }
  }

  // ...........................................................................
  void _checkData(Rlmap data) {
    final layersWithMissingData = <String>[];
    final layersWithWrongType = <String>[];

    for (final layer in data.keys) {
      if (layer == '_hash') continue;
      final layerData = data[layer];
      final items = layerData['_data'];
      if (items == null) {
        layersWithMissingData.add(layer);
      }

      if (items is! List<dynamic>) {
        layersWithWrongType.add(layer);
      }
    }

    if (layersWithMissingData.isNotEmpty) {
      throw Exception(
        '_data is missing in layer: ${layersWithMissingData.join(', ')}',
      );
    }

    if (layersWithWrongType.isNotEmpty) {
      throw Exception(
        '_data must be a list in layer: ${layersWithWrongType.join(', ')}',
      );
    }
  }

  // ...........................................................................
  Rllayers _toMap(Rlmap data) {
    final result = <String, Rlmap>{};

    // Iterate all layers
    for (final layer in data.keys) {
      if (layer.startsWith('_')) continue;

      final layerData = <String, Rlmap>{};
      result[layer] = layerData;

      // Turn _data into map
      final items = data[layer]['_data'] as List<dynamic>;

      for (final item in items) {
        final hash = item['_hash'] as String;
        layerData[hash] = item as Rlmap;
      }
    }

    return result;
  }
}
