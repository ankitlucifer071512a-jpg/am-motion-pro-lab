import 'package:flutter/material.dart';

class Plan {
  const Plan({
    required this.levelId,
    required this.label,
    required this.shortLabel,
    required this.duration,
    required this.price,
    required this.features,
    required this.support,
  });

  final String levelId; // basic | advanced | professional (same ids as backend)
  final String label;
  final String shortLabel;
  final String duration;
  final int price; // display only. The backend decides the real price.
  final List<String> features;
  final List<String> support;
}

class CourseModule {
  const CourseModule({required this.title, required this.topics});
  final String title;
  final List<String> topics;
}

class Course {
  const Course({
    required this.id,
    required this.name,
    required this.tagline,
    required this.description,
    required this.imageAsset,
    required this.icon,
    required this.skills,
    required this.tools,
    required this.modules,
    required this.plans,
  });

  final String id; // same ids as backend: video-editing, 2d-animation, ...
  final String name;
  final String tagline;
  final String description;
  final String imageAsset;
  final IconData icon;
  final List<String> skills;
  final List<String> tools;
  final List<CourseModule> modules;
  final List<Plan> plans;

  int get startingPrice => plans.map((p) => p.price).reduce((a, b) => a < b ? a : b);

  String get durationLabel {
    final re = RegExp(r'(\d+)\D+(\d+)');
    final a = re.firstMatch(plans.first.duration);
    final b = re.firstMatch(plans.last.duration);
    if (a == null || b == null) return plans.first.duration;
    return '${a.group(1)}\u2013${b.group(2)} Months';
  }
}
