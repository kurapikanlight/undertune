import 'package:flutter/material.dart';
import 'branding.dart';

class UndertuneAppBar extends StatelessWidget implements PreferredSizeWidget {
  const UndertuneAppBar({
    super.key,
    required this.onMenu,
    required this.onAdd,
    this.title,
    this.back = false,
    this.backLabel = 'Home',
  });
  final VoidCallback onMenu, onAdd;
  final String? title;
  final bool back;
  final String backLabel;
  @override
  Size get preferredSize => const Size.fromHeight(60);
  @override
  Widget build(BuildContext context) => AppBar(
    toolbarHeight: 60,
    centerTitle: true,
    titleSpacing: 0,
    leadingWidth: 64,
    scrolledUnderElevation: 0,
    leading: Padding(
      padding: const EdgeInsets.only(left: 8),
      child: IconButton(
        tooltip: back ? backLabel : 'Open menu',
        onPressed: onMenu,
        icon: Icon(
          back ? Icons.arrow_back : Icons.menu_rounded,
          semanticLabel: back ? backLabel : 'Open menu',
        ),
      ),
    ),
    title: title == null
        ? const BrandWordmark(width: 156)
        : Text(
            title!,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style:
                title == 'Search' ||
                    title == 'Videos' ||
                    title == 'Channel' ||
                    title == 'Album' ||
                    title == 'Music playlist' ||
                    title == 'Video playlist' ||
                    title == 'Your collection'
                ? feelfreeHeadingStyle.copyWith(
                    fontSize: title == 'Your collection' ? 44 : 36,
                  )
                : null,
          ),
    actions: [
      SizedBox(
        width: 64,
        child: Padding(
          padding: const EdgeInsets.only(right: 8),
          child: IconButton(
            tooltip: 'Create playlist',
            onPressed: onAdd,
            icon: const Icon(
              Icons.add_rounded,
              semanticLabel: 'Create playlist',
            ),
          ),
        ),
      ),
    ],
  );
}

class UndertuneNavigation extends StatelessWidget {
  static const double barHeight = 68 * .8;
  const UndertuneNavigation({
    super.key,
    required this.selectedIndex,
    required this.onSelected,
  });
  final int selectedIndex;
  final ValueChanged<int> onSelected;
  @override
  Widget build(BuildContext context) => NavigationBar(
    height: barHeight,
    selectedIndex: selectedIndex,
    onDestinationSelected: onSelected,
    destinations: const [
      NavigationDestination(
        icon: Icon(Icons.home_outlined),
        selectedIcon: Icon(Icons.home),
        label: 'Home',
      ),
      NavigationDestination(icon: Icon(Icons.search), label: 'Search'),
      NavigationDestination(
        icon: Icon(Icons.queue_music_outlined),
        selectedIcon: Icon(Icons.queue_music),
        label: 'Your Library',
      ),
    ],
  );
}
