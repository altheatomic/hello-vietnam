import 'package:supabase_flutter/supabase_flutter.dart';

enum AppReportCategory {
  contentReport('content_report'),
  bugReport('bug_report'),
  suggestion('suggestion'),
  accountIssue('account_issue'),
  paymentIssue('payment_issue');

  const AppReportCategory(this.storageValue);

  final String storageValue;
}

enum AppReportTargetType {
  food('food'),
  culture('culture'),
  activity('activity'),
  localProduct('local_product'),
  place('place'),
  province('province'),
  feature('feature'),
  system('system'),
  userAccount('user_account');

  const AppReportTargetType(this.storageValue);

  final String storageValue;
}

class ReportSubmission {
  const ReportSubmission({
    required this.category,
    this.targetType,
    this.targetId,
    this.featureArea,
    this.content,
    this.images = const <Map<String, dynamic>>[],
  });

  final AppReportCategory category;
  final AppReportTargetType? targetType;
  final String? targetId;
  final String? featureArea;
  final String? content;
  final List<Map<String, dynamic>> images;
}

class ReportRepository {
  ReportRepository({SupabaseClient? client})
    : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  Future<String> submitReport(ReportSubmission submission) async {
    final String? userId = await _ensureCurrentUserAccount();
    final Map<String, dynamic> payload =
        <String, dynamic>{
          'id_user': userId,
          'report_category': submission.category.storageValue,
          'target_type': submission.targetType?.storageValue,
          'target_id': submission.targetId,
          'feature_area': submission.featureArea,
          'report_content': submission.content?.trim(),
          'images': submission.images,
          'status': 'pending',
        }..removeWhere((String key, Object? value) {
          if (value == null) return true;
          if (value is String && value.trim().isEmpty) return true;
          if (value is List && value.isEmpty) return true;
          return false;
        });

    final Map<String, dynamic> row = await _client
        .from('report')
        .insert(payload)
        .select('id_report')
        .single();

    return row['id_report'].toString();
  }

  Future<String?> _ensureCurrentUserAccount() async {
    final User? user = _client.auth.currentUser;
    if (user == null) return null;

    final String userId = user.id;
    final String? email = user.email?.trim();
    final String? fullName =
        (user.userMetadata?['full_name'] as String?)?.trim() ??
        (user.userMetadata?['name'] as String?)?.trim();

    final Map<String, dynamic>? existing = await _client
        .from('user_account')
        .select('id_user, full_name, username')
        .eq('id_user', userId)
        .maybeSingle();

    if (existing == null) {
      await _client.from('user_account').insert(<String, dynamic>{
        'id_user': userId,
        if (fullName != null && fullName.isNotEmpty) 'full_name': fullName,
        if (email != null && email.isNotEmpty) 'username': email,
      });
      return userId;
    }

    final String existingFullName =
        existing['full_name']?.toString().trim() ?? '';
    final String existingUsername =
        existing['username']?.toString().trim() ?? '';
    if ((existingFullName.isEmpty && fullName != null && fullName.isNotEmpty) ||
        (existingUsername.isEmpty && email != null && email.isNotEmpty)) {
      await _client
          .from('user_account')
          .update(<String, dynamic>{
            if (existingFullName.isEmpty &&
                fullName != null &&
                fullName.isNotEmpty)
              'full_name': fullName,
            if (existingUsername.isEmpty && email != null && email.isNotEmpty)
              'username': email,
          })
          .eq('id_user', userId);
    }

    return userId;
  }
}
