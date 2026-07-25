import 'package:flutter/material.dart';

import 'package:hellovietnam/app/theme.dart';

class ExploreFloatingBackButton extends StatelessWidget {
  final VoidCallback onTap;

  const ExploreFloatingBackButton({super.key, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.only(left: 12, top: 8),
        child: Align(
          alignment: Alignment.topLeft,
          child: Material(
            color: theme.colorScheme.surface.withValues(alpha: 0.94),
            elevation: 6,
            shadowColor: Colors.black.withValues(alpha: 0.12),
            shape: const CircleBorder(),
            child: InkWell(
              onTap: onTap,
              customBorder: const CircleBorder(),
              child: const SizedBox(
                width: 40,
                height: 40,
                child: Icon(
                  Icons.chevron_left,
                  size: 26,
                  color: AppColors.primary,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
