import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';

class PresenceService extends ChangeNotifier {
  final _supabase = Supabase.instance.client;
  RealtimeChannel? _presenceChannel;
  int? _onlineUsersCount; // null means loading
  bool _isDisposed = false;

  int? get onlineUsersCount => _onlineUsersCount;

  PresenceService({required String userId}) {
    _initPresence(userId);
  }

  void _initPresence(String userId) {
    if (_isDisposed) return;

    // Remove old channel before creating new one (prevents leak on reconnect)
    if (_presenceChannel != null) {
      _supabase.removeChannel(_presenceChannel!);
      _presenceChannel = null;
    }

    _presenceChannel = _supabase.channel('global-presence');

    _presenceChannel!
        .onPresenceSync((_) => _updateCount())
        .onPresenceJoin((_) => _updateCount())
        .onPresenceLeave((_) => _updateCount())
        .subscribe((status, error) async {
          if (status == RealtimeSubscribeStatus.subscribed) {
            await _presenceChannel?.track({
              'user_id': userId,
              'online_at': DateTime.now().toIso8601String(),
            });
            _updateCount();
          }

          // Auto-reconnect on close/error
          if (status == RealtimeSubscribeStatus.closed ||
              status == RealtimeSubscribeStatus.channelError) {
            if (!_isDisposed) {
              await Future.delayed(const Duration(seconds: 2));
              _initPresence(userId); // Retry
            }
          }
        });
  }

  void _updateCount() {
    if (_presenceChannel == null || _isDisposed) return;

    final state = _presenceChannel!.presenceState();
    // Use the actual length, fallback to at least 1 if initializing
    _onlineUsersCount = state.isNotEmpty ? state.length : 1;
    notifyListeners();
  }

  @override
  void dispose() {
    _isDisposed = true;
    if (_presenceChannel != null) {
      _supabase.removeChannel(_presenceChannel!);
    }
    super.dispose();
  }
}
