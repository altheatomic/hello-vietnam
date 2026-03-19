import 'package:flutter/material.dart';
import 'package:hellovietnam/core/widgets/empty_state.dart';
import '../widgets/admin_section_header.dart';

class AdminFeedbackPage extends StatelessWidget {
  const AdminFeedbackPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const AdminSectionHeader(
          title: 'Feedback',
          subtitle: 'Read feedback submitted by users',
        ),
        EmptyState(
          icon: Icons.feedback_outlined,
          message: 'No feedback submitted yet.',
        ),
      ],
    );
  }
}
