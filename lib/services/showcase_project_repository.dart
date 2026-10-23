import 'dart:convert';

import 'package:flutter/services.dart';

import '../models/showcase_project.dart';

class ShowcaseProjectRepository {
  ShowcaseProjectRepository._();

  static Future<List<ShowcaseProject>> load() async {
    final json = jsonDecode(
      await rootBundle.loadString('assets/data/projects/project_catalog.json'),
    ) as Map<String, dynamic>;
    return (json['projects'] as List<dynamic>)
        .map((entry) => ShowcaseProject.fromJson(entry as Map<String, dynamic>))
        .toList(growable: false);
  }
}
