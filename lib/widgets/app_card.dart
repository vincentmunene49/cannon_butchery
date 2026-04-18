import 'package:flutter/material.dart';
import '../app_theme.dart';

class AppCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final Color? color;
  final VoidCallback? onTap;
  final double? elevation;

  const AppCard({
    super.key,
    required this.child,
    this.padding,
    this.color,
    this.onTap,
    this.elevation,
  });

  @override
  Widget build(BuildContext context) {
    final card = Card(
      color: color ?? kCardBackground,
      elevation: elevation ?? kCardElevation,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(kCardRadius),
      ),
      child: Padding(
        padding: padding ?? const EdgeInsets.all(16),
        child: child,
      ),
    );

    if (onTap != null) {
      return InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(kCardRadius),
        child: card,
      );
    }
    return card;
  }
}

class SummaryCard extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;
  final IconData? icon;

  const SummaryCard({
    super.key,
    required this.label,
    required this.value,
    this.valueColor,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, color: kPrimary, size: 20),
            const SizedBox(height: 8),
          ],
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w500,
                ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: valueColor,
                ),
          ),
        ],
      ),
    );
  }
}
