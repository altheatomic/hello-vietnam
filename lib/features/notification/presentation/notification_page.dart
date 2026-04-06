import 'package:flutter/material.dart';

class NotificationPage extends StatefulWidget {
  const NotificationPage({super.key});

  @override
  State<NotificationPage> createState() => _NotificationPageState();
}

class _NotificationPageState extends State<NotificationPage> {
  final List<_NotificationItem> _notifications = <_NotificationItem>[
    const _NotificationItem(
      icon: '🎉',
      title: "Data's got new festival!",
      message: "Don't miss the chance to go to\nthe Flower Festival.",
      timeAgo: '9 days ago',
      type: 'FORUM',
    ),
    const _NotificationItem(
      icon: '✅',
      title: 'You got new replies',
      message: 'Brandon has just comment on\nyour post',
      timeAgo: '13 days ago',
      type: 'ACCOUNT',
    ),
    const _NotificationItem(
      icon: '🍜',
      title: 'Fresh Flavors Unveiled!',
      message: 'New menu items are in! What will\nyou try next?',
      timeAgo: '4 days ago',
      type: 'TRIP',
    ),
    const _NotificationItem(
      icon: '🙌',
      title: 'How was your trips?',
      message: 'Tell us how satisfied you are on\nyour 3-days trips in Ho Chi Minh\nCity!!',
      timeAgo: '1 week ago',
      type: 'TRIP',
    ),
    const _NotificationItem(
      icon: '🎟',
      title: 'You got a new voucher!!',
      message: 'Get 10% off on for your premium\nsubscription',
      timeAgo: '11 days ago',
      type: 'VOUCHER',
    ),
  ];

  Set<String> _activeFilters = <String>{};

  static const List<String> _filterTypes = <String>[
    'FORUM',
    'VOUCHER',
    'ACCOUNT',
    'TRIP',
  ];

  List<_NotificationItem> get _visibleNotifications {
    if (_activeFilters.isEmpty) {
      return _notifications;
    }
    return _notifications
        .where((item) => _activeFilters.contains(item.type))
        .toList();
  }

  Future<void> _openFilters() async {
    final Set<String> draftFilters = Set<String>.from(_activeFilters);

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) {
        final MediaQueryData media = MediaQuery.of(context);
        final double bottomSafeInset = media.viewPadding.bottom;
        final double sheetHeight = media.size.height * 0.45;
        final double targetHeight = sheetHeight < 340 ? 340 : sheetHeight;

        return StatefulBuilder(
          builder: (BuildContext context, void Function(void Function()) setModalState) {
            return SafeArea(
              top: false,
              bottom: false,
              child: Container(
                height: targetHeight,
                padding: EdgeInsets.fromLTRB(18, 10, 18, bottomSafeInset + 14),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Align(
                      alignment: Alignment.topCenter,
                      child: Container(
                        width: 44,
                        height: 4,
                        decoration: BoxDecoration(
                          color: const Color(0xFFB8C3CF),
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 40,
                      child: Stack(
                        alignment: Alignment.center,
                        children: <Widget>[
                          Align(
                            alignment: Alignment.centerLeft,
                            child: TextButton(
                              onPressed: () {
                                setModalState(() {
                                  draftFilters.clear();
                                });
                              },
                              child: const Text(
                                'Clear All',
                                style: TextStyle(
                                  color: Color(0xFF2AAEEB),
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                          const Text(
                            'Filters',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF1E1E1E),
                            ),
                          ),
                          Align(
                            alignment: Alignment.centerRight,
                            child: IconButton(
                              onPressed: () => Navigator.of(context).pop(),
                              icon: const Icon(Icons.close, size: 20),
                              color: const Color(0xFF1E1E1E),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Notification type',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1E1E1E),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: <Widget>[
                        _buildFilterChip(
                          label: 'ALL',
                          selected: draftFilters.isEmpty,
                          onTap: () {
                            setModalState(() {
                              draftFilters.clear();
                            });
                          },
                        ),
                        ..._filterTypes.map((String type) {
                          return _buildFilterChip(
                            label: type,
                            selected: draftFilters.contains(type),
                            onTap: () {
                              setModalState(() {
                                if (draftFilters.contains(type)) {
                                  draftFilters.remove(type);
                                } else {
                                  draftFilters.add(type);
                                }
                              });
                            },
                          );
                        }),
                      ],
                    ),
                    const Spacer(),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF81D4FA),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 13),
                          elevation: 0,
                        ),
                        onPressed: () {
                          setState(() {
                            _activeFilters = Set<String>.from(draftFilters);
                          });
                          Navigator.of(context).pop();
                        },
                        child: Text(
                          'Apply Filters (${draftFilters.length})',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildFilterChip({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF81D4FA) : const Color(0xFFF0F0F0),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : const Color(0xFF9A9A9A),
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final List<_NotificationItem> items = _visibleNotifications;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              SizedBox(
                height: 52,
                child: Stack(
                  children: <Widget>[
                    Align(
                      alignment: Alignment.centerLeft,
                      child: IconButton(
                        onPressed: () => Navigator.of(context).maybePop(),
                        icon: const Icon(
                          Icons.arrow_back_ios_new_rounded,
                          color: Color(0xFF101010),
                          size: 20,
                        ),
                        tooltip: 'Back',
                      ),
                    ),
                    const Align(
                      alignment: Alignment.center,
                      child: Text(
                        'Notification',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF101010),
                        ),
                      ),
                    ),
                    Align(
                      alignment: Alignment.centerRight,
                      child: IconButton(
                        onPressed: _openFilters,
                        tooltip: 'Filters',
                        icon: const Icon(
                          Icons.filter_alt_outlined,
                          color: Color(0xFF2AAEEB),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: items.isEmpty
                    ? const _EmptyState()
                    : ListView.separated(
                        itemBuilder: (BuildContext context, int index) {
                          final _NotificationItem item = items[index];
                          return _NotificationTile(item: item);
                        },
                        separatorBuilder: (BuildContext context, int index) =>
                            const SizedBox(height: 12),
                        itemCount: items.length,
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NotificationTile extends StatelessWidget {
  const _NotificationTile({required this.item});

  final _NotificationItem item;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        SizedBox(
          width: 26,
          child: Text(
            item.icon,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 19),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                item.title,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1A1A1A),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                item.message,
                style: const TextStyle(
                  fontSize: 13,
                  color: Color(0xFF8A8A8A),
                  height: 1.25,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Text(
          item.timeAgo,
          style: const TextStyle(
            fontSize: 11,
            color: Color(0xFFB3B3B3),
          ),
        ),
      ],
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: const <Widget>[
          Icon(
            Icons.chat_bubble_outline_rounded,
            size: 46,
            color: Color(0xFFC0C0C0),
          ),
          SizedBox(height: 12),
          Text(
            'No Notifications',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: Color(0xFF1F1F1F),
            ),
          ),
          SizedBox(height: 6),
          Text(
            "We'll let you know when there will be\nsomething to update you.",
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              color: Color(0xFF9A9A9A),
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }
}

class _NotificationItem {
  const _NotificationItem({
    required this.icon,
    required this.title,
    required this.message,
    required this.timeAgo,
    required this.type,
  });

  final String icon;
  final String title;
  final String message;
  final String timeAgo;
  final String type;
}
