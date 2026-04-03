import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class StatsCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final double change;
  final String changeLabel;
  final bool positiveTrend;
  final Color iconColor;

  const StatsCard({
    super.key,
    required this.title,
    required this.value,
    required this.icon,
    this.change = 0,
    this.changeLabel = "from last month",
    this.positiveTrend = true,
    this.iconColor = AppTheme.primary,
  });

  @override
  Widget build(BuildContext context) {
    // Determine the trend color. (If positive trend is good, it's green. If it's bad, it's red).
    final trendColor = positiveTrend ? AppTheme.success : AppTheme.destructive;
    final trendIcon = change >= 0 ? Icons.arrow_upward : Icons.arrow_downward;
    final changeDisplay = "${change.abs()}%";

    return Card(
      shadowColor: Colors.black.withOpacity(0.05),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      color: AppTheme.mutedForeground,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Icon(icon, color: iconColor, size: 20),
              ],
            ),
            const Spacer(),
            Text(
              value,
              style: const TextStyle(
                color: AppTheme.foreground,
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
            ),
            const Spacer(),
            Row(
              children: [
                if (change != 0) ...[
                  Icon(trendIcon, color: trendColor, size: 14),
                  const SizedBox(width: 4),
                  Text(
                    changeDisplay,
                    style: TextStyle(
                      color: trendColor,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                Expanded(
                  child: Text(
                    changeLabel,
                    style: const TextStyle(
                      color: AppTheme.mutedForeground,
                      fontSize: 12,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
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
