import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class UserProfile {
  final String id;
  final String email;
  final String displayName;
  final String? photoUrl;
  final bool isDemo;

  const UserProfile({
    required this.id,
    required this.email,
    required this.displayName,
    this.photoUrl,
    this.isDemo = false,
  });

  static const demo = UserProfile(
    id: 'demo_user',
    email: 'demo@getplan.local',
    displayName: 'Local User',
    isDemo: true,
  );
}

class AuthState {
  final UserProfile? user;
  final bool isLoading;
  final String? errorMessage;
  final bool isSingleUserLocked;
  final String? allowedEmail;

  const AuthState({
    this.user = UserProfile.demo,
    this.isLoading = false,
    this.errorMessage,
    this.isSingleUserLocked = false,
    this.allowedEmail,
  });

  bool get isAuthenticated => user != null;

  AuthState copyWith({
    UserProfile? user,
    bool? isLoading,
    String? errorMessage,
    bool? isSingleUserLocked,
    String? allowedEmail,
    bool clearUser = false,
  }) {
    return AuthState(
      user: clearUser ? null : (user ?? this.user),
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
      isSingleUserLocked: isSingleUserLocked ?? this.isSingleUserLocked,
      allowedEmail: allowedEmail ?? this.allowedEmail,
    );
  }
}

class AuthNotifier extends Notifier<AuthState> {
  @override
  AuthState build() => const AuthState();

  void setAllowedEmail(String email) {
    state = state.copyWith(allowedEmail: email, isSingleUserLocked: true);
  }

  void enterDemoMode() {
    state = state.copyWith(
      user: UserProfile.demo,
      isLoading: false,
      errorMessage: null,
    );
  }

  void dismissError() {
    state = state.copyWith(errorMessage: null);
  }

  Future<bool> initializeFirebaseWithOptions(FirebaseOptions options) async {
    try {
      if (Firebase.apps.isNotEmpty) {
        await Firebase.app().delete();
      }
      await Firebase.initializeApp(options: options);
      state = state.copyWith(errorMessage: null);
      return true;
    } catch (e) {
      state = state.copyWith(
        errorMessage: 'Firebase initialization failed: $e',
      );
      return false;
    }
  }

  Future<void> signInWithGoogle() async {
    state = state.copyWith(isLoading: true, errorMessage: null);

    if (Firebase.apps.isEmpty) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Firebase has not been connected to a project yet. Configure your Firebase project in Settings > Firebase Setup or continue in Local Mode.',
      );
      return;
    }

    try {
      GoogleAuthProvider authProvider = GoogleAuthProvider();
      authProvider.addScope('email');
      authProvider.addScope('profile');

      final userCredential = await FirebaseAuth.instance.signInWithPopup(authProvider);
      final fbUser = userCredential.user;

      if (fbUser == null) {
        state = state.copyWith(
          isLoading: false,
          errorMessage: 'Sign-in cancelled or failed.',
        );
        return;
      }

      // Check single-user email restriction if configured
      if (state.allowedEmail != null &&
          state.allowedEmail!.isNotEmpty &&
          fbUser.email?.toLowerCase() != state.allowedEmail!.toLowerCase()) {
        await FirebaseAuth.instance.signOut();
        state = state.copyWith(
          isLoading: false,
          errorMessage: 'Unauthorized: Access is restricted to ${state.allowedEmail}.',
          clearUser: true,
        );
        return;
      }

      state = state.copyWith(
        isLoading: false,
        user: UserProfile(
          id: fbUser.uid,
          email: fbUser.email ?? '',
          displayName: fbUser.displayName ?? 'Plan User',
          photoUrl: fbUser.photoURL,
          isDemo: false,
        ),
      );
    } catch (e) {
      if (kDebugMode) {
        print('Google Sign-In note: $e (Falling back to local session)');
      }
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Google Sign-In: $e (You can continue in Local Mode)',
      );
    }
  }

  Future<void> signOut() async {
    try {
      await FirebaseAuth.instance.signOut();
    } catch (_) {}
    state = state.copyWith(clearUser: true);
  }
}

final authProvider = NotifierProvider<AuthNotifier, AuthState>(AuthNotifier.new);
