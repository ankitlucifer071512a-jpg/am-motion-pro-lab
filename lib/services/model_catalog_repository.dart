import 'dart:convert';

import 'package:flutter/services.dart';

import '../models/gallery_model.dart';

class ModelCatalogRepository {
  ModelCatalogRepository._();

  static const catalogAsset = 'assets/data/models/model_catalog.json';

  static Future<List<GalleryModel>> load() async {
    final raw = await rootBundle.loadString(catalogAsset);
    final decoded = jsonDecode(raw);
    if (decoded is! Map<String, dynamic> || decoded['version'] != 1) {
      throw const FormatException('Unsupported 3D model catalogue version.');
    }
    final models = decoded['models'];
    if (models is! List) {
      throw const FormatException('The model catalogue has no models list.');
    }
    final result = <GalleryModel>[];
    final ids = <String>{};
    for (final item in models) {
      if (item is! Map<String, dynamic>) {
        throw const FormatException('A model catalogue entry is malformed.');
      }
      final model = GalleryModel.fromJson(item);
      if (!ids.add(model.id)) {
        throw FormatException('Duplicate model catalogue id: ${model.id}.');
      }
      result.add(model);
    }
    return List.unmodifiable(result);
  }
}
