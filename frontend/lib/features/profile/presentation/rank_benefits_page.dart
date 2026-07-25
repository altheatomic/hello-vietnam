import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class RankBenefitsPage extends StatefulWidget {
  const RankBenefitsPage({super.key});

  @override
  State<RankBenefitsPage> createState() => _RankBenefitsPageState();
}

class _RankBenefitsPageState extends State<RankBenefitsPage> {
  static const int _currentPoints = 45000;
  int? _expandedIndex;

  static const List<_TierBenefitData> _tiers = <_TierBenefitData>[
    _TierBenefitData(
      name: 'Bronze',
      requiredPoints: 0,
      subLabel: 'Starting tier',
      accentColor: Color(0xFFB97833),
      benefitBackground: Color(0xFFF2EBE2),
      benefits: <String>[
        'Earn points on every purchase',
        'Get latest offers and updates',
        '24/7 customer support',
      ],
      icon: Icons.workspace_premium_outlined,
    ),
    _TierBenefitData(
      name: 'Silver',
      requiredPoints: 10000,
      accentColor: Color(0xFFB8BCC2),
      benefitBackground: Color(0xFFECEEF2),
      benefits: <String>[
        'All Bronze tier benefits',
        'Free shipping on orders over \$20',
        'Earn 1.2x points per transaction',
      ],
      icon: Icons.star_border_rounded,
    ),
    _TierBenefitData(
      name: 'Gold',
      requiredPoints: 30000,
      isCurrent: true,
      accentColor: Color(0xFFFFBC00),
      benefitBackground: Color(0xFFF3F0DF),
      benefits: <String>[
        'All Silver tier benefits',
        'Special birthday gift',
        'Earn 1.5x points per transaction',
        'Priority customer support',
      ],
      icon: Icons.workspace_premium_rounded,
    ),
    _TierBenefitData(
      name: 'Platinum',
      requiredPoints: 70000,
      accentColor: Color(0xFF66C7F4),
      benefitBackground: Color(0xFFE8EFF8),
      benefits: <String>[
        'All Gold tier benefits',
        'Free shipping on all orders',
        'Earn 2x points per transaction',
        'Early access to new products',
        'Dedicated account manager',
      ],
      icon: Icons.workspace_premium_rounded,
    ),
    _TierBenefitData(
      name: 'Diamond',
      requiredPoints: 150000,
      accentColor: Color(0xFF8B2AC9),
      benefitBackground: Color(0xFFF1EAF7),
      benefits: <String>[
        'All Platinum tier benefits',
        'Earn 3x points per transaction',
        'Exclusive monthly vouchers',
        'Special offers from partners',
        'VIP exclusive events',
        '1-on-1 personalized consultation',
      ],
      icon: Icons.diamond_outlined,
    ),
  ];

  bool _isUnlocked(_TierBenefitData tier) =>
      _currentPoints >= tier.requiredPoints;

  String _formatPoints(int value) {
    final String raw = value.toString();
    final StringBuffer out = StringBuffer();
    for (int i = 0; i < raw.length; i++) {
      final int reverseIndex = raw.length - i;
      out.write(raw[i]);
      if (reverseIndex > 1 && reverseIndex % 3 == 1) {
        out.write(',');
      }
    }
    return out.toString();
  }

  @override
  Widget build(BuildContext context) {
    final double topInset = MediaQuery.of(context).padding.top;
    final double bottomInset = MediaQuery.of(context).padding.bottom;
    final ThemeData theme = Theme.of(context);
    final bool isDark = theme.brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SingleChildScrollView(
        padding: EdgeInsets.only(bottom: bottomInset + 120),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Stack(
              clipBehavior: Clip.none,
              children: <Widget>[
                Container(
                  width: double.infinity,
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: <Color>[Color(0xFF67C6F3), Color(0xFF5DC0F1)],
                    ),
                  ),
                  padding: EdgeInsets.fromLTRB(18, topInset + 10, 18, 88),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      IconButton(
                        onPressed: () => context.pop(),
                        icon: const Icon(
                          Icons.arrow_back_ios_new_rounded,
                          color: Colors.white,
                          size: 19,
                        ),
                        splashRadius: 20,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints.tightFor(
                          width: 30,
                          height: 30,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: <Widget>[
                          Icon(
                            Icons.workspace_premium_outlined,
                            color: Colors.white,
                            size: 23,
                          ),
                          SizedBox(width: 8),
                          Text(
                            'Tier Benefits',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 40,
                              height: 1,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      const Align(
                        alignment: Alignment.center,
                        child: Text(
                          'Discover and enjoy exclusive privileges at each membership tier',
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Color(0xFFDDF4FF),
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Positioned(
                  left: 18,
                  right: 18,
                  bottom: -42,
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: <Color>[
                          Color(0xFFFFD700),
                          Color(0xFFFFD300),
                          Color(0xFFFFD000),
                          Color(0xFFFFCC00),
                          Color(0xFFFFC900),
                          Color(0xFFFFC500),
                          Color(0xFFFFC200),
                          Color(0xFFFFBE00),
                          Color(0xFFFFBB00),
                          Color(0xFFFFB700),
                          Color(0xFFFFB400),
                          Color(0xFFFFB000),
                          Color(0xFFFFAC00),
                          Color(0xFFFFA900),
                          Color(0xFFFFA500),
                        ],
                        stops: <double>[
                          0.00,
                          0.07,
                          0.14,
                          0.21,
                          0.29,
                          0.36,
                          0.43,
                          0.50,
                          0.57,
                          0.64,
                          0.71,
                          0.79,
                          0.86,
                          0.93,
                          1.00,
                        ],
                      ),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Colors.white, width: 2),
                      boxShadow: <BoxShadow>[
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.12),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      children: <Widget>[
                        Container(
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                            color: const Color(
                              0xFFEAA700,
                            ).withValues(alpha: 0.42),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.workspace_premium_rounded,
                            color: Colors.white,
                            size: 17,
                          ),
                        ),
                        const SizedBox(width: 10),
                        const Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              'Your current tier',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            SizedBox(height: 2),
                            Text(
                              'Gold',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 39,
                                height: 1,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            SizedBox(height: 2),
                            Text(
                              '45,000 lifetime points',
                              style: TextStyle(
                                color: Color(0xFFFFF0C8),
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 56),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    'All Membership Tiers',
                    style: TextStyle(
                      fontSize: 33,
                      height: 1,
                      fontWeight: FontWeight.w700,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 12),
                  ...List<Widget>.generate(_tiers.length, (int index) {
                    final _TierBenefitData tier = _tiers[index];
                    final bool expanded = _expandedIndex == index;
                    final bool unlocked = _isUnlocked(tier);
                    return _TierCard(
                      tier: tier,
                      expanded: expanded,
                      unlocked: unlocked,
                      currentPoints: _currentPoints,
                      remainingPoints: math.max(
                        0,
                        tier.requiredPoints - _currentPoints,
                      ),
                      formattedCurrentPoints: _formatPoints(_currentPoints),
                      formattedRequiredPoints: _formatPoints(
                        tier.requiredPoints,
                      ),
                      onTap: () {
                        setState(() {
                          _expandedIndex = expanded ? null : index;
                        });
                      },
                    );
                  }),
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                    decoration: BoxDecoration(
                      color: isDark
                          ? theme.colorScheme.surfaceContainerHighest
                          : const Color(0xFFE5F5FC),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isDark
                            ? theme.colorScheme.outline
                            : const Color(0xFFD2E9F5),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Row(
                          children: <Widget>[
                            Icon(
                              Icons.lightbulb_outline_rounded,
                              size: 16,
                              color: Color(0xFFE8B954),
                            ),
                            SizedBox(width: 8),
                            Text(
                              'Important Notes',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: theme.colorScheme.onSurface,
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 10),
                        Text(
                          '- Available Points: Used to redeem vouchers, will decrease when redeemed',
                          style: TextStyle(
                            fontSize: 14,
                            height: 1.35,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          '- Lifetime Points: Determines membership tier, does not decrease when redeeming vouchers',
                          style: TextStyle(
                            fontSize: 14,
                            height: 1.35,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          '- You will never lose your membership tier when redeeming rewards',
                          style: TextStyle(
                            fontSize: 14,
                            height: 1.35,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TierCard extends StatelessWidget {
  const _TierCard({
    required this.tier,
    required this.expanded,
    required this.unlocked,
    required this.currentPoints,
    required this.remainingPoints,
    required this.formattedCurrentPoints,
    required this.formattedRequiredPoints,
    required this.onTap,
  });

  final _TierBenefitData tier;
  final bool expanded;
  final bool unlocked;
  final int currentPoints;
  final int remainingPoints;
  final String formattedCurrentPoints;
  final String formattedRequiredPoints;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final bool showProgress = tier.isCurrent;
    final bool showLockNeed = !unlocked && tier.requiredPoints > 0;
    final ThemeData theme = Theme.of(context);
    final bool isDark = theme.brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: tier.isCurrent
              ? const Color(0xFF68C6F3)
              : (isDark ? theme.colorScheme.outline : const Color(0xFFE3E7ED)),
          width: tier.isCurrent ? 1.6 : 1,
        ),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: <Widget>[
          InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 11, 10, 11),
              child: Row(
                children: <Widget>[
                  Container(
                    width: 25,
                    height: 25,
                    decoration: BoxDecoration(
                      color: tier.accentColor,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(tier.icon, size: 14, color: Colors.white),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Row(
                          children: <Widget>[
                            Text(
                              tier.name,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: theme.colorScheme.onSurface,
                              ),
                            ),
                            if (tier.isCurrent) ...<Widget>[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 7,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF8FD5F7),
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: const Text(
                                  'Current',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ] else if (unlocked) ...<Widget>[
                              const SizedBox(width: 6),
                              Container(
                                width: 16,
                                height: 16,
                                decoration: const BoxDecoration(
                                  color: Color(0xFFBFF0CF),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.check_rounded,
                                  size: 12,
                                  color: Color(0xFF2AA85F),
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          tier.requiredPoints == 0
                              ? tier.subLabel
                              : '$formattedRequiredPoints points',
                          style: TextStyle(
                            fontSize: 13,
                            color: theme.colorScheme.onSurfaceVariant,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  AnimatedRotation(
                    turns: expanded ? 0.5 : 0.0,
                    duration: const Duration(milliseconds: 240),
                    curve: Curves.easeInOutCubic,
                    child: Icon(
                      Icons.keyboard_arrow_up_rounded,
                      color: theme.colorScheme.onSurfaceVariant,
                      size: 20,
                    ),
                  ),
                ],
              ),
            ),
          ),
          ClipRect(
            child: AnimatedSize(
              duration: const Duration(milliseconds: 280),
              curve: Curves.easeInOutCubic,
              alignment: Alignment.topCenter,
              child: expanded
                  ? Column(
                      children: <Widget>[
                        const Divider(height: 1, color: Color(0xFFE8ECF1)),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              if (showProgress) ...<Widget>[
                                Row(
                                  children: <Widget>[
                                    Text(
                                      '$formattedCurrentPoints points',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color:
                                            theme.colorScheme.onSurfaceVariant,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const Spacer(),
                                    Text(
                                      '$formattedRequiredPoints points',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color:
                                            theme.colorScheme.onSurfaceVariant,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(99),
                                  child: LinearProgressIndicator(
                                    minHeight: 6,
                                    value: (currentPoints / tier.requiredPoints)
                                        .clamp(0, 1),
                                    backgroundColor: const Color(0xFFE0E5EC),
                                    valueColor:
                                        const AlwaysStoppedAnimation<Color>(
                                          Color(0xFFFFBC00),
                                        ),
                                  ),
                                ),
                                const SizedBox(height: 10),
                              ],
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.fromLTRB(
                                  10,
                                  9,
                                  10,
                                  9,
                                ),
                                decoration: BoxDecoration(
                                  color: isDark
                                      ? theme
                                            .colorScheme
                                            .surfaceContainerHighest
                                      : tier.benefitBackground,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: <Widget>[
                                    Text(
                                      'Benefits:',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                        color: theme.colorScheme.onSurface,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    ...tier.benefits.map((String benefit) {
                                      return Padding(
                                        padding: const EdgeInsets.only(
                                          bottom: 4,
                                        ),
                                        child: Row(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: <Widget>[
                                            Container(
                                              width: 14,
                                              height: 14,
                                              margin: const EdgeInsets.only(
                                                top: 1,
                                              ),
                                              decoration: BoxDecoration(
                                                color: tier.accentColor,
                                                shape: BoxShape.circle,
                                              ),
                                              child: const Icon(
                                                Icons.check_rounded,
                                                size: 10,
                                                color: Colors.white,
                                              ),
                                            ),
                                            const SizedBox(width: 6),
                                            Expanded(
                                              child: Text(
                                                benefit,
                                                style: TextStyle(
                                                  fontSize: 13,
                                                  height: 1.25,
                                                  color: theme
                                                      .colorScheme
                                                      .onSurfaceVariant,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      );
                                    }),
                                  ],
                                ),
                              ),
                              if (showLockNeed) ...<Widget>[
                                const SizedBox(height: 10),
                                const Divider(
                                  height: 1,
                                  color: Color(0xFFE8ECF1),
                                ),
                                const SizedBox(height: 8),
                                Center(
                                  child: RichText(
                                    text: TextSpan(
                                      style: TextStyle(
                                        fontSize: 13,
                                        color:
                                            theme.colorScheme.onSurfaceVariant,
                                        fontFamily: 'Roboto',
                                      ),
                                      children: <TextSpan>[
                                        const TextSpan(text: 'Need '),
                                        TextSpan(
                                          text: _withCommas(remainingPoints),
                                          style: const TextStyle(
                                            color: Color(0xFF67C6F3),
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                        const TextSpan(
                                          text: ' more points to unlock',
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    )
                  : const SizedBox.shrink(),
            ),
          ),
        ],
      ),
    );
  }

  String _withCommas(int value) {
    final String raw = value.toString();
    final StringBuffer out = StringBuffer();
    for (int i = 0; i < raw.length; i++) {
      final int reverseIndex = raw.length - i;
      out.write(raw[i]);
      if (reverseIndex > 1 && reverseIndex % 3 == 1) {
        out.write(',');
      }
    }
    return out.toString();
  }
}

class _TierBenefitData {
  const _TierBenefitData({
    required this.name,
    required this.requiredPoints,
    required this.accentColor,
    required this.benefitBackground,
    required this.benefits,
    required this.icon,
    this.subLabel = '',
    this.isCurrent = false,
  });

  final String name;
  final int requiredPoints;
  final String subLabel;
  final bool isCurrent;
  final Color accentColor;
  final Color benefitBackground;
  final List<String> benefits;
  final IconData icon;
}
