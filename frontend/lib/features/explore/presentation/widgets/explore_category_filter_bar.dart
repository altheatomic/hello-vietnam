import 'dart:ui';

import 'package:flutter/material.dart';

class ExploreCategoryFilterBar extends StatelessWidget {
  const ExploreCategoryFilterBar({
    super.key,
    required this.labels,
    required this.selectedIndex,
    required this.onSelected,
  });

  static const double height = 44;

  final List<String> labels;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    return SizedBox(
      height: height,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: labels.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (BuildContext context, int index) {
          final bool isSelected = index == selectedIndex;
          final BorderRadius radius = BorderRadius.circular(18);

          return Semantics(
            button: true,
            selected: isSelected,
            child: SizedBox(
              height: height,
              child: ClipRRect(
                borderRadius: radius,
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () => onSelected(index),
                      borderRadius: radius,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 220),
                        curve: Curves.easeOutCubic,
                        alignment: Alignment.center,
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        decoration: BoxDecoration(
                          gradient: _gradient(isSelected, isDark),
                          borderRadius: radius,
                          border: Border.all(
                            color: isSelected
                                ? Colors.white.withValues(alpha: 0.48)
                                : isDark
                                ? Colors.white.withValues(alpha: 0.14)
                                : Colors.white.withValues(alpha: 0.78),
                          ),
                          boxShadow: <BoxShadow>[
                            BoxShadow(
                              color: isSelected
                                  ? const Color(
                                      0xFF38AEEA,
                                    ).withValues(alpha: 0.22)
                                  : Colors.black.withValues(
                                      alpha: isDark ? 0.18 : 0.05,
                                    ),
                              blurRadius: isSelected ? 14 : 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Text(
                          labels[index],
                          maxLines: 1,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.15,
                            color: isSelected
                                ? Colors.white
                                : isDark
                                ? Colors.white.withValues(alpha: 0.82)
                                : const Color(0xFF62666B),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  LinearGradient _gradient(bool isSelected, bool isDark) {
    if (isSelected) {
      return LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: <Color>[
          const Color(0xFF73D0F8).withValues(alpha: 0.94),
          const Color(0xFF35ABE7).withValues(alpha: 0.88),
        ],
      );
    }

    return LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: isDark
          ? <Color>[
              Colors.white.withValues(alpha: 0.12),
              Colors.white.withValues(alpha: 0.06),
            ]
          : <Color>[
              Colors.white.withValues(alpha: 0.72),
              const Color(0xFFEAF7FD).withValues(alpha: 0.56),
            ],
    );
  }
}
