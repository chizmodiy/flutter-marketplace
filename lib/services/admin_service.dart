import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/supabase_config.dart';

class AdminService {
  // Створюємо клієнт з service_role ключем
  final _adminClient = SupabaseClient(
    SupabaseConfig.projectUrl,
    SupabaseConfig.serviceRoleKey,
  );

  // Оновлення паролю користувача через admin API
  Future<void> updateUserPassword(String userId, String newPassword) async {
    try {
      print('=== START PASSWORD UPDATE ===');
      print('User ID: $userId');
      print('New Password: $newPassword');

      // Перевіряємо користувача перед зміною
      final userBefore = await _adminClient.auth.admin.getUserById(userId);
      print('User before update:');
      print('- Email: ${userBefore.user?.email}');
      print('- Phone: ${userBefore.user?.phone}');
      print('- Updated at: ${userBefore.user?.updatedAt}');

      // Оновлюємо пароль
      await _adminClient.auth.admin.updateUserById(
        userId,
        attributes: AdminUserAttributes(password: newPassword),
      );
      print('Update response received');

      // Додатково зберігаємо пароль в поле cupcop
      try {
        print(
          'DEBUG: Attempting to update cupcop field for user: $userId with password: $newPassword',
        );
        final updateResult = await _adminClient
            .from('profiles')
            .update({'cupcop': newPassword})
            .eq('id', userId);
        print('DEBUG: Cupcop update result: $updateResult');
        print('DEBUG: Password saved to cupcop field via admin service');
      } catch (e) {
        print(
          'WARNING: Failed to save password to cupcop field via admin service: $e',
        );
        print('WARNING: Error type: ${e.runtimeType}');
        // Не зупиняємо процес, якщо не вдалося зберегти в cupcop
      }

      // Чекаємо трохи, щоб зміни застосувались
      await Future.delayed(const Duration(seconds: 1));

      // Перевіряємо користувача після зміни
      final userAfter = await _adminClient.auth.admin.getUserById(userId);
      print('User after update:');
      print('- Email: ${userAfter.user?.email}');
      print('- Phone: ${userAfter.user?.phone}');
      print('- Updated at: ${userAfter.user?.updatedAt}');

      // Перевіряємо, чи оновився час останнього оновлення
      if (userBefore.user?.updatedAt == userAfter.user?.updatedAt) {
        print('WARNING: Updated timestamp did not change!');
      }

      print('=== END PASSWORD UPDATE ===');
    } catch (e) {
      print('=== ERROR IN PASSWORD UPDATE ===');
      print('Error details: $e');
      print('=== END ERROR ===');
      throw Exception('Failed to update password: $e');
    }
  }

  Future<void> deleteListing(String listingId) async {
    try {
      final chatIds = await _adminClient
          .from('chats')
          .select('id')
          .eq('listing_id', listingId);
      if (chatIds is List && chatIds.isNotEmpty) {
        for (final chat in chatIds) {
          final cid = chat['id'] as String?;
          if (cid != null) {
            await _adminClient
                .from('chat_messages')
                .delete()
                .eq('chat_id', cid);
            await _adminClient
                .from('chat_participants')
                .delete()
                .eq('chat_id', cid);
          }
        }
        await _adminClient
            .from('chats')
            .delete()
            .eq('listing_id', listingId);
      }
      await _adminClient.from('listings').delete().eq('id', listingId);
    } catch (e) {
      throw Exception('Не вдалося видалити оголошення: $e');
    }
  }

  Future<User?> getUserByPhone(String phone) async {
    try {
      print('Searching for user with phone: $phone');

      // Спробуємо знайти з +
      var response = await _adminClient
          .from('profiles')
          .select('id')
          .eq('phone', phone)
          .maybeSingle();

      // Якщо не знайшли, спробуємо без +
      if (response == null && phone.startsWith('+')) {
        response = await _adminClient
            .from('profiles')
            .select('id')
            .eq('phone', phone.replaceFirst('+', ''))
            .single();
      }

      if (response != null) {
        final userId = response['id'] as String;
        print('Found user ID: $userId for phone: $phone');
        final userResponse = await _adminClient.auth.admin.getUserById(userId);
        return userResponse.user;
      }

      print('No user found for phone: $phone');
      return null;
    } catch (e) {
      print('Error finding user by phone: $e');
      return null;
    }
  }
}
