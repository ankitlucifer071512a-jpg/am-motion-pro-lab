import 'package:flutter_test/flutter_test.dart';
import 'package:my_first_app/models/gallery_model.dart';
import 'package:my_first_app/services/model_catalog_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('loads the imported character and starter model slots', () async {
    final models = await ModelCatalogRepository.load();

    expect(models, hasLength(5));
    final hero =
        models.firstWhere((model) => model.id == 'anime-hero-character');
    expect(hero.hasModel, isTrue);
    expect(hero.assetPath,
        'assets/models/gallery/3d_anime_character_girl_for_blender.glb');
    expect(models.where((model) => model.isSlot), hasLength(4));
  });

  test('rejects a model path outside the managed GLB folder', () {
    expect(
      () => GalleryModel.fromJson({
        'id': 'bad-path',
        'title': 'Bad path',
        'category': 'Test',
        'description': 'Invalid path test',
        'format': 'GLB',
        'assetPath': '../private/model.glb',
        'previewPath': null,
        'animationInfo': '',
        'isSlot': false,
      }),
      throwsFormatException,
    );
  });
}
