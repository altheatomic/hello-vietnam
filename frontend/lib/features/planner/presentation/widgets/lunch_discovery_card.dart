import 'package:flutter/material.dart';

class LunchDiscoveryCard extends StatelessWidget {
  const LunchDiscoveryCard({
    super.key,
    required this.anchorName,
    required this.enabled,
    this.onTap,
  });

  final String anchorName;
  final bool enabled;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    final String title = enabled
        ? 'Find restaurants near $anchorName'
        : 'Restaurants near $anchorName';

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: colors.surface.withValues(alpha: 0.97),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: enabled ? const Color(0xFF2EBEFB) : colors.outline,
          width: 2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(
                Icons.restaurant_outlined,
                color: enabled ? const Color(0xFF159FD5) : colors.outline,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    color: colors.onSurface,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            enabled
                ? 'Open Google Maps to see nearby restaurants.'
                : 'Restaurant search is unavailable for this location.',
            style: TextStyle(
              color: colors.onSurfaceVariant,
              fontSize: 14,
              height: 1.4,
            ),
          ),
          if (enabled) ...<Widget>[
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: onTap,
                icon: const Icon(Icons.open_in_new_rounded, size: 18),
                label: const Text('View restaurants on Google Maps'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
