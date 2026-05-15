import 'package:flutter/material.dart';
import 'package:hellovietnam/core/widgets/empty_state.dart';
import '../widgets/admin_section_header.dart';

class AdminCannedRepliesPage extends StatelessWidget {
  const AdminCannedRepliesPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const AdminSectionHeader(
          title: 'Canned Replies',
          subtitle: 'Manage pre-written responses for support',
        ),
        EmptyState(
          icon: Icons.chat_bubble_outline_rounded,
          message: 'No canned replies yet.',
        ),
      ],
    );
  }
}
