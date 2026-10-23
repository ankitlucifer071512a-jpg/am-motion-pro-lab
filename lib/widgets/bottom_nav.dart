import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/theme/app_colors.dart';
import '../services/idea_lab_backend.dart';
import '../services/idea_lab_social_service.dart';

class NavItemData {
  const NavItemData(this.label, this.icon, this.activeIcon);
  final String label;
  final IconData icon;
  final IconData activeIcon;
}

/// Bottom navigation with a glowing sliding indicator and small icon motion.
class AmBottomNav extends StatefulWidget {
  const AmBottomNav({super.key, required this.index, required this.onChanged});
  final int index;
  final ValueChanged<int> onChanged;

  static const items = [
    NavItemData('Home', Icons.home_outlined, Icons.home_rounded),
    NavItemData('Courses', Icons.grid_view_outlined, Icons.grid_view_rounded),
    NavItemData('Game Lab', Icons.extension_outlined, Icons.extension_rounded),
    NavItemData(
        'Idea Lab', Icons.lightbulb_outline_rounded, Icons.lightbulb_rounded),
    NavItemData('Purchase Courses', Icons.shopping_bag_outlined,
        Icons.shopping_bag_rounded),
    NavItemData('Notifications', Icons.notifications_outlined,
        Icons.notifications_rounded),
    NavItemData('Profile', Icons.person_outline_rounded, Icons.person_rounded),
  ];

  @override
  State<AmBottomNav> createState() => _AmBottomNavState();
}

class _AmBottomNavState extends State<AmBottomNav> {
  StreamSubscription<AuthState>? _authSubscription;
  String? _avatarUrl;

  @override
  void initState() {
    super.initState();
    IdeaLabSocialService.currentUserAvatar.addListener(_syncAvatar);
    if (IdeaLabBackend.isReady) {
      _authSubscription = IdeaLabBackend.client.auth.onAuthStateChange.listen((_) {
        _syncAvatar();
        _loadAvatar();
      });
    }
    _loadAvatar();
  }

  Future<void> _loadAvatar() async {
    final user = IdeaLabBackend.currentUser;
    if (user == null) {
      if (mounted && _avatarUrl != null) setState(() => _avatarUrl = null);
      return;
    }
    try {
      await IdeaLabSocialService().profile(user.id);
    } catch (_) {
      // Keep the default profile icon if the profile cannot be loaded.
    }
  }

  void _syncAvatar() {
    if (!mounted) return;
    final userId = IdeaLabBackend.currentUser?.id;
    final avatar = IdeaLabSocialService.currentUserAvatar.value;
    final nextUrl = avatar != null && avatar.$1 == userId ? avatar.$2 : null;
    if (nextUrl != _avatarUrl) setState(() => _avatarUrl = nextUrl);
  }

  @override
  void dispose() {
    IdeaLabSocialService.currentUserAvatar.removeListener(_syncAvatar);
    _authSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.navy.fade(0.97),
        border: const Border(top: BorderSide(color: AppColors.glassBorder)),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 62,
          child: LayoutBuilder(
            builder: (context, cons) {
              final availableItemWidth =
                  cons.maxWidth / AmBottomNav.items.length;
              final itemWidth =
                  availableItemWidth < 96 ? 96.0 : availableItemWidth;
              return _ScrollableNavItems(
                index: widget.index,
                itemWidth: itemWidth,
                onChanged: widget.onChanged,
                avatarUrl: _avatarUrl,
              );
            },
          ),
        ),
      ),
    );
  }
}

class _ScrollableNavItems extends StatefulWidget {
  const _ScrollableNavItems({
    required this.index,
    required this.itemWidth,
    required this.onChanged,
    required this.avatarUrl,
  });

  final int index;
  final double itemWidth;
  final ValueChanged<int> onChanged;
  final String? avatarUrl;

  @override
  State<_ScrollableNavItems> createState() => _ScrollableNavItemsState();
}

class _ScrollableNavItemsState extends State<_ScrollableNavItems> {
  final ScrollController _scrollController = ScrollController();

  @override
  void didUpdateWidget(covariant _ScrollableNavItems oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.index != widget.index) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _revealItem(widget.index);
      });
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _revealItem(int itemIndex) {
    if (!_scrollController.hasClients) return;
    final position = _scrollController.position;
    final itemStart = itemIndex * widget.itemWidth;
    final itemEnd = itemStart + widget.itemWidth;
    var offset = position.pixels;
    if (itemStart < offset) {
      offset = itemStart;
    } else if (itemEnd > offset + position.viewportDimension) {
      offset = itemEnd - position.viewportDimension;
    }
    offset = offset.clamp(0.0, position.maxScrollExtent);
    if ((offset - position.pixels).abs() > 0.5) {
      _scrollController.animateTo(
        offset,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final contentWidth = widget.itemWidth * AmBottomNav.items.length;
    final indicatorWidth = widget.itemWidth * 0.44;
    return SingleChildScrollView(
      controller: _scrollController,
      scrollDirection: Axis.horizontal,
      child: SizedBox(
        width: contentWidth,
        height: 62,
        child: Stack(
          children: [
            AnimatedPositioned(
              duration: const Duration(milliseconds: 280),
              curve: Curves.easeOutCubic,
              left: widget.itemWidth * widget.index + widget.itemWidth * 0.28,
              top: 0,
              width: indicatorWidth,
              height: 2.5,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: AppColors.brandGradient,
                  borderRadius:
                      const BorderRadius.vertical(bottom: Radius.circular(3)),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.blue.fade(0.7),
                      blurRadius: 14,
                      spreadRadius: 1,
                    )
                  ],
                ),
              ),
            ),
            Row(
              children: [
                for (var i = 0; i < AmBottomNav.items.length; i++)
                  SizedBox(
                    width: widget.itemWidth,
                    child: _NavItem(
                      data: AmBottomNav.items[i],
                      active: i == widget.index,
                      avatarUrl: widget.avatarUrl,
                      onTap: () {
                        _revealItem(i);
                        widget.onChanged(i);
                      },
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem(
      {required this.data,
      required this.active,
      required this.avatarUrl,
      required this.onTap});
  final NavItemData data;
  final bool active;
  final String? avatarUrl;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          AnimatedScale(
            scale: active ? 1.12 : 1.0,
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOut,
            child: AnimatedSlide(
              offset: active ? const Offset(0, -0.06) : Offset.zero,
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOut,
              child: TweenAnimationBuilder<Color?>(
                tween: ColorTween(
                    end: active ? AppColors.sky : AppColors.inkFaint),
                duration: const Duration(milliseconds: 220),
                builder: (context, color, _) {
                  final iconColor = color ??
                      (active ? AppColors.sky : AppColors.inkFaint);
                  return data.label == 'Profile' && avatarUrl != null
                      ? _ProfileAvatar(
                          url: avatarUrl!, borderColor: iconColor)
                      : Icon(active ? data.activeIcon : data.icon,
                          size: 24, color: iconColor);
                },
              ),
            ),
          ),
          const SizedBox(height: 3),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 220),
              style: GoogleFonts.poppins(
                fontSize: 10.5,
                fontWeight: active ? FontWeight.w600 : FontWeight.w500,
                color: active ? AppColors.offWhite : AppColors.inkFaint,
              ),
              child: Text(data.label),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileAvatar extends StatelessWidget {
  const _ProfileAvatar({required this.url, required this.borderColor});

  final String url;
  final Color borderColor;

  Widget _fallback() => Icon(
        Icons.person_outline_rounded,
        size: 21,
        color: borderColor,
      );

  @override
  Widget build(BuildContext context) => Container(
        width: 24,
        height: 24,
        padding: const EdgeInsets.all(1),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: borderColor, width: 1.2),
        ),
        child: ClipOval(
          child: Image.network(
            url,
            width: 21,
            height: 21,
            fit: BoxFit.cover,
            loadingBuilder: (context, child, progress) =>
                progress == null ? child : _fallback(),
            errorBuilder: (context, error, stackTrace) => _fallback(),
          ),
        ),
      );
}
