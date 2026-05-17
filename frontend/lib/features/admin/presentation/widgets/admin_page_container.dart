import 'package:flutter/material.dart';
import 'package:hellovietnam/app/theme.dart';

/// Scrollable content area that wraps every admin page body.
///
/// Provides:
///   - [AppColors.background] (#F5FAFF) fill — the same scaffold background
///     used by mobile screens, scaled to fill the remaining desktop area.
///   - 24 px uniform padding (desktop density, up from mobile's pagePadding 16).
///   - Vertical scroll so pages can exceed the visible height.
///
/// Usage — place inside the [Expanded] region of AdminShell:
/// ```dart
/// Expanded(child: AdminPageContainer(child: pageContent))
/// ```
class AdminPageContainer extends StatelessWidget {
  const AdminPageContainer({super.key, required this.child});

  final Widget child;

  /// Desktop content padding. Wider than mobile's AppConstants.pagePadding
  /// (16 px) to account for the extra breathing room on large screens.
  static const double contentPadding = 24;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppColors.background,
      child: LayoutBuilder(
        builder: (context, constraints) {
          return Scrollbar(
            thumbVisibility: true,
            child: SingleChildScrollView(
              primary: true,
              padding: const EdgeInsets.all(contentPadding),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minWidth: constraints.maxWidth - (contentPadding * 2),
                  minHeight: constraints.maxHeight - (contentPadding * 2),
                ),
                child: Align(alignment: Alignment.topLeft, child: child),
              ),
            ),
          );
        },
      ),
    );
  }
}
