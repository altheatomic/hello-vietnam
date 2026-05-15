import 'package:flutter/material.dart';
import 'package:hellovietnam/core/widgets/empty_state.dart';
import '../widgets/admin_section_header.dart';

class AdminDashboardPage extends StatelessWidget {
  const AdminDashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const AdminSectionHeader(
          title: 'Dashboard',
          subtitle: 'Overview of your platform activity',
        ),
        EmptyState(
          icon: Icons.dashboard_outlined,
          message: 'Dashboard widgets coming soon.',
        ),
      ],
    );
  }
}
