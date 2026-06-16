import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:hellovietnam/features/loyalty/data/loyalty_award_service.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../media/cloudflare_media_repository.dart';

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
    if (_user != null) {
      unawaited(
        LoyaltyAwardService.instance.award(
          actionType: 'daily_login',
          description: 'Daily login',
        ),
      );
    }
    _authSubscription = _supabase.auth.onAuthStateChange.listen((data) {
      _user = data.session?.user;
      if (_user != null) {
        unawaited(
          LoyaltyAwardService.instance.award(
            actionType: 'daily_login',
            description: 'Daily login',
          ),
        );
      }
      notifyListeners();
    });
  }

  final _supabase = Supabase.instance.client;
  final CloudflareMediaRepository _mediaRepository =
      CloudflareMediaRepository();
  User? _user;
  late final StreamSubscription<AuthState> _authSubscription;

  User? get user => _user;
  bool get isLoggedIn => _user != null;
  String? get currentUserEmail => _user?.email;

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
        'avatars/$userId/avatar_${DateTime.now().microsecondsSinceEpoch}$extension';

    final CloudflareMediaUpload uploaded = await _mediaRepository.uploadBytes(
      bytes: bytes,
      folder: _folderFromPath(storagePath),
      fileName: _fileNameFromPath(storagePath),
      contentType: _mimeTypeFromExtension(extension),
    );

    await _saveCurrentUserAvatarUrl(
      userId: userId,
      avatarUrl: uploaded.url,
      email: currentUser?.email?.trim(),
      fullName: (currentUser?.userMetadata?['full_name'] as String?)?.trim(),
    );

    await _deleteAvatarPaths(
      <String>{
        ..._avatarCandidatePaths(userId),
        if (previousAvatarPath != null && previousAvatarPath.isNotEmpty)
          previousAvatarPath,
      }..remove(storagePath),
    );

    return uploaded.url;
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
    'avatars/$userId/avatar.jpg',
    'avatars/$userId/avatar.jpeg',
    'avatars/$userId/avatar.png',
    'avatars/$userId/avatar.webp',
    'avatars/$userId/avatar.gif',
    'Avatar/$userId/avatar.jpg',
    'Avatar/$userId/avatar.jpeg',
    'Avatar/$userId/avatar.png',
    'Avatar/$userId/avatar.webp',
    'Avatar/$userId/avatar.gif',
  };

  Future<void> _deleteAvatarPaths(Set<String> paths) async {
    final List<String> sanitized = paths
        .where((String path) => path.trim().isNotEmpty)
        .map((String path) => _mediaRepository.keyFromUrlOrPath(path))
        .whereType<String>()
        .toSet()
        .toList();
    if (sanitized.isEmpty) return;
    await _mediaRepository.deleteKeys(sanitized);
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

    return _mediaRepository.publicUrlForKey(avatarPath);
  }

  String? _avatarPathFromStoredAvatar(String? avatarValue) {
    if (avatarValue == null || avatarValue.isEmpty) return null;
    return _mediaRepository.keyFromUrlOrPath(avatarValue);
  }

  String _folderFromPath(String path) {
    final int slashIndex = path.lastIndexOf('/');
    if (slashIndex <= 0) return '';
    return path.substring(0, slashIndex);
  }

  String _fileNameFromPath(String path) {
    final int slashIndex = path.lastIndexOf('/');
    if (slashIndex == -1 || slashIndex == path.length - 1) {
      return 'avatar.jpg';
    }
    return path.substring(slashIndex + 1);
  }

  String _mimeTypeFromExtension(String extension) {
    switch (extension.toLowerCase()) {
      case '.png':
        return 'image/png';
      case '.webp':
        return 'image/webp';
      case '.gif':
        return 'image/gif';
      case '.jpeg':
      case '.jpg':
      default:
        return 'image/jpeg';
    }
  }
}
