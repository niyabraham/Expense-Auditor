import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class DashboardHeader extends StatelessWidget implements PreferredSizeWidget {
  final VoidCallback onLogout;
  final String title;

  const DashboardHeader({
    super.key,
    required this.onLogout,
    this.title = "Overview",
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: preferredSize.height,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      decoration: const BoxDecoration(
        color: AppTheme.background,
        border: Border(
          bottom: BorderSide(color: AppTheme.border, width: 1),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: AppTheme.foreground,
            ),
          ),
          Row(
            children: [
              // Search Bar Mock
              Container(
                width: 240,
                height: 36,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: AppTheme.secondary,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppTheme.border),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.search, size: 16, color: AppTheme.mutedForeground),
                    SizedBox(width: 8),
                    Text(
                      "Search...",
                      style: TextStyle(color: AppTheme.mutedForeground, fontSize: 13),
                    )
                  ],
                ),
              ),
              const SizedBox(width: 16),
              
              // Notifications
              IconButton(
                onPressed: () {},
                icon: const Icon(Icons.notifications_none, color: AppTheme.mutedForeground),
                splashRadius: 20,
              ),
              
              // Logout
              IconButton(
                onPressed: onLogout,
                icon: const Icon(Icons.logout, color: AppTheme.mutedForeground),
                tooltip: "Logout",
                splashRadius: 20,
              ),
              
              const SizedBox(width: 16),
              
              // Profile
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppTheme.primary,
                  borderRadius: BorderRadius.circular(8),
                  image: const DecorationImage(
                    image: NetworkImage("https://i.pravatar.cc/150?u=a042581f4e29026704d"),
                    fit: BoxFit.cover,
                  ),
                ),
              )
            ],
          )
        ],
      ),
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(70);
}
