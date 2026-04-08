import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';
import '../providers/theme_provider.dart';
import '../theme/apex_colors.dart';

class LucideBottomBar extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onTap;

  const LucideBottomBar({
    super.key,
    required this.selectedIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    final isDark = themeProvider.isDarkMode;
    final bgColor = isDark ? Colors.black : Colors.white;
    final textColor = isDark ? Colors.grey.shade400 : Colors.grey.shade600;

    // IDs and labels must match HomeScreen._onBottomBarTap mapping:
    // 0 -> ActivitiesPage, 1 -> UploadScreen, 2 -> Home, 3 -> ChatScreen, 4 -> FilieresPage
    final navItems = [
      {'id': 0, 'label': 'Upload', 'icon': LucideIcons.upload},
      {'id': 1, 'label': 'Entraide', 'icon': LucideIcons.users},
      {'id': 2, 'label': 'Home', 'icon': LucideIcons.home},
      {'id': 3, 'label': 'Chat', 'icon': LucideIcons.messageCircle},
      {'id': 4, 'label': 'Biblio', 'icon': LucideIcons.library},
    ];

    return Container(
      decoration: BoxDecoration(
        color: bgColor.withOpacity(0.96),
        border: Border(
          top: BorderSide(
            color: isDark ? Colors.grey.shade800 : Colors.grey.shade200,
            width: 0.6,
          ),
        ),
        boxShadow: const [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 8,
            offset: Offset(0, -2),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: navItems.map((item) {
          final isActive = selectedIndex == item['id'];

          return GestureDetector(
            onTap: () => onTap(item['id'] as int),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: isActive
                    ? ApexColors.primary.withOpacity(0.12)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    item['icon'] as IconData,
                    size: 26,
                    color: isActive ? ApexColors.primary : textColor,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    item['label'] as String,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: isActive ? ApexColors.primary : textColor,
                    ),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}
