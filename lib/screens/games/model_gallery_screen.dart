import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../models/gallery_model.dart';
import '../../services/model_catalog_repository.dart';
import '../../widgets/app_button.dart';
import '../../widgets/glass_card.dart';
import '../../widgets/interactive_model_viewer.dart';
import 'three_d_studio_screen.dart';

class ModelGalleryScreen extends StatefulWidget {
  const ModelGalleryScreen({super.key});

  @override
  State<ModelGalleryScreen> createState() => _ModelGalleryScreenState();
}

class _ModelGalleryScreenState extends State<ModelGalleryScreen> {
  late Future<List<GalleryModel>> _catalog = ModelCatalogRepository.load();
  final _search = TextEditingController();
  String _category = 'All';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _retry() => setState(() => _catalog = ModelCatalogRepository.load());

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('3D Model Gallery')),
        body: FutureBuilder<List<GalleryModel>>(
          future: _catalog,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return _CatalogState(
                icon: Icons.broken_image_outlined,
                title: 'Could not load the model catalogue',
                message:
                    'Check assets/data/models/model_catalog.json and its registered asset paths, then try again.',
                action: TextButton.icon(
                  onPressed: _retry,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Retry'),
                ),
              );
            }
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final models = snapshot.data!;
            final categories = [
              'All',
              ...models.map((m) => m.category).toSet()
            ];
            final query = _search.text.trim().toLowerCase();
            final visible = models.where((model) {
              final matchesCategory =
                  _category == 'All' || model.category == _category;
              final matchesSearch = query.isEmpty ||
                  '${model.title} ${model.category} ${model.description}'
                      .toLowerCase()
                      .contains(query);
              return matchesCategory && matchesSearch;
            }).toList();

            return CustomScrollView(
              slivers: [
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(18, 14, 18, 0),
                  sliver: SliverToBoxAdapter(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('YOUR MODEL LIBRARY', style: AppText.label),
                        const SizedBox(height: 6),
                        Text('Explore 3D assets', style: AppText.h1),
                        const SizedBox(height: 6),
                        Text(
                          'Browse registered GLB assets or use a labelled slot to plan what you will add next.',
                          style: AppText.body,
                        ),
                        const SizedBox(height: 14),
                        TextField(
                          controller: _search,
                          onChanged: (_) => setState(() {}),
                          decoration: InputDecoration(
                            hintText: 'Search models and categories',
                            prefixIcon: const Icon(Icons.search),
                            suffixIcon: _search.text.isEmpty
                                ? null
                                : IconButton(
                                    tooltip: 'Clear search',
                                    onPressed: () {
                                      _search.clear();
                                      setState(() {});
                                    },
                                    icon: const Icon(Icons.close),
                                  ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        SizedBox(
                          height: 40,
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            itemCount: categories.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(width: 8),
                            itemBuilder: (context, index) {
                              final category = categories[index];
                              return ChoiceChip(
                                label: Text(category),
                                selected: _category == category,
                                onSelected: (_) =>
                                    setState(() => _category = category),
                              );
                            },
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'The starter catalogue contains empty slots; no sample models are bundled.',
                          style: AppText.caption,
                        ),
                      ],
                    ),
                  ),
                ),
                if (visible.isEmpty)
                  const SliverFillRemaining(
                    hasScrollBody: false,
                    child: _CatalogState(
                      icon: Icons.search_off_rounded,
                      title: 'No matching model slots',
                      message: 'Try another search or choose All categories.',
                    ),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(18, 12, 18, 26),
                    sliver: SliverGrid.builder(
                      itemCount: visible.length,
                      gridDelegate:
                          const SliverGridDelegateWithMaxCrossAxisExtent(
                        maxCrossAxisExtent: 390,
                        mainAxisExtent: 252,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                      ),
                      itemBuilder: (context, index) => _ModelCard(
                        model: visible[index],
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => ModelDetailScreen(
                              model: visible[index],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      );
}

class _ModelCard extends StatelessWidget {
  const _ModelCard({required this.model, required this.onTap});
  final GalleryModel model;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: GlassCard(
          padding: EdgeInsets.zero,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(15)),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      _ModelPreview(model: model, compact: true),
                      Positioned(
                        left: 10,
                        top: 10,
                        child: _Tag(model.category),
                      ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(13, 10, 13, 12),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(model.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppText.h3.copyWith(fontSize: 15)),
                          const SizedBox(height: 3),
                          Text(
                            model.hasModel ? model.format : 'Empty asset slot',
                            style: AppText.caption,
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.arrow_forward_rounded,
                        size: 18, color: AppColors.sky),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
}

class ModelDetailScreen extends StatelessWidget {
  const ModelDetailScreen({super.key, required this.model});
  final GalleryModel model;

  void _openStudio(BuildContext context) {
    Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => ThreeDStudioScreen(
        initialAssetPath: model.assetPath,
        initialModelName: model.title,
      ),
    ));
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Model details')),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(18, 8, 18, 28),
          children: [
            AspectRatio(
              aspectRatio: 16 / 10,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: model.hasModel
                    ? InteractiveModelViewer(
                        key: ValueKey(model.assetPath),
                        src: model.assetPath!,
                        alt: model.title,
                        poster: model.previewPath,
                        backgroundColor: AppColors.navyDeep,
                      )
                    : _ModelPreview(model: model),
              ),
            ),
            const SizedBox(height: 18),
            Text(model.category.toUpperCase(), style: AppText.label),
            const SizedBox(height: 5),
            Text(model.title, style: AppText.h1),
            const SizedBox(height: 9),
            Text(model.description, style: AppText.body),
            const SizedBox(height: 18),
            GlassCard(
              padding: const EdgeInsets.all(15),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _MetadataRow(
                    label: 'Format',
                    value: model.hasModel ? model.format : 'GLB slot',
                  ),
                  const SizedBox(height: 10),
                  _MetadataRow(
                    label: 'Animation',
                    value: model.animationInfo,
                  ),
                  if (model.assetPath != null) ...[
                    const SizedBox(height: 10),
                    _MetadataRow(label: 'Asset', value: model.assetPath!),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 14),
            AppButton(
              label:
                  model.hasModel ? 'Open in 3D Studio' : 'Import a GLB model',
              icon: Icons.view_in_ar_outlined,
              expand: true,
              onTap: () => _openStudio(context),
            ),
            const SizedBox(height: 9),
            Text(
              model.hasModel
                  ? 'Interactive GLB viewer: drag to orbit and pinch or scroll to zoom. If it fails to load, check the catalogue path and pack all textures into the GLB.'
                  : 'This is an empty slot. Add a packed GLB under assets/models/, update the catalogue, and register the asset in pubspec.yaml to preview it here.',
              style: AppText.caption,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
}

class _ModelPreview extends StatelessWidget {
  const _ModelPreview({required this.model, this.compact = false});
  final GalleryModel model;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final previewPath = model.previewPath;
    if (previewPath != null) {
      return Image.asset(
        previewPath,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _fallback(),
        frameBuilder: (context, child, frame, syncLoaded) =>
            frame != null || syncLoaded
                ? child
                : const Center(child: CircularProgressIndicator()),
      );
    }
    return _fallback();
  }

  Widget _fallback() => DecoratedBox(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(0, -.25),
            radius: 1.15,
            colors: [Color(0xFF1B2E50), Color(0xFF0B1222)],
          ),
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.view_in_ar_outlined,
                  size: compact ? 34 : 48, color: AppColors.sky),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  model.hasModel
                      ? 'Preview image not supplied'
                      : 'Empty model slot · add a GLB to preview',
                  style: AppText.caption,
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        ),
      );
}

class _MetadataRow extends StatelessWidget {
  const _MetadataRow({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 86,
            child: Text(label, style: AppText.caption),
          ),
          Expanded(child: Text(value, style: AppText.body)),
        ],
      );
}

class _Tag extends StatelessWidget {
  const _Tag(this.label);
  final String label;

  @override
  Widget build(BuildContext context) => DecoratedBox(
        decoration: BoxDecoration(
          color: AppColors.navyDeep.withValues(alpha: .82),
          borderRadius: BorderRadius.circular(99),
          border: Border.all(color: AppColors.glassBorderStrong),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
          child: Text(label,
              style: AppText.caption.copyWith(color: AppColors.ink)),
        ),
      );
}

class _CatalogState extends StatelessWidget {
  const _CatalogState({
    required this.icon,
    required this.title,
    required this.message,
    this.action,
  });

  final IconData icon;
  final String title;
  final String message;
  final Widget? action;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: GlassCard(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 38, color: AppColors.sky),
                const SizedBox(height: 10),
                Text(title, style: AppText.h3, textAlign: TextAlign.center),
                const SizedBox(height: 6),
                Text(message,
                    style: AppText.caption, textAlign: TextAlign.center),
                if (action != null) ...[
                  const SizedBox(height: 8),
                  action!,
                ],
              ],
            ),
          ),
        ),
      );
}
