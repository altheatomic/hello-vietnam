import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hellovietnam/app/router.dart';
import 'package:hellovietnam/core/language/app_language.dart';
import 'package:hellovietnam/features/profile/presentation/voucher_detail_page.dart';

class VoucherPage extends StatefulWidget {
  const VoucherPage({super.key});

  @override
  State<VoucherPage> createState() => _VoucherPageState();
}

class _VoucherPageState extends State<VoucherPage> {
  bool _showMyVouchers = false;
  static const int _availablePoints = 12500;

  static const List<_VoucherItem> _redeemVouchers = <_VoucherItem>[
    _VoucherItem(
      tag: 'Discount',
      title: '\$5 off on orders over \$20',
      pointsRequired: 5000,
      code: 'SAVE5',
      expiry: '30/04/2026',
      validityDays: 30,
      descriptionLines: <String>[
        'Special discount voucher for orders valued at \$20 or more',
        'Valid for all products regardless of category',
        'Can be combined with free shipping voucher',
        'Maximum discount of \$5 per order',
      ],
      imageColorA: Color(0xFF5B6073),
      imageColorB: Color(0xFF202736),
    ),
    _VoucherItem(
      tag: 'Shipping',
      title: 'Free nationwide shipping',
      pointsRequired: 3000,
      code: 'FREESHIP',
      expiry: '25/03/2026',
      validityDays: 25,
      descriptionLines: <String>[
        'Apply free delivery to eligible orders nationwide',
        'No minimum order value required in selected zones',
        'Cannot be combined with another shipping voucher',
      ],
      imageColorA: Color(0xFF6398BB),
      imageColorB: Color(0xFF204D6C),
    ),
    _VoucherItem(
      tag: 'Discount',
      title: '\$10 off on orders over \$50',
      pointsRequired: 8000,
      code: 'SAVE10',
      expiry: '12/05/2026',
      validityDays: 45,
      descriptionLines: <String>[
        'Special discount voucher for orders valued at \$50 or more',
        'Valid for all products regardless of category',
        'Can be combined with free shipping voucher',
        'Maximum discount of \$10 per order',
      ],
      imageColorA: Color(0xFF905070),
      imageColorB: Color(0xFF39213A),
    ),
    _VoucherItem(
      tag: 'Gift',
      title: 'Free gift with purchase',
      pointsRequired: 4000,
      code: 'GIFT2026',
      expiry: '15/05/2026',
      validityDays: 50,
      descriptionLines: <String>[
        'Receive one surprise gift with qualifying purchase',
        'Gift value may vary by campaign and stock',
        'Voucher can be redeemed once per account',
      ],
      imageColorA: Color(0xFFC36969),
      imageColorB: Color(0xFF6D3131),
    ),
    _VoucherItem(
      tag: 'Premium',
      title: '\$20 Premium voucher',
      pointsRequired: 15000,
      code: 'PREMIUM200',
      expiry: '31/07/2026',
      validityDays: 60,
      descriptionLines: <String>[
        'Premium voucher with \$20 discount for Premium package',
        'Upgrade your experience with exclusive features',
        '24/7 priority support from specialists',
        'Many special benefits exclusively for Premium members',
        'Can renew and accumulate more benefits',
      ],
      imageColorA: Color(0xFFC98AD9),
      imageColorB: Color(0xFF6A418E),
    ),
    _VoucherItem(
      tag: 'Cashback',
      title: '20% cashback up to 80K',
      pointsRequired: 6000,
      code: 'CASHBACK20',
      expiry: '20/06/2026',
      validityDays: 35,
      descriptionLines: <String>[
        'Get 20% cashback on eligible orders (max 80K)',
        'Cashback is credited within 24 hours after completion',
        'Can be combined with selected platform offers',
      ],
      imageColorA: Color(0xFFB1A396),
      imageColorB: Color(0xFF665549),
    ),
  ];

  static const List<_VoucherItem> _myVouchers = <_VoucherItem>[
    _VoucherItem(
      tag: 'Discount',
      title: '\$5 off on orders over \$20',
      pointsRequired: 0,
      code: 'SAVE5',
      expiry: '30/04/2026',
      validityDays: 30,
      descriptionLines: <String>[
        'Special discount voucher for orders valued at \$20 or more',
      ],
      imageColorA: Color(0xFF5B6073),
      imageColorB: Color(0xFF202736),
    ),
    _VoucherItem(
      tag: 'Shipping',
      title: 'Free nationwide shipping',
      pointsRequired: 0,
      code: 'FREESHIP',
      expiry: '25/03/2026',
      validityDays: 25,
      descriptionLines: <String>[
        'Apply free delivery to eligible orders nationwide',
      ],
      imageColorA: Color(0xFF6398BB),
      imageColorB: Color(0xFF204D6C),
    ),
    _VoucherItem(
      tag: 'Gift',
      title: 'Free gift with purchase',
      pointsRequired: 0,
      code: 'GIFT2026',
      expiry: '15/05/2026',
      validityDays: 50,
      descriptionLines: <String>[
        'Receive one surprise gift with qualifying purchase',
      ],
      imageColorA: Color(0xFFC36969),
      imageColorB: Color(0xFF6D3131),
    ),
  ];

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

  void _openVoucherDetail(_VoucherItem item) {
    context.push(
      AppRoutes.voucherDetail,
      extra: VoucherDetailPayload(
        isOwnedVoucher: false,
        tag: item.tag,
        title: item.title,
        pointsRequired: item.pointsRequired,
        availablePoints: _availablePoints,
        validityDays: item.validityDays,
        voucherCode: item.code,
        expiryDate: item.expiry,
        descriptionLines: item.descriptionLines,
        imageColorA: item.imageColorA,
        imageColorB: item.imageColorB,
      ),
    );
  }

  void _openMyVoucherDetail(_VoucherItem item) {
    context.push(
      AppRoutes.voucherDetail,
      extra: VoucherDetailPayload(
        isOwnedVoucher: true,
        tag: item.tag,
        title: item.title,
        pointsRequired: item.pointsRequired,
        availablePoints: _availablePoints,
        validityDays: item.validityDays,
        voucherCode: item.code,
        expiryDate: item.expiry,
        descriptionLines: item.descriptionLines,
        imageColorA: item.imageColorA,
        imageColorB: item.imageColorB,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final MediaQueryData mq = MediaQuery.of(context);
    return MediaQuery(
      data: mq.copyWith(textScaler: TextScaler.noScaling),
      child: Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        body: CustomScrollView(
          slivers: <Widget>[
            SliverAppBar(
              pinned: true,
              backgroundColor: const Color(0xFF67C6F3),
              elevation: 0,
              toolbarHeight: 54,
              automaticallyImplyLeading: false,
              titleSpacing: 0,
              title: SizedBox(
                height: 34,
                child: Stack(
                  alignment: Alignment.center,
                  children: <Widget>[
                    Align(
                      alignment: Alignment.centerLeft,
                      child: IconButton(
                        onPressed: () => context.pop(),
                        icon: const Icon(
                          Icons.arrow_back_ios_new_rounded,
                          size: 18,
                          color: Colors.white,
                        ),
                        splashRadius: 20,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints.tightFor(
                          width: 30,
                          height: 30,
                        ),
                      ),
                    ),
                    Text(
                      context.l10n.ui('Reward'),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: _RewardHeroSection(
                onViewBenefits: () => context.push(AppRoutes.rankBenefits),
              ),
            ),
            SliverPersistentHeader(
              pinned: true,
              delegate: _VoucherPinnedHeaderDelegate(
                showMyVouchers: _showMyVouchers,
                onSelectRedeem: () {
                  if (_showMyVouchers) {
                    setState(() {
                      _showMyVouchers = false;
                    });
                  }
                },
                onSelectMyVoucher: () {
                  if (!_showMyVouchers) {
                    setState(() {
                      _showMyVouchers = true;
                    });
                  }
                },
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 24),
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 260),
                  switchInCurve: Curves.easeOutCubic,
                  switchOutCurve: Curves.easeInCubic,
                  transitionBuilder:
                      (Widget child, Animation<double> animation) {
                        return FadeTransition(
                          opacity: animation,
                          child: SizeTransition(
                            sizeFactor: animation,
                            axisAlignment: -1,
                            child: child,
                          ),
                        );
                      },
                  child: _showMyVouchers
                      ? _MyVoucherList(
                          key: const ValueKey<String>('my-vouchers'),
                          items: _myVouchers,
                          onOpenDetail: _openMyVoucherDetail,
                        )
                      : _RedeemVoucherGrid(
                          key: const ValueKey<String>('redeem-vouchers'),
                          items: _redeemVouchers,
                          formatPoints: _formatPoints,
                          onOpenDetail: _openVoucherDetail,
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RewardProfileRow extends StatelessWidget {
  const _RewardProfileRow();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        const _AvatarCircle(),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const Text(
                'John Anderson',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Row(
                children: <Widget>[
                  const _TierIcon(),
                  const SizedBox(width: 6),
                  Text(
                    context.l10n.ui('Gold Tier'),
                    style: const TextStyle(
                      color: Color(0xFFFFE08B),
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _RewardHeroSection extends StatelessWidget {
  const _RewardHeroSection({required this.onViewBenefits});

  final VoidCallback onViewBenefits;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 346,
      child: Stack(
        children: <Widget>[
          Column(
            children: <Widget>[
              Container(
                height: 164,
                width: double.infinity,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: <Color>[Color(0xFF67C6F3), Color(0xFF68C6F3)],
                  ),
                ),
              ),
              Expanded(
                child: Container(
                  color: Theme.of(context).scaffoldBackgroundColor,
                ),
              ),
            ],
          ),
          const Positioned(
            left: 14,
            right: 14,
            top: 16,
            child: _RewardProfileRow(),
          ),
          Positioned(
            left: 14,
            right: 14,
            top: 82,
            child: _RewardSummaryCard(onViewBenefits: onViewBenefits),
          ),
        ],
      ),
    );
  }
}

class _AvatarCircle extends StatelessWidget {
  const _AvatarCircle();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 52,
      height: 52,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2),
      ),
      child: const Icon(Icons.person, color: Color(0xFF7A7A7A), size: 26),
    );
  }
}

class _TierIcon extends StatelessWidget {
  const _TierIcon();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 24,
      height: 24,
      decoration: const BoxDecoration(
        color: Color(0xFFFFC234),
        shape: BoxShape.circle,
      ),
      child: const Icon(
        Icons.workspace_premium_rounded,
        size: 14,
        color: Colors.white,
      ),
    );
  }
}

class _RewardSummaryCard extends StatelessWidget {
  const _RewardSummaryCard({required this.onViewBenefits});

  final VoidCallback onViewBenefits;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 14),
            decoration: BoxDecoration(
              color: const Color(0xFF67C6F3),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  context.l10n.ui('Available Points'),
                  style: const TextStyle(
                    fontSize: 16,
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  '12,500',
                  style: TextStyle(
                    fontSize: 52,
                    height: 0.95,
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  context.l10n.ui('Use to redeem vouchers'),
                  style: const TextStyle(
                    fontSize: 15,
                    color: Colors.white,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: <Widget>[
              const _TierIcon(),
              const SizedBox(width: 6),
              Text(
                context.l10n.ui('Gold'),
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              const Spacer(),
              TextButton(
                onPressed: onViewBenefits,
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text(
                  context.l10n.ui('View Benefits >'),
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF67C6F3),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: const LinearProgressIndicator(
              value: 0.64,
              minHeight: 9,
              backgroundColor: Color(0xFFD6DCE3),
              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF67C6F3)),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  context.l10n.ui('45,000 / 70,000 pts'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              SizedBox(width: 8),
              Expanded(
                child: Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    context.l10n.ui('25,000 to Platinum'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF67C6F3),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _VoucherPinnedHeaderDelegate extends SliverPersistentHeaderDelegate {
  _VoucherPinnedHeaderDelegate({
    required this.showMyVouchers,
    required this.onSelectRedeem,
    required this.onSelectMyVoucher,
  });

  final bool showMyVouchers;
  final VoidCallback onSelectRedeem;
  final VoidCallback onSelectMyVoucher;

  @override
  double get minExtent => 112;

  @override
  double get maxExtent => 112;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return Container(
      color: Theme.of(context).scaffoldBackgroundColor,
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              const Icon(
                Icons.card_giftcard_rounded,
                size: 19,
                color: Color(0xFF81D4FA),
              ),
              const SizedBox(width: 8),
              Text(
                context.l10n.ui('Vouchers'),
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _VoucherTabs(
            showMyVouchers: showMyVouchers,
            onSelectRedeem: onSelectRedeem,
            onSelectMyVoucher: onSelectMyVoucher,
          ),
        ],
      ),
    );
  }

  @override
  bool shouldRebuild(covariant _VoucherPinnedHeaderDelegate oldDelegate) {
    return oldDelegate.showMyVouchers != showMyVouchers;
  }
}

class _VoucherTabs extends StatelessWidget {
  const _VoucherTabs({
    required this.showMyVouchers,
    required this.onSelectRedeem,
    required this.onSelectMyVoucher,
  });

  final bool showMyVouchers;
  final VoidCallback onSelectRedeem;
  final VoidCallback onSelectMyVoucher;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 46,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: const Color(0xFFEFF1F4),
          borderRadius: BorderRadius.circular(11),
        ),
        child: Stack(
          children: <Widget>[
            AnimatedAlign(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeInOutCubic,
              alignment: showMyVouchers
                  ? Alignment.centerRight
                  : Alignment.centerLeft,
              child: FractionallySizedBox(
                widthFactor: 0.5,
                child: Padding(
                  padding: const EdgeInsets.all(3),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(9),
                      boxShadow: <BoxShadow>[
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.07),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            Row(
              children: <Widget>[
                Expanded(
                  child: _TabTextButton(
                    label: context.l10n.ui('Redeem Voucher'),
                    selected: !showMyVouchers,
                    onTap: onSelectRedeem,
                  ),
                ),
                Expanded(
                  child: _TabTextButton(
                    label: context.l10n.ui('My Vouchers (3)'),
                    selected: showMyVouchers,
                    onTap: onSelectMyVoucher,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _TabTextButton extends StatelessWidget {
  const _TabTextButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Center(
        child: AnimatedDefaultTextStyle(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: selected ? const Color(0xFF67C6F3) : const Color(0xFF35465E),
          ),
          child: Text(label),
        ),
      ),
    );
  }
}

class _RedeemVoucherGrid extends StatelessWidget {
  const _RedeemVoucherGrid({
    super.key,
    required this.items,
    required this.onOpenDetail,
    required this.formatPoints,
  });

  final List<_VoucherItem> items;
  final ValueChanged<_VoucherItem> onOpenDetail;
  final String Function(int value) formatPoints;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: items.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 10,
        mainAxisSpacing: 12,
        mainAxisExtent: 230,
      ),
      itemBuilder: (BuildContext context, int index) {
        final _VoucherItem item = items[index];
        return _RedeemVoucherCard(
          item: item,
          onTap: () => onOpenDetail(item),
          formattedPoints: formatPoints(item.pointsRequired),
        );
      },
    );
  }
}

class _RedeemVoucherCard extends StatelessWidget {
  const _RedeemVoucherCard({
    required this.item,
    required this.onTap,
    required this.formattedPoints,
  });

  final _VoucherItem item;
  final VoidCallback onTap;
  final String formattedPoints;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: colors.outlineVariant),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Stack(
                children: <Widget>[
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(12),
                    ),
                    child: Container(
                      height: 94,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: <Color>[item.imageColorA, item.imageColorB],
                        ),
                      ),
                      child: const Center(
                        child: Icon(
                          Icons.image_outlined,
                          color: Color(0xCCFFFFFF),
                          size: 24,
                        ),
                      ),
                    ),
                  ),
                  Positioned(top: 7, left: 8, child: _TagPill(label: item.tag)),
                ],
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 9, 10, 5),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    SizedBox(
                      height: 34,
                      child: Align(
                        alignment: Alignment.topLeft,
                        child: Text(
                          context.l10n.ui(item.title),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: colors.onSurface,
                            height: 1.2,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: <Widget>[
                        const Icon(
                          Icons.monetization_on_outlined,
                          size: 13,
                          color: Color(0xFFF0A429),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          formattedPoints,
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFFF0A429),
                            height: 1,
                          ),
                        ),
                        const SizedBox(width: 2),
                        Text(
                          context.l10n.ui('points'),
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w500,
                            color: colors.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    SizedBox(
                      width: double.infinity,
                      height: 31,
                      child: ElevatedButton(
                        onPressed: onTap,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF81D4FA),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(9),
                          ),
                          padding: EdgeInsets.zero,
                        ),
                        child: Text(
                          context.l10n.ui('Redeem Now'),
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MyVoucherList extends StatelessWidget {
  const _MyVoucherList({
    super.key,
    required this.items,
    required this.onOpenDetail,
  });

  final List<_VoucherItem> items;
  final ValueChanged<_VoucherItem> onOpenDetail;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: items.length,
      separatorBuilder: (BuildContext context, int index) =>
          const SizedBox(height: 12),
      itemBuilder: (BuildContext context, int index) {
        final _VoucherItem item = items[index];
        return _MyVoucherCard(item: item, onTap: () => onOpenDetail(item));
      },
    );
  }
}

class _MyVoucherCard extends StatelessWidget {
  const _MyVoucherCard({required this.item, required this.onTap});

  final _VoucherItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: colors.outlineVariant),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 7,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            children: <Widget>[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      width: 88,
                      height: 88,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: <Color>[item.imageColorA, item.imageColorB],
                        ),
                      ),
                      child: const Center(
                        child: Icon(
                          Icons.image_outlined,
                          color: Color(0xCCFFFFFF),
                          size: 24,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        _TagPill(label: item.tag),
                        const SizedBox(height: 8),
                        Text(
                          context.l10n.ui(item.title),
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: colors.onSurface,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: <Widget>[
                            Icon(
                              Icons.calendar_today_rounded,
                              size: 14,
                              color: colors.onSurfaceVariant,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              '${context.l10n.ui('Exp')}: ${item.expiry}',
                              style: TextStyle(
                                fontSize: 14,
                                color: colors.onSurfaceVariant,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 9),
                        Row(
                          children: <Widget>[
                            Expanded(
                              child: Container(
                                height: 34,
                                alignment: Alignment.centerLeft,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                ),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(9),
                                  border: Border.all(
                                    color: colors.outlineVariant,
                                  ),
                                ),
                                child: Text(
                                  item.code,
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    color: colors.onSurface,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Icon(
                              Icons.content_copy_rounded,
                              color: colors.onSurfaceVariant,
                              size: 19,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                height: 36,
                child: ElevatedButton(
                  onPressed: onTap,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF81D4FA),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: Text(
                    context.l10n.ui('Use Now'),
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TagPill extends StatelessWidget {
  const _TagPill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: const Color(0xFFE9F7FF),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          const Icon(
            Icons.local_offer_outlined,
            size: 11,
            color: Color(0xFF6AA9CC),
          ),
          const SizedBox(width: 4),
          Text(
            context.l10n.ui(label),
            style: const TextStyle(
              fontSize: 13,
              color: Color(0xFF6AA9CC),
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _VoucherItem {
  const _VoucherItem({
    required this.tag,
    required this.title,
    required this.pointsRequired,
    required this.code,
    required this.expiry,
    required this.validityDays,
    required this.descriptionLines,
    required this.imageColorA,
    required this.imageColorB,
  });

  final String tag;
  final String title;
  final int pointsRequired;
  final String code;
  final String expiry;
  final int validityDays;
  final List<String> descriptionLines;
  final Color imageColorA;
  final Color imageColorB;
}
