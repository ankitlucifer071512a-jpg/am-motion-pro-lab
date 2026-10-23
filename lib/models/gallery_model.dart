class GalleryModel {
  const GalleryModel({
    required this.id,
    required this.title,
    required this.category,
    required this.description,
    required this.format,
    required this.animationInfo,
    required this.isSlot,
    this.assetPath,
    this.previewPath,
  });

  final String id;
  final String title;
  final String category;
  final String description;
  final String format;
  final String animationInfo;
  final bool isSlot;
  final String? assetPath;
  final String? previewPath;

  bool get hasModel => !isSlot && assetPath != null;

  factory GalleryModel.fromJson(Map<String, dynamic> json) {
    String requiredText(String key) {
      final value = json[key];
      if (value is! String || value.trim().isEmpty) {
        throw FormatException('Model catalogue field "$key" must be text.');
      }
      return value.trim();
    }

    String? optionalPath(String key) {
      final value = json[key];
      if (value == null) return null;
      if (value is! String || value.trim().isEmpty) {
        throw FormatException(
            'Model catalogue field "$key" must be a path or null.');
      }
      return value.trim();
    }

    final isSlot = json['isSlot'];
    if (isSlot is! bool) {
      throw const FormatException(
          'Model catalogue field "isSlot" must be true or false.');
    }

    final assetPath = optionalPath('assetPath');
    final previewPath = optionalPath('previewPath');
    if (assetPath != null &&
        (!assetPath.startsWith('assets/models/') ||
            assetPath.contains('..') ||
            !assetPath.toLowerCase().endsWith('.glb'))) {
      throw const FormatException(
          'Registered model paths must point to a .glb under assets/models/.');
    }
    if (previewPath != null &&
        (!previewPath.startsWith('assets/models/gallery/') ||
            previewPath.contains('..') ||
            !RegExp(r'\.(png|jpe?g|webp)$', caseSensitive: false)
                .hasMatch(previewPath))) {
      throw const FormatException(
          'Model preview paths must be images under assets/models/gallery/.');
    }
    if (isSlot && assetPath != null) {
      throw const FormatException(
          'A model slot cannot point to an asset; set isSlot to false for a real model.');
    }

    final animationInfo = json['animationInfo'];
    if (animationInfo is! String) {
      throw const FormatException(
          'Model catalogue field "animationInfo" must be text.');
    }

    return GalleryModel(
      id: requiredText('id'),
      title: requiredText('title'),
      category: requiredText('category'),
      description: requiredText('description'),
      format: requiredText('format'),
      animationInfo: animationInfo.trim(),
      isSlot: isSlot,
      assetPath: assetPath,
      previewPath: previewPath,
    );
  }
}
