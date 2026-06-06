import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/env.dart';

class CurrentUserProfileData {
  const CurrentUserProfileData({
    required this.fullName,
    required this.username,
    required this.email,
    required this.avatarPath,
    required this.avatarUrl,
  });

  final String? fullName;
  final String? username;
  final String? email;
  final String? avatarPath;
  final String? avatarUrl;
}

class AuthRepository extends ChangeNotifier {
  // Singleton
  static final AuthRepository instance = AuthRepository._();

  AuthRepository._() {
    _user = _supabase.auth.currentUser;
    _authSubscription = _supabase.auth.onAuthStateChange.listen((data) {
      _user = data.session?.user;
      notifyListeners();
    });
  }

  final _supabase = Supabase.instance.client;
  late final SupabaseClient _avatarStorageClient = Env.hasExternalAvatarStorage
      ? SupabaseClient(Env.avatarStorageProjectUrl, Env.avatarStorageAnonKey)
      : _supabase;
  User? _user;
  late final StreamSubscription<AuthState> _authSubscription;

  User? get user => _user;
  bool get isLoggedIn => _user != null;
  String? get currentUserEmail => _user?.email;
  String get _avatarBucket => Env.avatarStorageBucket;
  bool get _usesExternalAvatarStorage => Env.hasExternalAvatarStorage;

  Future<CurrentUserProfileData?> getCurrentUserProfile() async {
    final currentUser = _user ?? _supabase.auth.currentUser;
    final userId = currentUser?.id;
    if (userId == null) return null;

    String? fullName;
    String? username;
    String? avatarPath;

    try {
      final Map<String, dynamic>? response = await _supabase
          .from('user_account')
          .select('full_name, username, avatar')
          .eq('id_user', userId)
          .maybeSingle();

      fullName = (response?['full_name'] as String?)?.trim();
      username = (response?['username'] as String?)?.trim();
      avatarPath = (response?['avatar'] as String?)?.trim();
    } catch (e) {
      debugPrint('Load current user profile error: $e');
    }

    fullName ??= (currentUser?.userMetadata?['full_name'] as String?)?.trim();
    username ??= currentUser?.email?.trim();

    return CurrentUserProfileData(
      fullName: fullName,
      username: username,
      email: currentUser?.email?.trim(),
      avatarPath: avatarPath,
      avatarUrl: await _resolveAvatarUrl(avatarPath),
    );
  }

  Future<String?> getCurrentUserFullName() async {
    return (await getCurrentUserProfile())?.fullName;
  }

  Future<String?> uploadCurrentUserAvatar(XFile file) async {
    final currentUser = _user ?? _supabase.auth.currentUser;
    final userId = currentUser?.id;
    if (userId == null) {
      throw Exception('USER_NOT_FOUND: Khong tim thay user dang dang nhap.');
    }

    final CurrentUserProfileData? profile = await getCurrentUserProfile();
    final String? previousAvatarPath = _avatarPathFromStoredAvatar(
      profile?.avatarPath,
    );
    final Uint8List bytes = await file.readAsBytes();
    final String extension = _extractFileExtension(file);
    final String storagePath =
        previousAvatarPath != null && previousAvatarPath.isNotEmpty
        ? previousAvatarPath
        : 'Avatar/$userId/avatar$extension';

    if (previousAvatarPath == null || previousAvatarPath.isEmpty) {
      final Set<String> stalePaths = <String>{..._avatarCandidatePaths(userId)}
        ..remove(storagePath);
      await _deleteAvatarPaths(stalePaths);
    }

    await _avatarStorageClient.storage
        .from(_avatarBucket)
        .uploadBinary(
          storagePath,
          bytes,
          fileOptions: const FileOptions(upsert: true),
        );

    final String avatarUrl = _avatarUrlFromPath(storagePath);

    await _saveCurrentUserAvatarUrl(
      userId: userId,
      avatarUrl: avatarUrl,
      email: currentUser?.email?.trim(),
      fullName: (currentUser?.userMetadata?['full_name'] as String?)?.trim(),
    );

    return avatarUrl;
  }

  Future<void> clearCurrentUserAvatar() async {
    final currentUser = _user ?? _supabase.auth.currentUser;
    final userId = currentUser?.id;
    if (userId == null) {
      throw Exception('USER_NOT_FOUND: Khong tim thay user dang dang nhap.');
    }

    final CurrentUserProfileData? profile = await getCurrentUserProfile();
    final String? previousAvatarPath = _avatarPathFromStoredAvatar(
      profile?.avatarPath,
    );

    await _supabase
        .from('user_account')
        .update(<String, dynamic>{'avatar': null})
        .eq('id_user', userId);

    await _deleteAvatarPaths(<String>{
      ..._avatarCandidatePaths(userId),
      if (previousAvatarPath != null && previousAvatarPath.isNotEmpty)
        previousAvatarPath,
    });
  }

  Future<void> signIn({required String email, required String password}) async {
    try {
      await _supabase.auth.signInWithPassword(email: email, password: password);
    } on AuthException catch (e) {
      // Handle error
      debugPrint(e.message);
      rethrow;
    }
  }

  Future<void> adminSignIn({
    required String email,
    required String password,
  }) async {
    try {
      // First, sign in with credentials
      await _supabase.auth.signInWithPassword(email: email, password: password);

      // Then verify user has admin role
      final currentUser = _supabase.auth.currentUser;
      if (currentUser == null) {
        await _supabase.auth.signOut();
        throw Exception('USER_NOT_FOUND: Failed to retrieve user information');
      }

      // Check role in user_account table
      final response = await _supabase
          .from('user_account')
          .select('role')
          .eq('id_user', currentUser.id)
          .maybeSingle();

      final role = response?['role'] as String?;

      if (role != 'admin') {
        // Sign out if not admin
        await _supabase.auth.signOut();
        throw Exception(
          'NOT_ADMIN: Only administrators can access this portal',
        );
      }
    } on AuthException catch (e) {
      debugPrint('Admin sign in error: ${e.message}');
      rethrow;
    } catch (e) {
      debugPrint('Admin sign in error: $e');
      rethrow;
    }
  }

  Future<void> signInWithGoogle() async {
    try {
      final String redirectTo = kIsWeb
          ? Uri.base.origin
          : 'com.example.hellovietnam://login-callback';

      await _supabase.auth.signInWithOAuth(
        OAuthProvider.google,
        redirectTo: redirectTo,
        authScreenLaunchMode: LaunchMode.externalApplication,
      );
    } on AuthException catch (e) {
      debugPrint(e.message);
      rethrow;
    }
  }

  Future<void> signUp({
    required String name,
    required String email,
    required String password,
  }) async {
    try {
      final response = await _supabase.auth.signUp(
        email: email,
        password: password,
        data: {'full_name': name},
      );
      final user = response.user;
      if (user != null) {
        await _supabase.from('user_account').insert({
          'id_user': user.id,
          'full_name': name,
          'username': email,
        });
        await _supabase.from('user_contact').upsert({
          'id_user': user.id,
          'email': email,
        });
      }
    } on AuthException catch (e) {
      // Handle error
      debugPrint(e.message);
      rethrow;
    }
  }

  Future<void> signOut() async {
    await _supabase.auth.signOut();
  }

  Future<void> resetPassword({required String email}) async {
    try {
      await _supabase.auth.resetPasswordForEmail(
        email,
        redirectTo: kIsWeb ? null : 'com.example.hellovietnam://reset-password',
      );
    } on AuthException catch (e) {
      debugPrint('Reset password error: ${e.message}');

      // Create more specific error messages
      if (e.message.contains('rate limit') ||
          e.message.contains('Rate limit')) {
        throw Exception(
          'RATE_LIMIT: Too many reset emails sent. Please wait 1 hour before trying again.',
        );
      } else if (e.message.contains('Invalid email')) {
        throw Exception('INVALID_EMAIL: Please enter a valid email address.');
      } else {
        throw Exception('RESET_FAILED: ${e.message}');
      }
    }
  }

  Future<void> updatePassword({required String newPassword}) async {
    try {
      await _supabase.auth.updateUser(UserAttributes(password: newPassword));
    } on AuthException catch (e) {
      debugPrint('Update password error: ${e.message}');
      rethrow;
    }
  }

  @override
  void dispose() {
    _authSubscription.cancel();
    super.dispose();
  }

  String _extractFileExtension(XFile file) {
    final String source = file.name.isNotEmpty ? file.name : file.path;
    final int dotIndex = source.lastIndexOf('.');
    if (dotIndex == -1 || dotIndex == source.length - 1) {
      return '.jpg';
    }
    return source.substring(dotIndex).toLowerCase();
  }

  Set<String> _avatarCandidatePaths(String userId) => <String>{
    'Avatar/$userId/avatar.jpg',
    'Avatar/$userId/avatar.jpeg',
    'Avatar/$userId/avatar.png',
    'Avatar/$userId/avatar.webp',
    'Avatar/$userId/avatar.gif',
  };

  Future<void> _deleteAvatarPaths(Set<String> paths) async {
    final List<String> sanitized = paths
        .where((String path) => path.trim().isNotEmpty)
        .map((String path) => path.trim())
        .toSet()
        .toList();
    if (sanitized.isEmpty) return;
    try {
      await _avatarStorageClient.storage.from(_avatarBucket).remove(sanitized);
    } catch (e) {
      if (!_usesExternalAvatarStorage) {
        debugPrint('Delete avatar paths warning: $e');
      }
    }
  }

  Future<void> _saveCurrentUserAvatarUrl({
    required String userId,
    required String avatarUrl,
    required String? email,
    required String? fullName,
  }) async {
    final Map<String, dynamic>? existingByUserId = await _supabase
        .from('user_account')
        .select('id_user')
        .eq('id_user', userId)
        .maybeSingle();

    if (existingByUserId != null) {
      await _supabase
          .from('user_account')
          .update(<String, dynamic>{'avatar': avatarUrl})
          .eq('id_user', userId);
      return;
    }

    if (email != null && email.isNotEmpty) {
      final Map<String, dynamic>? existingByUsername = await _supabase
          .from('user_account')
          .select('id_user, username')
          .eq('username', email)
          .maybeSingle();

      if (existingByUsername != null) {
        await _supabase
            .from('user_account')
            .update(<String, dynamic>{'avatar': avatarUrl})
            .eq('username', email);
        return;
      }
    }

    try {
      await _supabase.from('user_account').insert(<String, dynamic>{
        'id_user': userId,
        'avatar': avatarUrl,
        if (email != null && email.isNotEmpty) 'username': email,
        if (fullName != null && fullName.isNotEmpty) 'full_name': fullName,
      });
    } on PostgrestException catch (error) {
      final String message = error.message.toLowerCase();
      final bool duplicateUsername =
          error.code == '23505' &&
          message.contains('user_account_username_key');

      if (!duplicateUsername || email == null || email.isEmpty) {
        rethrow;
      }

      // If a row with the same username exists but wasn't visible earlier,
      // fall back to updating it directly instead of failing the avatar save.
      await _supabase
          .from('user_account')
          .update(<String, dynamic>{'avatar': avatarUrl})
          .eq('username', email);
    }
  }

  Future<String?> _resolveAvatarUrl(String? avatarPath) async {
    if (avatarPath == null || avatarPath.isEmpty) return null;
    if (avatarPath.startsWith('http://') || avatarPath.startsWith('https://')) {
      return avatarPath;
    }

    if (_usesExternalAvatarStorage) {
      try {
        return _avatarStorageClient.storage
            .from(_avatarBucket)
            .getPublicUrl(avatarPath);
      } catch (e) {
        debugPrint('Resolve external avatar url error: $e');
      }
    }

    try {
      return await _avatarStorageClient.storage
          .from(_avatarBucket)
          .createSignedUrl(avatarPath, 60 * 60 * 24 * 30);
    } catch (_) {
      try {
        return _avatarStorageClient.storage
            .from(_avatarBucket)
            .getPublicUrl(avatarPath);
      } catch (e) {
        debugPrint('Resolve avatar url error: $e');
        return null;
      }
    }
  }

  String _avatarUrlFromPath(String avatarPath) {
    return _avatarStorageClient.storage
        .from(_avatarBucket)
        .getPublicUrl(avatarPath);
  }

  String? _avatarPathFromStoredAvatar(String? avatarValue) {
    if (avatarValue == null || avatarValue.isEmpty) return null;
    if (!avatarValue.startsWith('http://') &&
        !avatarValue.startsWith('https://')) {
      return avatarValue;
    }

    final String publicPrefix =
        '${Env.avatarStorageProjectUrl}/storage/v1/object/public/$_avatarBucket/';
    final String signPrefix =
        '${Env.avatarStorageProjectUrl}/storage/v1/object/sign/$_avatarBucket/';

    if (avatarValue.startsWith(publicPrefix)) {
      return Uri.decodeComponent(avatarValue.substring(publicPrefix.length));
    }

    if (avatarValue.startsWith(signPrefix)) {
      final String withoutPrefix = avatarValue.substring(signPrefix.length);
      final int queryIndex = withoutPrefix.indexOf('?');
      final String rawPath = queryIndex == -1
          ? withoutPrefix
          : withoutPrefix.substring(0, queryIndex);
      return Uri.decodeComponent(rawPath);
    }

    final Uri? uri = Uri.tryParse(avatarValue);
    if (uri == null) return null;
    final List<String> segments = uri.pathSegments;
    final int bucketIndex = segments.indexOf(_avatarBucket);
    if (bucketIndex == -1 || bucketIndex == segments.length - 1) {
      return null;
    }
    return Uri.decodeComponent(segments.sublist(bucketIndex + 1).join('/'));
  }
}
