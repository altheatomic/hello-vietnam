import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hellovietnam/features/planner/data/trip_wizard_data.dart';
import 'package:hellovietnam/features/planner/presentation/widgets/planner_step_scaffold.dart';
import 'package:http/http.dart' as http;

class BusinessLocationPage extends StatefulWidget {
  const BusinessLocationPage({super.key});

  @override
  State<BusinessLocationPage> createState() => _BusinessLocationPageState();
}

class _BusinessLocationPageState extends State<BusinessLocationPage> {
  final TextEditingController _controller = TextEditingController();
  bool _isGeocoding = false;

  bool get _canContinue =>
      _controller.text.trim().length >= 3 && !_isGeocoding;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_handleTextChanged);
  }

  @override
  void dispose() {
    _controller
      ..removeListener(_handleTextChanged)
      ..dispose();
    super.dispose();
  }

  void _handleTextChanged() {
    setState(() {});
  }

  Future<void> _onNext() async {
    final address = _controller.text.trim();
    if (address.length < 3) return;

    setState(() => _isGeocoding = true);

    try {
      final uri = Uri.https('nominatim.openstreetmap.org', '/search', {
        'q': address,
        'format': 'json',
        'limit': '1',
        'countrycodes': 'vn',
      });

      final response = await http.get(
        uri,
        headers: {'User-Agent': 'HelloVietnam/1.0 (oanhlovescoding@gmail.com)'},
      );

      if (!mounted) return;

      if (response.statusCode != 200) {
        _showError('Không thể kết nối, thử lại sau.');
        return;
      }

      final List<dynamic> results =
          jsonDecode(response.body) as List<dynamic>;

      if (results.isEmpty) {
        _showError(
          'Không tìm thấy địa chỉ, thử nhập cụ thể hơn (vd: Quận 1, TP.HCM)',
        );
        return;
      }

      final first = results.first as Map<String, dynamic>;
      final lat = double.tryParse(first['lat'] as String? ?? '');
      final lng = double.tryParse(first['lon'] as String? ?? '');

      if (lat == null || lng == null) {
        _showError('Không thể xác định toạ độ, thử nhập cụ thể hơn.');
        return;
      }

      final wizard = TripWizardData(
        tripType: 'business',
        targetLat: lat,
        targetLng: lng,
        businessAddress: address,
      );

      if (!mounted) return;
      context.push('/trip-planner/duration', extra: wizard.toJson());
    } catch (_) {
      if (mounted) _showError('Không thể kết nối, thử lại sau.');
    } finally {
      if (mounted) setState(() => _isGeocoding = false);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
      ));
  }

  @override
  Widget build(BuildContext context) {
    return PlannerStepScaffold(
      currentStep: 2,
      badgeIcon: Icons.work_outline_rounded,
      title: 'Business Location',
      subtitle: 'Where will you be working?',
      onBack: () => context.pop(),
      nextEnabled: _canContinue,
      onNext: _onNext,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Text(
            'Enter address',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: Color(0xFF162235),
            ),
          ),
          const SizedBox(height: 14),
          _BusinessAddressField(controller: _controller),
          const SizedBox(height: 22),
          if (_isGeocoding)
            const Padding(
              padding: EdgeInsets.only(bottom: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2.5),
                  ),
                  SizedBox(width: 12),
                  Text(
                    'Đang tìm địa chỉ…',
                    style: TextStyle(
                      fontSize: 14,
                      color: Color(0xFF6F7B8A),
                    ),
                  ),
                ],
              ),
            ),
          const Text(
            'We will suggest activities around your business location\nduring free time',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              fontStyle: FontStyle.italic,
              color: Color(0xFF6F7B8A),
              height: 1.45,
            ),
          ),
          const Spacer(),
        ],
      ),
    );
  }
}

class _BusinessAddressField extends StatelessWidget {
  const _BusinessAddressField({required this.controller});

  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.96),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFC4F4FF), width: 1.6),
        boxShadow: const <BoxShadow>[
          BoxShadow(
            color: Color(0x260F2C4F),
            blurRadius: 28,
            offset: Offset(0, 14),
          ),
        ],
      ),
      child: TextField(
        controller: controller,
        style: const TextStyle(
          fontSize: 15.5,
          fontWeight: FontWeight.w500,
          color: Color(0xFF162235),
        ),
        decoration: const InputDecoration(
          prefixIcon: Icon(
            Icons.location_on_outlined,
            color: Color(0xFF9BA3B2),
            size: 22,
          ),
          hintText: 'e.g. District 1, Ho Chi Minh City',
          hintStyle: TextStyle(
            fontSize: 15.5,
            color: Color(0xFF9AA3B2),
            fontWeight: FontWeight.w500,
          ),
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(horizontal: 18, vertical: 18),
        ),
      ),
    );
  }
}
