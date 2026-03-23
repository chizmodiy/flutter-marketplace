import 'package:supabase_flutter/supabase_flutter.dart';

class ChatService {
  final SupabaseClient _client = Supabase.instance.client;

  Future<bool> hasUnreadMessages() async {
    final currentUser = _client.auth.currentUser;
    if (currentUser == null) {
      return false;
    }

    // Спочатку отримуємо chat_id, в яких бере участь поточний користувач
    final participantResponse = await _client
        .from('chat_participants')
        .select('chat_id')
        .eq('user_id', currentUser.id);

    if (participantResponse.isEmpty) {
      return false;
    }

    final chatIds = (participantResponse as List)
        .map((e) => e['chat_id'])
        .toList();

    // Тепер перевіряємо, чи є в цих чатах непрочитані повідомлення не від поточного користувача
    final response = await _client
        .from('chat_messages')
        .select('id')
        .in_('chat_id', chatIds)
        .eq('is_read', false)
        .neq('sender_id', currentUser.id)
        .limit(1)
        .maybeSingle();

    return response != null;
  }
}
