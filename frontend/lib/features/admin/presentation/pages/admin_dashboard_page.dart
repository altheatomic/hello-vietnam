import 'package:flutter/material.dart';
import 'package:hellovietnam/core/widgets/empty_state.dart';
import 'package:hellovietnam/features/admin/data/admin_dashboard_repository.dart';
import 'package:hellovietnam/features/admin/domain/admin_dashboard_models.dart';
import 'package:hellovietnam/features/admin/domain/admin_dashboard_repository.dart';
import 'package:hellovietnam/features/admin/presentation/widgets/admin_dashboard_widgets.dart';

class AdminDashboardPage extends StatefulWidget {
  const AdminDashboardPage({super.key, this.repository});

  final AdminDashboardRepository? repository;

  @override
  State<AdminDashboardPage> createState() => _AdminDashboardPageState();
}

class _AdminDashboardPageState extends State<AdminDashboardPage> {
  late Future<AdminDashboardSnapshot> _future;
  late final AdminDashboardRepository _repository;
  bool _isRefreshing = false;

  @override
  void initState() {
    super.initState();
    _repository = widget.repository ?? AdminDashboardRepositoryImpl();
    _future = _repository.fetchDashboardSnapshot();
  }

  Future<void> _refresh() async {
    setState(() => _isRefreshing = true);
    final nextFuture = _repository.fetchDashboardSnapshot(forceRefresh: true);
    setState(() {
      _future = nextFuture;
    });
    await nextFuture;
    if (!mounted) return;
    setState(() => _isRefreshing = false);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<AdminDashboardSnapshot>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return const _DashboardLoadingState();
        }

        if (snapshot.hasError) {
          return EmptyState(
            icon: Icons.dashboard_outlined,
            message:
                'Unable to load dashboard data right now.\nTry refreshing in a moment.',
          );
        }

        final data = snapshot.data;
        if (data == null) {
          return EmptyState(
            icon: Icons.dashboard_outlined,
            message: 'No dashboard data is available yet.',
          );
        }

        return AdminDashboardOverview(
          snapshot: data,
          onRefresh: _refresh,
          isRefreshing: _isRefreshing,
        );
      },
    );
  }
}

class _DashboardLoadingState extends StatelessWidget {
  const _DashboardLoadingState();

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        _LoadingBar(width: 180, height: 26),
        SizedBox(height: 10),
        _LoadingBar(width: 420, height: 14),
        SizedBox(height: 28),
        _LoadingCard(height: 210),
        SizedBox(height: 20),
        Wrap(
          spacing: 18,
          runSpacing: 18,
          children: <Widget>[
            _LoadingCard(width: 250, height: 190),
            _LoadingCard(width: 250, height: 190),
            _LoadingCard(width: 250, height: 190),
          ],
        ),
        SizedBox(height: 24),
        _LoadingCard(height: 320),
      ],
    );
  }
}

class _LoadingCard extends StatelessWidget {
  const _LoadingCard({this.width, required this.height});

  final double? width;
  final double height;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: const Color(0xFFE6EEF8)),
      ),
    );
  }
}

class _LoadingBar extends StatelessWidget {
  const _LoadingBar({required this.width, required this.height});

  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(999),
      ),
    );
  }
}
