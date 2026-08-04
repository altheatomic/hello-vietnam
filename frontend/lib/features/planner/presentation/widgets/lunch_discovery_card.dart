import 'package:flutter/material.dart';
import 'package:hellovietnam/core/language/app_language.dart';

class LunchDiscoveryCard extends StatelessWidget {
  const LunchDiscoveryCard({
    super.key,
    required this.anchorName,
    required this.lunchWindow,
    required this.enabled,
    required this.onTap,
  });

  final String anchorName;
  final String lunchWindow;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool isDark = theme.brightness == Brightness.dark;
    final Color accent = isDark
        ? theme.colorScheme.primary
        : const Color(0xFF168FBD);
    final Color warmSurface = isDark
        ? Color.alphaBlend(
            const Color(0xFF8E5D36).withValues(alpha: 0.20),
            theme.colorScheme.surface,
          )
        : const Color(0xFFFFF8EA);

    return Container(
      key: const Key('lunch-discovery-card'),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: warmSurface,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: accent.withValues(alpha: 0.28), width: 2),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: isDark ? Colors.black26 : const Color(0x221B4965),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(Icons.restaurant_rounded, color: accent, size: 25),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  context.l10n.ui('What to eat nearby?'),
                  style: TextStyle(
                    color: theme.colorScheme.onSurface,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Text(
                lunchWindow,
                style: TextStyle(
                  color: accent,
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            '${context.l10n.ui('Explore restaurants near')} $anchorName',
            style: TextStyle(
              color: theme.colorScheme.onSurfaceVariant,
              fontSize: 15,
              height: 1.4,
            ),
          ),
          if (!enabled) ...<Widget>[
            const SizedBox(height: 8),
            Text(
              context.l10n.ui(
                'Restaurant search is unavailable for this location.',
              ),
              style: TextStyle(
                color: theme.colorScheme.error,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
          const SizedBox(height: 16),
          Opacity(
            opacity: enabled ? 1 : 0.45,
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: enabled ? onTap : null,
                borderRadius: BorderRadius.circular(999),
                child: Ink(
                  height: 48,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(999),
                    gradient: const LinearGradient(
                      colors: <Color>[Color(0xFF10C4E8), Color(0xFF4E98F7)],
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: <Widget>[
                      const Icon(Icons.map_outlined, color: Colors.white, size: 19),
                      const SizedBox(width: 9),
                      Flexible(
                        child: Text(
                          context.l10n.ui('View restaurants on Google Maps'),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
