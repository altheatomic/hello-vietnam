import 'package:flutter/material.dart';
import 'package:hellovietnam/core/widgets/empty_state.dart';
import '../widgets/admin_section_header.dart';

class AdminReportPage extends StatelessWidget {
  const AdminReportPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const AdminSectionHeader(
          title: 'Reports',
          subtitle: 'Review flagged content and user reports',
        ),
        EmptyState(
          icon: Icons.flag_outlined,
          message: 'No reports to review.',
        ),
      ],
    );
  }
}
