import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:hellovietnam/core/language/app_language.dart';

class VoucherDetailPayload {
  const VoucherDetailPayload({
    required this.isOwnedVoucher,
    required this.tag,
    required this.title,
    required this.pointsRequired,
    required this.availablePoints,
    required this.validityDays,
    required this.voucherCode,
    required this.expiryDate,
    required this.descriptionLines,
    required this.imageColorA,
    required this.imageColorB,
  });

  final bool isOwnedVoucher;
  final String tag;
  final String title;
  final int pointsRequired;
  final int availablePoints;
  final int validityDays;
  final String voucherCode;
  final String expiryDate;
  final List<String> descriptionLines;
  final Color imageColorA;
  final Color imageColorB;
}

class VoucherDetailPage extends StatelessWidget {
  const VoucherDetailPage({super.key, required this.payload});

  final VoucherDetailPayload payload;

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

  Future<void> _copyCode(BuildContext context) async {
    await Clipboard.setData(ClipboardData(text: payload.voucherCode));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(context.l10n.ui('Voucher code copied')),
        duration: const Duration(milliseconds: 1200),
      ),
    );
  }

  Future<void> _showConfirmDialog(BuildContext context) async {
    await showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.52),
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: Text(context.l10n.ui('Confirm Redemption')),
          content: Text(
            context.l10n.redeemPointsConfirm(
              _formatPoints(payload.pointsRequired),
              context.l10n.ui(payload.title),
            ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text(context.l10n.ui('Cancel')),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text(context.l10n.ui('OK')),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final MediaQueryData mq = MediaQuery.of(context);
    final bool canRedeem = payload.availablePoints >= payload.pointsRequired;
    final int missingPoints = (payload.pointsRequired - payload.availablePoints)
        .clamp(0, 1 << 30)
        .toInt();

    return MediaQuery(
      data: mq.copyWith(textScaler: TextScaler.noScaling),
      child: Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        body: Column(
          children: <Widget>[
            Container(
              width: double.infinity,
              color: const Color(0xFF67C6F3),
              padding: EdgeInsets.fromLTRB(16, mq.padding.top + 8, 16, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  IconButton(
                    onPressed: () => context.pop(),
                    icon: const Icon(
                      Icons.arrow_back_ios_new_rounded,
                      size: 20,
                      color: Colors.white,
                    ),
                    splashRadius: 20,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints.tightFor(
                      width: 30,
                      height: 30,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: <Widget>[
                      const Icon(
                        Icons.card_giftcard_rounded,
                        color: Colors.white,
                        size: 24,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        context.l10n.ui('Voucher Details'),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.only(bottom: mq.padding.bottom + 120),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Stack(
                      children: <Widget>[
                        Container(
                          width: double.infinity,
                          height: 188,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: <Color>[
                                payload.imageColorA,
                                payload.imageColorB,
                              ],
                            ),
                          ),
                          child: const Center(
                            child: Icon(
                              Icons.image_outlined,
                              color: Color(0xCCFFFFFF),
                              size: 36,
                            ),
                          ),
                        ),
                        Positioned(
                          left: 20,
                          bottom: 12,
                          child: _DetailTagPill(
                            label: context.l10n.ui(payload.tag),
                          ),
                        ),
                      ],
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(22, 18, 22, 0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            context.l10n.ui(payload.title),
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF0D1E3A),
                            ),
                          ),
                          const SizedBox(height: 16),
                          if (payload.isOwnedVoucher) ...<Widget>[
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: const Color(0xFFEAF6FF),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: const Color(0xFFC7E8FF),
                                ),
                              ),
                              child: Column(
                                children: <Widget>[
                                  Row(
                                    children: <Widget>[
                                      Expanded(
                                        child: Text(
                                          context.l10n.ui('Voucher Code'),
                                          style: const TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ),
                                      InkWell(
                                        onTap: () => _copyCode(context),
                                        child: Row(
                                          children: <Widget>[
                                            const Icon(
                                              Icons.content_copy_rounded,
                                              size: 14,
                                              color: Color(0xFF6CBFED),
                                            ),
                                            const SizedBox(width: 4),
                                            Text(
                                              context.l10n.ui('Copy'),
                                              style: const TextStyle(
                                                fontSize: 13,
                                                color: Color(0xFF6CBFED),
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Container(
                                    width: double.infinity,
                                    alignment: Alignment.center,
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 12,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(
                                        color: const Color(0xFFC7E8FF),
                                      ),
                                    ),
                                    child: Text(
                                      payload.voucherCode,
                                      style: const TextStyle(
                                        fontSize: 32,
                                        fontWeight: FontWeight.w800,
                                        color: Color(0xFF0E1D35),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              context.l10n.expiryDate(payload.expiryDate),
                              style: const TextStyle(
                                fontSize: 14,
                                color: Color(0xFF2C3A53),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 16),
                            const _HowToUseCard(),
                            const SizedBox(height: 14),
                            const _ImportantNoticeCard(),
                          ] else ...<Widget>[
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.fromLTRB(
                                14,
                                14,
                                14,
                                12,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF7E7CC),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: const Color(0xFFF1CA88),
                                ),
                              ),
                              child: Column(
                                children: <Widget>[
                                  Row(
                                    children: <Widget>[
                                      const Icon(
                                        Icons.monetization_on_outlined,
                                        color: Color(0xFFF0A429),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        context.l10n.ui('Points required'),
                                        style: const TextStyle(
                                          fontSize: 14,
                                          color: Color(0xFF3E4B60),
                                        ),
                                      ),
                                      const Spacer(),
                                      Text(
                                        _formatPoints(payload.pointsRequired),
                                        style: const TextStyle(
                                          fontSize: 32,
                                          color: Color(0xFFF4A025),
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const Divider(
                                    height: 20,
                                    color: Color(0xFFEACB94),
                                  ),
                                  Row(
                                    children: <Widget>[
                                      Text(
                                        context.l10n.ui(
                                          'Your available points:',
                                        ),
                                        style: const TextStyle(
                                          fontSize: 16,
                                          color: Color(0xFF3B4759),
                                        ),
                                      ),
                                      const Spacer(),
                                      Text(
                                        _formatPoints(payload.availablePoints),
                                        style: TextStyle(
                                          fontSize: 24,
                                          color: canRedeem
                                              ? const Color(0xFF00B738)
                                              : const Color(0xFFE52525),
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ],
                                  ),
                                  if (!canRedeem) ...<Widget>[
                                    const SizedBox(height: 8),
                                    Text(
                                      context.l10n.needMorePoints(
                                        _formatPoints(missingPoints),
                                      ),
                                      style: const TextStyle(
                                        fontSize: 13,
                                        color: Color(0xFFE52F2F),
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              context.l10n.validForDays(payload.validityDays),
                              style: const TextStyle(
                                fontSize: 14,
                                color: Color(0xFF2C3A53),
                              ),
                            ),
                            const SizedBox(height: 16),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: const Color(0xFFDEE4EC),
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: <Widget>[
                                  Text(
                                    context.l10n.ui('Description'),
                                    style: const TextStyle(
                                      fontSize: 17,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  ...payload.descriptionLines.map(
                                    (String line) => Padding(
                                      padding: const EdgeInsets.only(bottom: 6),
                                      child: Text(
                                        '- ${context.l10n.ui(line)}',
                                        style: const TextStyle(
                                          fontSize: 14,
                                          height: 1.35,
                                          color: Color(0xFF1E2D43),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 22),
                            SizedBox(
                              width: double.infinity,
                              height: 56,
                              child: ElevatedButton(
                                onPressed: canRedeem
                                    ? () => _showConfirmDialog(context)
                                    : null,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: canRedeem
                                      ? const Color(0xFF81D4FA)
                                      : const Color(0xFFC6CDD8),
                                  foregroundColor: canRedeem
                                      ? Colors.white
                                      : const Color(0xFF647185),
                                  disabledBackgroundColor: const Color(
                                    0xFFC6CDD8,
                                  ),
                                  disabledForegroundColor: const Color(
                                    0xFF647185,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                ),
                                child: Text(
                                  context.l10n.ui(
                                    canRedeem
                                        ? 'Redeem Points'
                                        : 'Insufficient Points',
                                  ),
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HowToUseCard extends StatelessWidget {
  const _HowToUseCard();

  static const List<String> _steps = <String>[
    'Copy the voucher code above',
    'Apply the code at checkout',
    'Enjoy your discount or benefit',
    'Code can only be used once before expiry date',
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE0E6EE)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            context.l10n.ui('How to Use'),
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 10),
          ...List<Widget>.generate(_steps.length, (int index) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    '${index + 1}.',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF77C8F0),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      context.l10n.ui(_steps[index]),
                      style: const TextStyle(
                        fontSize: 15,
                        height: 1.3,
                        color: Color(0xFF1E2D43),
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _ImportantNoticeCard extends StatelessWidget {
  const _ImportantNoticeCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF7E8),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFF2C65F)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Icon(
            Icons.warning_amber_rounded,
            color: Color(0xFFF3A019),
            size: 20,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  context.l10n.ui('Important'),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  context.l10n.ui(
                    'This voucher cannot be exchanged for cash and is non-transferable. Please use before the expiration date.',
                  ),
                  style: const TextStyle(
                    fontSize: 14,
                    height: 1.35,
                    color: Color(0xFFD05B00),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailTagPill extends StatelessWidget {
  const _DetailTagPill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 12,
          color: Color(0xFF3E4B5B),
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
