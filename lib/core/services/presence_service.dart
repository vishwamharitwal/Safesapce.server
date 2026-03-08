import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';

class PresenceService extends ChangeNotifier {
  final _supabase = Supabase.instance.client;
  late final RealtimeChannel _presenceChannel;
  int _onlineUsersCount = 1; // Default to 1 (themselves)

  int get onlineUsersCount => _onlineUsersCount;

  PresenceService({required String userId}) {
    _initPresence(userId);
  }

  void _initPresence(String userId) {
    _presenceChannel = _supabase.channel('global-presence');

    _presenceChannel
        .onPresenceSync((_) {
          final state = _presenceChannel.presenceState();
          _onlineUsersCount = state.isNotEmpty ? state.length : 1;
          notifyListeners();
        })
        .subscribe((status, error) async {
          if (status == RealtimeSubscribeStatus.subscribed) {
            await _presenceChannel.track({
              'user_id': userId,
              'online_at': DateTime.now().toIso8601String(),
            });
          }
        });
  }

  @override
  void dispose() {
    _supabase.removeChannel(_presenceChannel);
    super.dispose();
  }
}
