import 'dart:async';
import 'package:geolocator/geolocator.dart';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/error/exceptions.dart';
import '../models/user_model.dart';
import '../../../../core/services/location_helper.dart';

abstract class AuthRemoteDataSource {
  Future<UserModel> register({
    required String email,
    required String password,
    required String name,
    required String phone,
    required String userType,
  });

  Future<UserModel> login({
    required String email,
    required String password,
  });

  Future<UserModel> loginWithGoogle();
  Future<UserModel> loginWithApple();
  Future<void> logout();
  Future<UserModel?> getCurrentUser();
  Future<bool> isAuthenticated();

  Future<UserModel> updateProfile({
    required String userId,
    String? name,
    String? phone,
    double? latitude,
    double? longitude,
    String? address,
  });

  Future<String> uploadProfilePhoto({
    required String userId,
    required String filePath,
  });

  Stream<UserModel?> get authStateChanges;

  Future<void> updateUserType(String userId, String newType);
  Future<void> createArtisanProfileIfNeeded(String userId);
  Future<void> requestAccountDeletion({required String reason});
}

class AuthRemoteDataSourceImpl implements AuthRemoteDataSource {
  final SupabaseClient client;

  AuthRemoteDataSourceImpl(
      {required this.client, required Object supabaseClient});

  static const String _mobileAuthRedirect = String.fromEnvironment(
    'AUTH_REDIRECT_MOBILE',
    defaultValue: 'io.supabase.artisanmarketplace://login-callback/',
  );

  static const String _webAuthRedirect = String.fromEnvironment(
    'AUTH_REDIRECT_WEB',
    defaultValue: '',
  );

  static const String _googleWebClientId = String.fromEnvironment(
    'GOOGLE_WEB_CLIENT_ID',
    defaultValue: '',
  );

  String _resolveRedirectUrl() {
    if (!kIsWeb) return _mobileAuthRedirect;
    if (_webAuthRedirect.isNotEmpty) return _webAuthRedirect;
    return Uri.base.origin;
  }

  Future<Map<String, dynamic>> _buildLocationFields() async {
    if (kIsWeb) return <String, dynamic>{};

    final locationData = await LocationHelper.getLocationData();
    final position = locationData['position'] as Position?;
    final address = locationData['address'] as String?;

    if (position == null) return <String, dynamic>{};

    final fields = <String, dynamic>{
      'latitude': position.latitude,
      'longitude': position.longitude,
      'location': 'POINT(${position.longitude} ${position.latitude})',
    };

    if (address != null && address.isNotEmpty) {
      fields['address'] = address;
    }

    return fields;
  }

  Future<UserModel> _getOrCreateOAuthUserProfile(User supabaseUser) async {
    final userId = supabaseUser.id;
    final existingProfile =
        await client.from('users').select().eq('id', userId).maybeSingle();

    if (existingProfile != null) {
      final hasCoordinates = existingProfile['latitude'] != null &&
          existingProfile['longitude'] != null;
      if (!hasCoordinates) {
        final locationFields = await _buildLocationFields();
        if (locationFields.isNotEmpty) {
          await client.from('users').update(locationFields).eq('id', userId);
          final refreshed = await client
              .from('users')
              .select()
              .eq('id', userId)
              .single();
          return UserModel.fromJson(refreshed);
        }
      }
      return UserModel.fromJson(existingProfile);
    }

    final metadata = supabaseUser.userMetadata ?? <String, dynamic>{};
    final created = <String, dynamic>{
      'id': userId,
      'email': supabaseUser.email ?? '',
      'name': (metadata['full_name'] as String?) ??
          (metadata['name'] as String?) ??
          ((supabaseUser.email ?? 'User').split('@').first),
      'user_type': 'customer',
      'photo_url': metadata['avatar_url'],
      'created_at': DateTime.now().toIso8601String(),
    };
    created.addAll(await _buildLocationFields());

    await client.from('users').upsert(created);
    return UserModel.fromJson(created);
  }

  @override
  Future<UserModel> register({
    required String email,
    required String password,
    required String name,
    required String phone,
    required String userType,
  }) async {
    try {
      print('📝 Starting registration for: $email');

      // 1️⃣ Sign up with Supabase Auth
      final authResponse = await client.auth.signUp(
        email: email,
        password: password,
        data: {
          'name': name,
          'user_type': userType,
        },
      );

      final user = authResponse.user;
      if (user == null) {
        throw const ServerException(message: 'Registration failed. Please try again.');
      }

      // Supabase returns the existing user silently when email is already
      // registered (it does NOT throw an AuthException). Detect this by
      // checking identities — a brand new user always has at least one identity.
      // An existing user that was "re-signed-up" comes back with empty identities.
      final identities = user.identities;
      if (identities != null && identities.isEmpty) {
        throw const ServerException(
          message: 'An account with this email already exists. Please log in instead.',
        );
      }

      final userId = user.id;
      print('✅ Auth user created: $userId');

      // 2️⃣ Wait for trigger to create user record
      await Future.delayed(const Duration(milliseconds: 1000));

      // 3️⃣ Get current location
      final locationData = await LocationHelper.getLocationData();
      final position = locationData['position'] as Position?;
      final address = locationData['address'] as String?;

      // 4️⃣ Build user record
      final userData = <String, dynamic>{
        'id': userId,
        'name': name,
        'email': email,
        'user_type': userType,
        'phone': phone,
        'created_at': DateTime.now().toIso8601String(),
      };

      if (position != null) {
        userData['latitude'] = position.latitude;
        userData['longitude'] = position.longitude;
        userData['location'] =
            'POINT(${position.longitude} ${position.latitude})';
      }

      if (address != null && address.isNotEmpty) {
        userData['address'] = address;
      }

      // 5️⃣ Upsert user data
      try {
        await client.from('users').upsert(userData);
        print('✅ User data saved to database');
      } catch (e) {
        print('⚠️ Error saving user data: $e');
        // Non-fatal — continue
      }

      // 6️⃣ Create artisan profile if needed
      if (userType == 'artisan') {
        try {
          final existingProfile = await client
              .from('artisan_profiles')
              .select('id')
              .eq('user_id', userId)
              .maybeSingle();

          if (existingProfile == null) {
            final artisanData = <String, dynamic>{
              'user_id': userId,
              'category': 'General',
              'availability_status': 'available',
            };

            if (position != null) {
              artisanData['latitude'] = position.latitude;
              artisanData['longitude'] = position.longitude;
              artisanData['location'] =
                  'POINT(${position.longitude} ${position.latitude})';
            }

            await client.from('artisan_profiles').insert(artisanData);
            print('✅ Artisan profile created');
          }
        } catch (e) {
          print('⚠️ Error creating artisan profile: $e');
        }
      }

      // 7️⃣ Fetch final user data — use maybeSingle() to avoid coercion crash.
      // With autoconfirm disabled, the user row may not exist yet if the
      // trigger hasn't fired. Return a minimal UserModel in that case.
      final userResponse = await client
          .from('users')
          .select()
          .eq('id', userId)
          .maybeSingle();

      print('✅ Registration complete — awaiting email confirmation');

      if (userResponse != null) {
        return UserModel.fromJson(userResponse);
      }

      // Fallback: construct from what we know
      return UserModel.fromJson(userData);
    } on AuthException catch (e) {
      print('❌ Auth error: ${e.message}');
      // Map common Supabase auth error codes to friendly messages
      final msg = _friendlyAuthError(e.message);
      throw ServerException(message: msg);
    } on PostgrestException catch (e) {
      print('❌ Database error: ${e.message}');
      throw ServerException(message: e.message);
    } on ServerException {
      rethrow;
    } catch (e) {
      print('❌ Registration error: $e');
      if (e.toString().contains('SocketException') ||
          e.toString().contains('Connection timed out') ||
          e.toString().contains('Connection refused')) {
        throw const ServerException(
          message:
              'Could not connect to the server. Please check your internet connection and try again.',
        );
      }
      throw ServerException(message: 'Registration failed: ${e.toString()}');
    }
  }

  /// Maps Supabase auth error messages to user-friendly equivalents.
  String _friendlyAuthError(String raw) {
    final lower = raw.toLowerCase();
    if (lower.contains('already registered') ||
        lower.contains('already exists') ||
        lower.contains('user already')) {
      return 'An account with this email already exists. Please log in instead.';
    }
    if (lower.contains('email not confirmed') ||
        lower.contains('not confirmed')) {
      return 'Please confirm your email address before logging in. Check your inbox for the confirmation link.';
    }
    if (lower.contains('invalid login') ||
        lower.contains('invalid credentials') ||
        lower.contains('wrong password') ||
        lower.contains('invalid password')) {
      return 'Incorrect email or password. Please try again.';
    }
    if (lower.contains('password') && lower.contains('short')) {
      return 'Password is too short. Please use at least 8 characters.';
    }
    if (lower.contains('invalid email')) {
      return 'Please enter a valid email address.';
    }
    if (lower.contains('rate limit') || lower.contains('too many')) {
      return 'Too many attempts. Please wait a moment and try again.';
    }
    if (lower.contains('user not found') || lower.contains('no user')) {
      return 'No account found with this email. Please register first.';
    }
    return raw;
  }

  @override
  Future<UserModel> login({
    required String email,
    required String password,
  }) async {
    try {
      final authResponse = await client.auth.signInWithPassword(
        email: email,
        password: password,
      );

      final user = authResponse.user;
      if (user == null) throw const ServerException(message: 'Login failed');

      final userId = user.id;

      final userResponse = await client
          .from('users')
          .select()
          .eq('id', userId)
          .maybeSingle();

      if (userResponse == null) {
        final defaultUser = {
          'id': userId,
          'name': 'User',
          'email': email,
          'user_type': 'customer',
          'created_at': DateTime.now().toIso8601String(),
        };
        await client.from('users').insert(defaultUser);
        return UserModel.fromJson(defaultUser);
      }

      return UserModel.fromJson(userResponse);
    } on AuthException catch (e) {
      final msg = e.message.toLowerCase();

      // Just show incorrect credentials — we cannot safely distinguish
      // between wrong password and unconfirmed email without a server-side
      // function. Previous attempts to detect this client-side caused
      // confirmed users to be wrongly sent to the confirm email screen.
      if (msg.contains('invalid login') ||
          msg.contains('invalid credentials') ||
          msg.contains('wrong password') ||
          msg.contains('invalid password')) {
        throw const ServerException(
          message: 'Incorrect email or password. Please try again.',
        );
      }

      throw ServerException(message: _friendlyAuthError(e.message));
    } on PostgrestException catch (e) {
      throw ServerException(message: e.message);
    } catch (e) {
      if (e is ServerException) rethrow;
      if (e.toString().contains('SocketException') ||
          e.toString().contains('Connection timed out')) {
        throw const ServerException(
          message:
              'Could not connect to the server. Please check your internet connection.',
        );
      }
      throw ServerException(message: 'Login failed: ${e.toString()}');
    }
  }

  @override
  Future<UserModel> loginWithGoogle() async {
    try {
      if (!kIsWeb) {
        if (_googleWebClientId.isEmpty) {
          throw const ServerException(
            message:
                'Missing GOOGLE_WEB_CLIENT_ID. Pass your Google Web OAuth client ID via --dart-define=GOOGLE_WEB_CLIENT_ID=...',
          );
        }

        final googleSignIn = GoogleSignIn(
          scopes: const ['email', 'profile'],
          serverClientId: _googleWebClientId,
        );

        final googleUser = await googleSignIn.signIn();
        if (googleUser == null) {
          throw const ServerException(message: 'Google sign-in was canceled.');
        }

        final googleAuth = await googleUser.authentication;
        final idToken = googleAuth.idToken;
        if (idToken == null || idToken.isEmpty) {
          throw const ServerException(
            message:
                'Google sign-in failed: missing ID token. Ensure GOOGLE_WEB_CLIENT_ID is your Web OAuth client ID and your Android package/SHA are configured in Google Cloud.',
          );
        }

        await client.auth.signInWithIdToken(
          provider: OAuthProvider.google,
          idToken: idToken,
          accessToken: googleAuth.accessToken,
        );

        final session = client.auth.currentSession;
        if (session == null) {
          throw const ServerException(
            message: 'Google sign-in failed: session not created.',
          );
        }

        return _getOrCreateOAuthUserProfile(session.user);
      }

      final redirectUrl = _resolveRedirectUrl();
      await client.auth.signInWithOAuth(
        OAuthProvider.google,
        redirectTo: redirectUrl,
        queryParams: const {
          'prompt': 'select_account',
          'access_type': 'offline',
        },
        authScreenLaunchMode: LaunchMode.externalApplication,
      );

      final activeSession = client.auth.currentSession;
      if (activeSession != null) {
        return _getOrCreateOAuthUserProfile(activeSession.user);
      }

      final session = await client.auth.onAuthStateChange
          .firstWhere((event) => event.session != null)
          .timeout(const Duration(seconds: 90));

      return _getOrCreateOAuthUserProfile(session.session!.user);
    } on AuthException catch (e) {
      throw ServerException(message: e.message);
    } on PlatformException catch (e) {
      final message = (e.message ?? '').toLowerCase();
      final isGoogleConfigError = e.code == 'sign_in_failed' &&
          (message.contains('apiexception: 10') ||
              message.contains('developer_error'));
      if (isGoogleConfigError) {
        throw const ServerException(
          message:
              'Google sign-in is not configured correctly for this Android build (ApiException 10). Verify GOOGLE_WEB_CLIENT_ID, package name, and SHA-1/SHA-256 in Firebase/Google Cloud, then update Supabase Google provider client IDs.',
        );
      }
      throw ServerException(message: 'Google login failed: ${e.message}');
    } on TimeoutException {
      throw const ServerException(
        message: 'Google sign-in timed out. Please try again.',
      );
    } catch (e) {
      throw ServerException(message: 'Google login failed: ${e.toString()}');
    }
  }

  @override
  Future<UserModel> loginWithApple() async {
    try {
      final redirectUrl = _resolveRedirectUrl();

      await client.auth.signInWithOAuth(
        OAuthProvider.apple,
        redirectTo: redirectUrl,
        authScreenLaunchMode: kIsWeb
            ? LaunchMode.platformDefault
            : LaunchMode.externalApplication,
      );

      final session = await client.auth.onAuthStateChange
          .firstWhere((event) => event.session != null);

      final supabaseUser = session.session!.user;
      final userId = supabaseUser.id;

      var userResponse = await client
          .from('users')
          .select()
          .eq('id', userId)
          .maybeSingle();

      if (userResponse == null) {
        final newUser = {
          'id': userId,
          'email': supabaseUser.email!,
          'name': supabaseUser.userMetadata?['full_name'] ?? 'User',
          'user_type': 'customer',
        };
        await client.from('users').insert(newUser);
        return UserModel.fromJson(newUser);
      }

      return UserModel.fromJson(userResponse);
    } on AuthException catch (e) {
      throw ServerException(message: e.message);
    } catch (e) {
      throw ServerException(message: 'Apple login failed: ${e.toString()}');
    }
  }

  @override
  Future<void> logout() async {
    try {
      await client.auth.signOut();
    } on AuthException catch (e) {
      throw ServerException(message: e.message);
    }
  }

  @override
  Future<UserModel?> getCurrentUser() async {
    try {
      final user = client.auth.currentUser;
      if (user == null) return null;

      final userResponse = await client
          .from('users')
          .select()
          .eq('id', user.id)
          .maybeSingle();

      if (userResponse == null) {
        final defaultUser = {
          'id': user.id,
          'name': 'User',
          'email': user.email ?? '',
          'user_type': 'customer',
        };
        await client.from('users').insert(defaultUser);
        return UserModel.fromJson(defaultUser);
      }

      return UserModel.fromJson(userResponse);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<bool> isAuthenticated() async {
    try {
      final session = client.auth.currentSession;
      return session != null;
    } catch (e) {
      return false;
    }
  }

  @override
  Future<UserModel> updateProfile({
    required String userId,
    String? name,
    String? phone,
    double? latitude,
    double? longitude,
    String? address,
  }) async {
    try {
      final updateData = <String, dynamic>{};

      if (name != null) updateData['name'] = name;
      if (phone != null) updateData['phone'] = phone;
      if (address != null) updateData['address'] = address;

      if (latitude != null && longitude != null) {
        updateData['location'] = 'POINT($longitude $latitude)';
      }

      await client.from('users').update(updateData).eq('id', userId);

      final userResponse = await client
          .from('users')
          .select()
          .eq('id', userId)
          .single();

      return UserModel.fromJson(userResponse);
    } on PostgrestException catch (e) {
      throw ServerException(message: e.message);
    } catch (e) {
      throw ServerException(
          message: 'Profile update failed: ${e.toString()}');
    }
  }

  @override
  Future<String> uploadProfilePhoto({
    required String userId,
    required String filePath,
  }) async {
    try {
      final fileName =
          '$userId/${DateTime.now().millisecondsSinceEpoch}.jpg';

      await client.storage.from('profile-images').upload(
            fileName,
            File(filePath),
            fileOptions: const FileOptions(upsert: true),
          );

      final publicUrl =
          client.storage.from('profile-images').getPublicUrl(fileName);

      await client
          .from('users')
          .update({'photo_url': publicUrl}).eq('id', userId);

      return publicUrl;
    } on StorageException catch (e) {
      throw ServerException(message: e.message);
    } catch (e) {
      throw ServerException(
          message: 'Photo upload failed: ${e.toString()}');
    }
  }

  @override
  Stream<UserModel?> get authStateChanges {
    return client.auth.onAuthStateChange.asyncMap((event) async {
      final user = event.session?.user;
      if (user == null) return null;

      final userResponse = await client
          .from('users')
          .select()
          .eq('id', user.id)
          .maybeSingle();

      if (userResponse == null) {
        final defaultUser = {
          'id': user.id,
          'name': 'User',
          'email': user.email ?? '',
          'user_type': 'customer',
        };
        await client.from('users').insert(defaultUser);
        return UserModel.fromJson(defaultUser);
      }

      return UserModel.fromJson(userResponse);
    });
  }

  @override
  Future<void> updateUserType(String userId, String newType) async {
    try {
      await client
          .from('users')
          .update({'user_type': newType}).eq('id', userId);
    } on PostgrestException catch (e) {
      throw ServerException(message: e.message);
    } catch (e) {
      throw ServerException(
          message: 'Failed to update user type: ${e.toString()}');
    }
  }

  @override
  Future<void> createArtisanProfileIfNeeded(String userId) async {
    try {
      final userData = await client
          .from('users')
          .select('latitude, longitude, location, address, verified')
          .eq('id', userId)
          .single();

      final userVerified = (userData['verified'] as bool?) ?? false;

      final existingProfile = await client
          .from('artisan_profiles')
          .select('id,verified')
          .eq('user_id', userId)
          .maybeSingle();

      if (existingProfile != null) {
        final artisanVerified = (existingProfile['verified'] as bool?) ?? false;
        if (artisanVerified != userVerified) {
          await client
              .from('artisan_profiles')
              .update({'verified': userVerified})
              .eq('user_id', userId);
        }
        return;
      }

      final artisanData = <String, dynamic>{
        'user_id': userId,
        'category': 'General',
        'availability_status': 'available',
        'rating': 0.0,
        'reviews_count': 0,
        'verified': userVerified,
        'premium': false,
        'completed_jobs': 0,
      };

      if (userData['latitude'] != null && userData['longitude'] != null) {
        artisanData['latitude'] = userData['latitude'];
        artisanData['longitude'] = userData['longitude'];
        artisanData['location'] = userData['location'];
      }

      if (userData['address'] != null) {
        artisanData['address'] = userData['address'];
      }

      await client.from('artisan_profiles').insert(artisanData);
    } on PostgrestException catch (e) {
      throw ServerException(message: e.message);
    } catch (e) {
      throw ServerException(
          message: 'Failed to create artisan profile: ${e.toString()}');
    }
  }

  @override
  Future<void> requestAccountDeletion({required String reason}) async {
    try {
      final user = client.auth.currentUser;
      if (user == null) {
        throw const ServerException(message: 'No authenticated user found.');
      }

      try {
        final response = await client.functions.invoke(
          'delete-account',
          body: {'reason': reason},
        );

        if (response.status >= 200 && response.status < 300) {
          await client.auth.signOut();
          return;
        }
      } catch (_) {
        // Edge function not deployed — fall through to queue
      }

      await client.from('account_deletion_requests').upsert({
        'user_id': user.id,
        'reason': reason,
        'status': 'pending',
        'requested_at': DateTime.now().toIso8601String(),
      }, onConflict: 'user_id');

      await client.auth.signOut();
    } on PostgrestException catch (e) {
      throw ServerException(message: e.message);
    } on AuthException catch (e) {
      throw ServerException(message: e.message);
    } catch (e) {
      throw ServerException(
        message:
            'Failed to process account deletion request: ${e.toString()}',
      );
    }
  }
}
