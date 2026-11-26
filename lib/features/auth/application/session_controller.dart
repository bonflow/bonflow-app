import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_error.dart';
import '../../../core/storage/token_store.dart';
import '../data/auth_repository.dart';

/// Whether a waiter is logged in. While [restoring] the stored session is still being read.
class SessionState {
  const SessionState({this.restoring = true, this.session});

  final bool restoring;
  final Session? session;

  bool get loggedIn => session != null;
}

class SessionController extends Notifier<SessionState> {
  Future<bool>? _refreshing;

  @override
  SessionState build() {
    Future.microtask(_restore);
    return const SessionState();
  }

  String? get accessToken => state.session?.accessToken;

  Future<void> _restore() async {
    final stored = await ref.read(tokenStoreProvider).read();
    if (!ref.mounted) {
      return;
    }
    state = SessionState(restoring: false, session: stored);
  }

  Future<void> login(int waiterId, String pin) async {
    final session = await ref.read(authRepositoryProvider).login(waiterId, pin);
    await ref.read(tokenStoreProvider).write(session);
    state = SessionState(restoring: false, session: session);
  }

  Future<void> logout() async {
    await ref.read(tokenStoreProvider).clear();
    state = const SessionState(restoring: false);
  }

  /// Gets new tokens with the refresh token. Concurrent callers share one request.
  /// Logs out and returns false if the server no longer accepts the refresh token.
  Future<bool> refreshTokens() => _refreshing ??= _refresh().whenComplete(() {
    _refreshing = null;
  });

  Future<bool> _refresh() async {
    final current = state.session;
    if (current == null) {
      return false;
    }
    try {
      final renewed = await ref.read(authRepositoryProvider).refresh(current);
      await ref.read(tokenStoreProvider).write(renewed);
      state = SessionState(restoring: false, session: renewed);
      return true;
    } on ApiError catch (e) {
      if (e.kind == ApiErrorKind.unauthorized) {
        await logout();
      }
      return false;
    }
  }
}

final sessionControllerProvider =
    NotifierProvider<SessionController, SessionState>(SessionController.new);
