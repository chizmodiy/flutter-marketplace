import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../widgets/common_header.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../services/profile_service.dart';
import '../services/complaint_service.dart';
import '../widgets/complaint_modal.dart';
import '../widgets/success_bottom_sheet.dart';
import '../utils/price_formatter.dart';
import 'full_screen_image_slider_page.dart';

class ChatPage extends StatefulWidget {
  final VoidCallback? onChatRead;

  const ChatPage({super.key, this.onChatRead});

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  bool isBuyerSelected = true; // За замовчуванням 'Купую'

  String? _currentUserId;
  String? _anonymousUserId; // Додано для анонімних користувачів
  List<Map<String, dynamic>> _chats = [];
  bool _loading = true;
  String? _error; // Додано для обробки помилок
  final ProfileService _profileService = ProfileService();
  RealtimeChannel? _realtimeChannel;
  bool _hasUnreadBuyer = false;
  bool _hasUnreadSeller = false;

  @override
  void initState() {
    super.initState();
    _currentUserId = Supabase.instance.client.auth.currentUser?.id;
    _loadAnonymousUserId().then((_) => _loadChats());
    _subscribeToChatUpdates();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Оновлюємо список чатів при зміні залежностей (наприклад, при поверненні з діалогу)
    _loadChats();
  }

  @override
  void didUpdateWidget(ChatPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Оновлюємо список чатів при оновленні віджета
    _loadChats();
  }

  @override
  void dispose() {
    _realtimeChannel?.unsubscribe();
    super.dispose();
  }

  Future<void> _loadAnonymousUserId() async {
    final prefs = await SharedPreferences.getInstance();
    String? storedId = prefs.getString('anonymous_user_id');

    if (storedId == null) {
      storedId = const Uuid().v4();
      await prefs.setString('anonymous_user_id', storedId);
      print('DEBUG (ChatPage): Generated new anonymous user ID: $storedId');
    } else {
      print('DEBUG (ChatPage): Loaded existing anonymous user ID: $storedId');
    }

    setState(() {
      _anonymousUserId = storedId;
    });
  }

  void _subscribeToChatUpdates() {
    final client = Supabase.instance.client;
    _realtimeChannel = client.channel('public:chat_messages')
      ..on(
        RealtimeListenTypes.postgresChanges,
        ChannelFilter(
          event: 'INSERT',
          schema: 'public',
          table: 'chat_messages',
        ),
        (payload, [ref]) {
          // Оновлюємо список чатів при отриманні нового повідомлення
          _loadChats();
        },
      )
      ..on(
        RealtimeListenTypes.postgresChanges,
        ChannelFilter(
          event: 'UPDATE',
          schema: 'public',
          table: 'chat_messages',
        ),
        (payload, [ref]) {
          // Оновлюємо список чатів при оновленні повідомлення (наприклад, позначення як прочитане)
          _loadChats();
        },
      )
      ..subscribe();
  }

  // Метод для оновлення списку чатів
  void refreshProducts() {
    _loadChats();
  }

  Future<void> _loadChats() async {
    print('DEBUG (ChatPage): _loadChats called.');
    final String? initiatorId = _currentUserId ?? _anonymousUserId;
    if (initiatorId == null) {
      print('DEBUG (ChatPage): Initiator ID is null, cannot load chats.');
      setState(() {
        _loading = false;
      });
      return;
    }

    setState(() => _loading = true);
    final client = Supabase.instance.client;

    try {
      print('DEBUG (ChatPage): Loading chats for initiator ID: $initiatorId');
      final chatsData = await client
          .from('chat_participants')
          .select('chat_id')
          .eq('user_id', initiatorId);

      final chatIds = (chatsData as List<dynamic>)
          .map((e) => e['chat_id'])
          .toList();
      print('DEBUG (ChatPage): Found ${chatIds.length} chat IDs: $chatIds');

      if (chatIds.isEmpty) {
        setState(() {
          _chats = [];
          _loading = false;
        });
        print('DEBUG (ChatPage): No chats found for this initiator.');
        return;
      }

      final fullChats = await client
          .from('chats')
          .select(
            '*, chat_participants(user_id), chat_messages(*), listings(id, title, photos, price, location, created_at, user_id)',
          ) // Додано listings
          .in_('id', chatIds);

      List<Map<String, dynamic>> processedChats = [];
      for (var chat in fullChats) {
        final participants = chat['chat_participants'] as List<dynamic>;
        final otherParticipant = participants.firstWhere(
          (p) => p['user_id'] != initiatorId, // Знаходимо іншого учасника чату
          orElse: () => null,
        );

        String otherUserName = 'Невідомий користувач';
        String otherUserAvatarUrl = '';

        if (otherParticipant != null && otherParticipant['user_id'] != null) {
          final otherUserId = otherParticipant['user_id'] as String;
          final otherUserProfile = await _profileService.getUser(otherUserId);
          if (otherUserProfile != null) {
            otherUserName = otherUserProfile.fullName;
            otherUserAvatarUrl = otherUserProfile.avatarUrl ?? '';
          } else {
            // Якщо профіль не знайдено, можливо, це анонімний користувач
            otherUserName = 'Анонімний користувач';
            otherUserAvatarUrl = '';
          }
        }

        final listing = chat['listings'];
        final listingTitle = listing != null
            ? listing['title']
            : 'Оголошення видалено';
        final listingImageUrl =
            listing != null &&
                listing['photos'] != null &&
                (listing['photos'] as List).isNotEmpty
            ? (listing['photos'] as List).first
            : '';
        final listingPrice = _formatListingPrice(listing);
        final listingLocation = listing != null ? listing['location'] : '';
        final listingDate = listing != null && listing['created_at'] != null
            ? _formatChatListTime(DateTime.parse(listing['created_at']))
            : '';

        final messages = chat['chat_messages'] as List<dynamic>;
        messages.sort(
          (a, b) => DateTime.parse(
            a['created_at'],
          ).compareTo(DateTime.parse(b['created_at'])),
        );
        final lastMessage = messages.isNotEmpty
            ? (messages.last['content'] ?? '')
            : 'Повідомлень немає';
        final lastMessageTime = messages.isNotEmpty
            ? _formatChatListTime(DateTime.parse(messages.last['created_at']))
            : '';

        final unreadCount = messages
            .where(
              (msg) =>
                  msg['sender_id'] != initiatorId &&
                  (msg['is_read'] == false || msg['is_read'] == null),
            )
            .length;

        processedChats.add({
          'chatId': chat['id'],
          'imageUrl': listingImageUrl,
          'listingTitle': listingTitle,
          'userName': otherUserName,
          'userAvatarUrl': otherUserAvatarUrl,
          'lastMessage': lastMessage,
          'time': lastMessageTime,
          'unreadCount': unreadCount,
          'listingPrice': listingPrice,
          'listingDate': listingDate,
          'listingLocation': listingLocation,
          'listingOwnerId':
              listing?['user_id'], // Додаємо ID власника оголошення
        });
      }

      // Обчислення непрочитаних для вкладок
      int unreadBuyer = 0;
      int unreadSeller = 0;

      // Фільтрація чатів за типом (Куплю/Продам)
      List<Map<String, dynamic>> filteredChats = [];

      // Для анонімних користувачів (неавторизованих)
      if (_currentUserId == null) {
        for (var chat in processedChats) {
          unreadBuyer += (chat['unreadCount'] as int);
        }
        if (isBuyerSelected) {
          // "Куплю" - показуємо всі чати (анонімний користувач завжди купує)
          filteredChats = processedChats;
        } else {
          // "Продам" - не показуємо нічого (анонімний користувач не може продавати)
          filteredChats = [];
        }
      } else {
        // Для авторизованих користувачів
        for (var chat in processedChats) {
          final listingOwnerId = chat['listingOwnerId'];
          final unreadCount = chat['unreadCount'] as int;

          if (listingOwnerId != initiatorId) {
            unreadBuyer += unreadCount;
            if (isBuyerSelected) filteredChats.add(chat);
          } else {
            unreadSeller += unreadCount;
            if (!isBuyerSelected) filteredChats.add(chat);
          }
        }
      }

      setState(() {
        _hasUnreadBuyer = unreadBuyer > 0;
        _hasUnreadSeller = unreadSeller > 0;
        _chats = filteredChats;
        _loading = false;
      });
      print(
        'DEBUG (ChatPage): Loaded ${processedChats.length} processed chat objects. UnreadBuyer: $unreadBuyer, UnreadSeller: $unreadSeller',
      );
    } catch (e, stackTrace) {
      print('ERROR (ChatPage): Failed to load chats: $e');
      print('STACK (ChatPage): $stackTrace');
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  String _formatChatListTime(DateTime dateTime) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final messageDate = DateTime(dateTime.year, dateTime.month, dateTime.day);

    // Форматуємо час
    final time =
        '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';

    if (messageDate == today) {
      return time; // Тільки час для сьогодні
    } else if (messageDate == yesterday) {
      return 'Вчора';
    } else if (now.difference(dateTime).inDays < 7) {
      // Цього тижня - показуємо короткий день тижня
      return _shortWeekdayName(dateTime.weekday);
    } else {
      // Старіше - показуємо коротку дату
      return '${dateTime.day.toString().padLeft(2, '0')}.${dateTime.month.toString().padLeft(2, '0')}';
    }
  }

  String _shortWeekdayName(int weekday) {
    const names = ['', 'Пн', 'Вт', 'Ср', 'Чт', 'Пт', 'Сб', 'Нд'];
    return names[weekday];
  }

  String _formatListingDate(DateTime dateTime) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final listingDate = DateTime(dateTime.year, dateTime.month, dateTime.day);

    if (listingDate == today) {
      return 'Сьогодні';
    } else if (listingDate == yesterday) {
      return 'Вчора';
    } else if (now.difference(dateTime).inDays < 7) {
      return _shortWeekdayName(dateTime.weekday);
    } else {
      return '${dateTime.day.toString().padLeft(2, '0')}.${dateTime.month.toString().padLeft(2, '0')}';
    }
  }

  String _formatListingPrice(dynamic listing) {
    if (listing == null) return '';

    final bool isFree = listing['is_free'] == true;
    if (isFree) {
      return 'Безкоштовно';
    }

    final bool isNegotiable = listing['is_negotiable'] == true;
    final dynamic priceValue = listing['price'];

    if (priceValue == null) {
      return isNegotiable ? 'Договірна' : 'Ціна не вказана';
    }

    num? priceNum;
    if (priceValue is num) {
      priceNum = priceValue;
    } else if (priceValue is String) {
      priceNum = num.tryParse(priceValue);
    }

    if (priceNum == null) {
      return isNegotiable ? 'Договірна' : 'Ціна не вказана';
    }

    final currency = listing['currency'];
    return PriceFormatter.formatCurrency(priceNum, currency: currency);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: const CommonHeader(),
      body: Padding(
        padding: const EdgeInsets.only(top: 20, left: 13, right: 13, bottom: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Чат',
              style: TextStyle(
                color: Color(0xFF161817),
                fontSize: 28,
                fontFamily: 'Inter',
                fontWeight: FontWeight.w600,
                height: 1.2,
              ),
            ),
            const SizedBox(height: 20),
            _currentUserId != null
                ? ChatTypeSwitch(
                    isBuyerSelected: isBuyerSelected,
                    hasUnreadBuyer: _hasUnreadBuyer,
                    hasUnreadSeller: _hasUnreadSeller,
                    onChanged: (value) {
                      setState(() {
                        isBuyerSelected = value;
                      });
                      _loadChats();
                    },
                  )
                : SizedBox.shrink(),
            const SizedBox(height: 20),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _chats.isNotEmpty
                  ? ListView.separated(
                      itemCount: _chats.length,
                      separatorBuilder: (context, index) =>
                          const SizedBox(height: 20),
                      itemBuilder: (context, index) {
                        final chat = _chats[index];
                        return ChatCard(
                          imageUrl: chat['imageUrl'],
                          listingTitle: chat['listingTitle'],
                          userName: chat['userName'],
                          lastMessage: chat['lastMessage'],
                          time: chat['time'],
                          unreadCount: chat['unreadCount'],
                          onTap: () async {
                            await Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (context) => ChatDialogPage(
                                  chatId: chat['chatId'] ?? '',
                                  userName: chat['userName'] ?? '',
                                  userAvatarUrl: chat['userAvatarUrl'] ?? '',
                                  listingTitle: chat['listingTitle'] ?? '',
                                  listingImageUrl: chat['imageUrl'] ?? '',
                                  listingPrice: chat['listingPrice'] ?? '',
                                  listingDate: chat['listingDate'] ?? '',
                                  listingLocation:
                                      chat['listingLocation'] ?? '',
                                ),
                              ),
                            );
                            if (mounted) {
                              _loadChats();
                              widget.onChatRead?.call();
                            }
                          },
                        );
                      },
                    )
                  : _currentUserId ==
                        null // Якщо чатів немає і користувач не авторизований
                  ? Column(
                      children: [
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.only(top: 40),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            mainAxisAlignment: MainAxisAlignment.start,
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              // Content
                              Column(
                                children: [
                                  // Featured icon with message
                                  Container(
                                    width: 48,
                                    height: 48,
                                    decoration: BoxDecoration(
                                      color: AppColors.zinc100,
                                      borderRadius: BorderRadius.circular(28),
                                      border: Border.all(
                                        color: AppColors.zinc50,
                                        width: 8,
                                      ),
                                    ),
                                    child: Center(
                                      child: SvgPicture.asset(
                                        'assets/icons/message-circle-01.svg',
                                        width: 24,
                                        height: 24,
                                        colorFilter: const ColorFilter.mode(
                                          AppColors.primaryColor,
                                          BlendMode.srcIn,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  // Text content
                                  Column(
                                    children: [
                                      Text(
                                        'Обмінюйтесь повідомленями',
                                        textAlign: TextAlign.center,
                                        style: AppTextStyles.heading1Semibold
                                            .copyWith(
                                              color: Colors.black,
                                              fontSize: 24,
                                              height: 28.8 / 24,
                                            ),
                                      ),
                                      const SizedBox(height: 12),
                                      Text(
                                        'Увійдіть або створіть профіль для обміну повідомленнями з іншими користувачами нашої платформи.',
                                        textAlign: TextAlign.center,
                                        style: AppTextStyles.body1Regular
                                            .copyWith(
                                              color: AppColors.color7,
                                              height: 22.4 / 16,
                                              letterSpacing: 0.16,
                                            ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              const SizedBox(height: 40),
                              // Buttons
                              Column(
                                children: [
                                  SizedBox(
                                    width: double.infinity,
                                    height: 44,
                                    child: ElevatedButton(
                                      onPressed: () {
                                        Navigator.of(
                                          context,
                                        ).pushNamed('/auth');
                                      },
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: const Color(
                                          0xFF015873,
                                        ),
                                        foregroundColor: Colors.white,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            200,
                                          ),
                                        ),
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 18,
                                        ),
                                        elevation: 0,
                                        shadowColor: const Color.fromRGBO(
                                          16,
                                          24,
                                          40,
                                          0.05,
                                        ),
                                      ),
                                      child: Text(
                                        'Увійти',
                                        style: AppTextStyles.body1Medium
                                            .copyWith(
                                              color: Colors.white,
                                              letterSpacing: 0.16,
                                            ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  SizedBox(
                                    width: double.infinity,
                                    height: 44,
                                    child: OutlinedButton(
                                      onPressed: () {
                                        Navigator.of(
                                          context,
                                        ).pushNamed('/auth');
                                      },
                                      style: OutlinedButton.styleFrom(
                                        backgroundColor: Colors.white,
                                        foregroundColor: Colors.black,
                                        side: const BorderSide(
                                          color: AppColors.zinc200,
                                          width: 1,
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            200,
                                          ),
                                        ),
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 18,
                                        ),
                                        elevation: 0,
                                        shadowColor: const Color.fromRGBO(
                                          16,
                                          24,
                                          40,
                                          0.05,
                                        ),
                                      ),
                                      child: Text(
                                        'Створити акаунт',
                                        style: AppTextStyles.body1Medium
                                            .copyWith(
                                              color: Colors.black,
                                              letterSpacing: 0.16,
                                            ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const Spacer(),
                      ],
                    )
                  : Column(
                      children: [
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.only(top: 40),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            mainAxisAlignment: MainAxisAlignment.start,
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Container(
                                width: 52,
                                height: 52,
                                child: Stack(
                                  children: [
                                    Positioned(
                                      left: 0,
                                      top: 0,
                                      child: Container(
                                        width: 52,
                                        height: 52,
                                        decoration: const ShapeDecoration(
                                          color: Color(0xFFFAFAFA),
                                          shape: OvalBorder(),
                                        ),
                                      ),
                                    ),
                                    const Positioned(
                                      left: 14,
                                      top: 14,
                                      child: Icon(
                                        Icons.chat_bubble_outline,
                                        size: 24,
                                        color: Color(0xFF52525B),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 20),
                              Container(
                                width: double.infinity,
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  mainAxisAlignment: MainAxisAlignment.start,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    SizedBox(
                                      width: double.infinity,
                                      child: const Text(
                                        'Немає повідомлень',
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          color: Color(0xFF667084),
                                          fontSize: 16,
                                          fontFamily: 'Inter',
                                          fontWeight: FontWeight.w400,
                                          height: 1.40,
                                          letterSpacing: 0.16,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Spacer(),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class ChatTypeSwitch extends StatelessWidget {
  final bool isBuyerSelected;
  final bool hasUnreadBuyer;
  final bool hasUnreadSeller;
  final ValueChanged<bool> onChanged;

  const ChatTypeSwitch({
    super.key,
    required this.isBuyerSelected,
    this.hasUnreadBuyer = false,
    this.hasUnreadSeller = false,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(4),
      decoration: ShapeDecoration(
        color: const Color(0xFFF4F4F5),
        shape: RoundedRectangleBorder(
          side: const BorderSide(width: 1, color: Color(0xFFFAFAFA)),
          borderRadius: BorderRadius.circular(200),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () => onChanged(true),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                decoration: ShapeDecoration(
                  color: isBuyerSelected ? Colors.white : Colors.transparent,
                  shape: RoundedRectangleBorder(
                    side: BorderSide(
                      width: 1,
                      color: isBuyerSelected
                          ? const Color(0xFFE4E4E7)
                          : Colors.transparent,
                    ),
                    borderRadius: BorderRadius.circular(200),
                  ),
                  shadows: isBuyerSelected
                      ? [
                          const BoxShadow(
                            color: Color(0x0C101828),
                            blurRadius: 2,
                            offset: Offset(0, 1),
                            spreadRadius: 0,
                          ),
                        ]
                      : [],
                ),
                child: Center(
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Text(
                        'Купую',
                        style: TextStyle(
                          color: isBuyerSelected
                              ? Colors.black
                              : Colors.grey[700],
                          fontSize: 14,
                          fontFamily: 'Inter',
                          fontWeight: FontWeight.w600,
                          height: 1.40,
                          letterSpacing: 0.14,
                        ),
                      ),
                      if (hasUnreadBuyer)
                        Positioned(
                          right: -8,
                          top: -2,
                          child: Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              color: Colors.red,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: GestureDetector(
              onTap: () => onChanged(false),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                decoration: ShapeDecoration(
                  color: !isBuyerSelected ? Colors.white : Colors.transparent,
                  shape: RoundedRectangleBorder(
                    side: BorderSide(
                      width: 1,
                      color: !isBuyerSelected
                          ? const Color(0xFFE4E4E7)
                          : Colors.transparent,
                    ),
                    borderRadius: BorderRadius.circular(200),
                  ),
                  shadows: !isBuyerSelected
                      ? [
                          const BoxShadow(
                            color: Color(0x0C101828),
                            blurRadius: 2,
                            offset: Offset(0, 1),
                            spreadRadius: 0,
                          ),
                        ]
                      : [],
                ),
                child: Center(
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Text(
                        'Продаю',
                        style: TextStyle(
                          color: !isBuyerSelected
                              ? Colors.black
                              : Colors.grey[700],
                          fontSize: 14,
                          fontFamily: 'Inter',
                          fontWeight: FontWeight.w600,
                          height: 1.40,
                          letterSpacing: 0.14,
                        ),
                      ),
                      if (hasUnreadSeller)
                        Positioned(
                          right: -8,
                          top: -2,
                          child: Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              color: Colors.red,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Додаю компонент ChatCard
class ChatCard extends StatelessWidget {
  final String imageUrl;
  final String listingTitle;
  final String userName;
  final String lastMessage;
  final String time;
  final int unreadCount;
  final VoidCallback? onTap;

  const ChatCard({
    super.key,
    required this.imageUrl,
    required this.listingTitle,
    required this.userName,
    required this.lastMessage,
    required this.time,
    this.unreadCount = 0,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Container(
            width: double.infinity,
            clipBehavior: Clip.antiAlias,
            decoration: ShapeDecoration(
              color: const Color(0xFFFAFAFA),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 92,
                  height: 92,
                  clipBehavior: Clip.antiAlias,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    color: imageUrl.isEmpty ? Colors.grey[200] : null,
                  ),
                  child: imageUrl.isEmpty
                      ? const Icon(
                          Icons.image_not_supported,
                          size: 48,
                          color: Colors.grey,
                        )
                      : Image.network(
                          imageUrl,
                          fit: BoxFit.cover,
                          width: 92,
                          height: 92,
                          errorBuilder: (context, error, stackTrace) =>
                              Container(
                                color: Colors.grey[200],
                                child: const Icon(
                                  Icons.image_not_supported,
                                  size: 48,
                                  color: Colors.grey,
                                ),
                              ),
                        ),
                ),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                listingTitle,
                                style: const TextStyle(
                                  color: Colors.black,
                                  fontSize: 14,
                                  fontFamily: 'Inter',
                                  fontWeight: FontWeight.w500,
                                  height: 1.40,
                                  letterSpacing: 0.14,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              time,
                              style: const TextStyle(
                                color: Color(0xFF52525B),
                                fontSize: 12,
                                fontFamily: 'Inter',
                                fontWeight: FontWeight.w500,
                                height: 1.30,
                                letterSpacing: 0.24,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          userName,
                          style: const TextStyle(
                            color: Color(0xFF71717A),
                            fontSize: 12,
                            fontFamily: 'Inter',
                            fontWeight: FontWeight.w500,
                            height: 1.30,
                            letterSpacing: 0.24,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                lastMessage,
                                style: const TextStyle(
                                  color: Colors.black,
                                  fontSize: 14,
                                  fontFamily: 'Inter',
                                  fontWeight: FontWeight.w400,
                                  height: 1.43,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (unreadCount > 0) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 2,
                                ),
                                decoration: ShapeDecoration(
                                  color: const Color(0xFF83DAF5),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                ),
                                child: Text(
                                  '$unreadCount',
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    color: Color(0xFF015873),
                                    fontSize: 12,
                                    fontFamily: 'Inter',
                                    fontWeight: FontWeight.w500,
                                    height: 1.50,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class ChatDialogPage extends StatefulWidget {
  final String chatId;
  final String userName;
  final String userAvatarUrl;
  final String listingTitle;
  final String listingImageUrl;
  final String listingPrice;
  final String listingDate;
  final String listingLocation;

  const ChatDialogPage({
    super.key,
    required this.chatId,
    required this.userName,
    required this.userAvatarUrl,
    required this.listingTitle,
    required this.listingImageUrl,
    required this.listingPrice,
    required this.listingDate,
    required this.listingLocation,
  });

  @override
  State<ChatDialogPage> createState() => _ChatDialogPageState();
}

class _ChatDialogPageState extends State<ChatDialogPage> {
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _textController = TextEditingController();
  List<Map<String, dynamic>> _messages = [];
  bool _loading = true;
  String? _currentUserId;
  String? _anonymousUserId; // Додано для анонімних користувачів
  RealtimeChannel? _realtimeChannel;
  late final ComplaintService _complaintService;
  final TextEditingController _complaintDescriptionController =
      TextEditingController();
  String _selectedComplaintType = 'Інше';
  String? _listingId;

  @override
  void initState() {
    super.initState();
    _complaintService = ComplaintService(Supabase.instance.client);
    _currentUserId = Supabase.instance.client.auth.currentUser?.id;
    _loadAnonymousUserId();
    _loadMessages();
    _subscribeToNewMessages();
    _getListingId();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Позначаємо повідомлення як прочитані при зміні залежностей
    _markMessagesAsRead();
  }

  Future<void> _loadAnonymousUserId() async {
    final prefs = await SharedPreferences.getInstance();
    String? storedId = prefs.getString('anonymous_user_id');

    if (storedId == null) {
      storedId = const Uuid().v4();
      await prefs.setString('anonymous_user_id', storedId);
      print(
        'DEBUG (ChatDialogPage): Generated new anonymous user ID: $storedId',
      );
    } else {
      print(
        'DEBUG (ChatDialogPage): Loaded existing anonymous user ID: $storedId',
      );
    }

    setState(() {
      _anonymousUserId = storedId;
    });
  }

  Future<void> _getListingId() async {
    final client = Supabase.instance.client;
    final response = await client
        .from('chats')
        .select('listing_id')
        .eq('id', widget.chatId)
        .single();
    if (response.isNotEmpty) {
      setState(() {
        _listingId = response['listing_id'] as String?;
      });
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _textController.dispose();
    _complaintDescriptionController.dispose();
    _realtimeChannel?.unsubscribe();
    super.dispose();
  }

  Future<void> _loadMessages() async {
    setState(() => _loading = true);
    final client = Supabase.instance.client;
    final messages = await client
        .from('chat_messages')
        .select('*')
        .eq('chat_id', widget.chatId)
        .order('created_at', ascending: false)
        .limit(30);
    setState(() {
      _messages = List<Map<String, dynamic>>.from(messages.reversed);
      _loading = false;
    });
    _scrollToBottom();
    await _markMessagesAsRead();
  }

  Future<void> _markMessagesAsRead() async {
    final String? initiatorId = _currentUserId ?? _anonymousUserId;
    if (initiatorId == null) return;
    final client = Supabase.instance.client;
    try {
      final result = await client
          .from('chat_messages')
          .update({'is_read': true})
          .eq('chat_id', widget.chatId)
          .eq('is_read', false)
          .neq('sender_id', initiatorId)
          .select('id');
      if (result.isEmpty && mounted) {
        debugPrint(
          'ChatDialogPage: Mark as read affected 0 rows (check RLS on chat_messages)',
        );
      }
    } catch (e) {
      debugPrint('ChatDialogPage: Failed to mark messages as read: $e');
    }
  }

  void _subscribeToNewMessages() {
    final client = Supabase.instance.client;
    _realtimeChannel = client.channel('public:chat_messages')
      ..on(
        RealtimeListenTypes.postgresChanges,
        ChannelFilter(
          event: 'INSERT',
          schema: 'public',
          table: 'chat_messages',
          filter: 'chat_id=eq.${widget.chatId}',
        ),
        (payload, [ref]) {
          final newMessage = payload['new'] as Map<String, dynamic>;

          // Ігноруємо тимчасові повідомлення
          if (newMessage['is_temp'] == true) return;

          // Перевіряємо, чи це повідомлення не вже є в списку
          final messageId = newMessage['id'];
          final existingMessage = _messages.any(
            (msg) => msg['id'] == messageId,
          );

          if (!existingMessage) {
            setState(() {
              _messages.add(newMessage);
            });
            _scrollToBottom();
          }

          // Позначаємо нове повідомлення як прочитане, якщо воно не від нас
          final String? initiatorId = _currentUserId ?? _anonymousUserId;
          if (newMessage['sender_id'] != initiatorId) {
            _markMessagesAsRead();
          }
        },
      )
      ..subscribe();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
      }
    });
  }

  void _showComplaintBottomSheet() {
    if (_listingId == null) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => ComplaintModal(productId: _listingId!),
    ).then((success) {
      if (success == true) {
        _showSuccessBottomSheet();
      }
    });
  }

  void _showSuccessBottomSheet() {
    showModalBottomSheet(
      context: context,
      isDismissible: false,
      builder: (context) => SuccessBottomSheet(
        title: 'Скаргу надіслано',
        message: 'Дякуємо за вашу скаргу! Ми розглянемо її якнайшвидше.',
        onClose: () {
          Navigator.of(context).pop(); // Close the success bottom sheet
        },
      ),
    );
  }

  void _showDeleteChatOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Заголовок з іконкою хрестика
            Container(
              padding: const EdgeInsets.only(
                top: 20,
                left: 16,
                right: 16,
                bottom: 16,
              ),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Опції чату',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Icon(
                        Icons.close,
                        size: 20,
                        color: Colors.grey,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Опції
            _buildBottomSheetOption(
              icon: Icons.report_problem_outlined,
              title: 'Надіслати скаргу',
              color: Colors.orange,
              onTap: () {
                Navigator.pop(context);
                _showComplaintBottomSheet();
              },
            ),
            const Divider(height: 1, indent: 16, endIndent: 16),
            _buildBottomSheetOption(
              icon: Icons.delete_outline,
              title: 'Видалити чат',
              color: Colors.red,
              onTap: () {
                Navigator.pop(context);
                _showDeleteConfirmation();
              },
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomSheetOption({
    required IconData icon,
    required String title,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 0, vertical: 4),
        leading: Icon(icon, color: color, size: 22),
        title: Text(
          title,
          style: TextStyle(
            color: color,
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
        ),
        onTap: onTap,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  void _showDeleteConfirmation() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Заголовок з іконкою хрестика
            Container(
              padding: const EdgeInsets.only(
                top: 20,
                left: 24,
                right: 24,
                bottom: 16,
              ),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Видалити чат?',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Icon(
                        Icons.close,
                        size: 20,
                        color: Colors.grey,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Опис
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text(
                'Ви впевнені, що хочете видалити цей чат? Цю дію неможливо буде скасувати.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, color: Colors.grey[600]),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        side: BorderSide(color: Colors.grey[300]!),
                      ),
                      child: Text(
                        'Скасувати',
                        style: TextStyle(color: Colors.grey[700]),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context); // Close confirmation
                        _deleteChat();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: const Text(
                        'Так, видалити',
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Future<void> _deleteChat() async {
    try {
      final client = Supabase.instance.client;
      // 1. Delete messages
      await client.from('chat_messages').delete().eq('chat_id', widget.chatId);
      // 2. Delete participants
      await client
          .from('chat_participants')
          .delete()
          .eq('chat_id', widget.chatId);
      // 3. Delete chat
      await client.from('chats').delete().eq('id', widget.chatId);

      // Navigate back after deletion
      if (mounted) {
        Navigator.pop(context);
      }
    } catch (e) {
      // Handle error
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Не вдалося видалити чат. Спробуйте ще раз.'),
          ),
        );
      }
    }
  }

  Future<void> _pickAndUploadImage() async {
    print('DEBUG (ChatDialogPage): _pickAndUploadImage called.');
    final picker = ImagePicker();
    // Pick an image
    final XFile? imageFile = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 600,
    );

    if (imageFile == null) {
      print('DEBUG (ChatDialogPage): No image selected, returning.');
      return;
    }
    final String? initiatorId = _currentUserId ?? _anonymousUserId;
    print(
      'DEBUG (ChatDialogPage): Initiator ID for image upload: $initiatorId',
    );
    if (initiatorId == null) {
      print(
        'DEBUG (ChatDialogPage): Initiator ID is null for image upload, returning.',
      );
      return;
    }

    final client = Supabase.instance.client;
    final imageExtension = imageFile.name.split('.').last.toLowerCase();
    final imageBytes = await imageFile.readAsBytes();
    final imagePath =
        '$initiatorId/${DateTime.now().millisecondsSinceEpoch}.$imageExtension';

    try {
      print(
        'DEBUG (ChatDialogPage): Attempting to upload image to Supabase storage.',
      );
      await client.storage
          .from('chat_images')
          .uploadBinary(
            imagePath,
            imageBytes,
            fileOptions: FileOptions(
              upsert: false,
              contentType: imageFile.mimeType,
            ),
          );

      final imageUrl = client.storage
          .from('chat_images')
          .getPublicUrl(imagePath);
      await _sendMessage(imageUrl: imageUrl);
    } catch (e) {
      if (mounted) {
        // Error loading photo
      }
    }
  }

  Future<void> _sendMessage({String? imageUrl}) async {
    print('DEBUG (ChatDialogPage): _sendMessage called.');
    final text = _textController.text.trim();
    final String? initiatorId = _currentUserId ?? _anonymousUserId;
    print(
      'DEBUG (ChatDialogPage): Current User ID: $_currentUserId, Anonymous User ID: $_anonymousUserId, Initiator ID: $initiatorId',
    );
    if ((text.isEmpty && imageUrl == null) || initiatorId == null) {
      print(
        'DEBUG (ChatDialogPage): Message content is empty or initiator ID is null, returning.',
      );
      return;
    }

    // Додаємо тимчасове повідомлення для кращого UX
    final tempMessage = {
      'id': 'temp_${DateTime.now().millisecondsSinceEpoch}',
      'chat_id': widget.chatId,
      'sender_id': initiatorId,
      'content': text.isNotEmpty ? text : null,
      'image_url': imageUrl,
      'created_at': DateTime.now().toIso8601String(),
      'is_temp': true,
    };

    setState(() {
      _messages.add(tempMessage);
    });
    _scrollToBottom();

    final client = Supabase.instance.client;

    final messageData = {
      'chat_id': widget.chatId,
      'sender_id': initiatorId,
      'content': text.isNotEmpty ? text : null,
      'image_url': imageUrl,
    };

    try {
      print(
        'DEBUG (ChatDialogPage): Attempting to insert message into Supabase.',
      );
      await client.from('chat_messages').insert(messageData).select().single();
      print('DEBUG (ChatDialogPage): Message successfully inserted.');

      if (imageUrl == null) {
        _textController.clear();
      }

      // Видаляємо тимчасове повідомлення після успішного відправлення
      setState(() {
        _messages.removeWhere((msg) => msg['is_temp'] == true);
      });
    } catch (e, stackTrace) {
      print('ERROR (ChatDialogPage): Failed to send message: $e');
      print('STACK (ChatDialogPage): $stackTrace');
      // Видаляємо тимчасове повідомлення при помилці
      setState(() {
        _messages.removeWhere((msg) => msg['is_temp'] == true);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(56),
        child: ChatAppBar(
          userName: widget.userName,
          userAvatarUrl: widget.userAvatarUrl,
          onBack: () => Navigator.of(context).pop(),
          onMenu: () => _showDeleteChatOptions(),
        ),
      ),
      body: Column(
        children: [
          ChatListingCard(
            imageUrl: widget.listingImageUrl,
            title: widget.listingTitle,
            price: widget.listingPrice,
            date: widget.listingDate,
            location: widget.listingLocation,
          ),
          // Видалити Divider над полем для введення повідомлення
          // const Divider(height: 1),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _messages.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.only(top: 40),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            mainAxisAlignment: MainAxisAlignment.start,
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Container(
                                width: 52,
                                height: 52,
                                child: Stack(
                                  children: [
                                    Positioned(
                                      left: 0,
                                      top: 0,
                                      child: Container(
                                        width: 52,
                                        height: 52,
                                        decoration: const ShapeDecoration(
                                          color: Color(0xFFFAFAFA),
                                          shape: OvalBorder(),
                                        ),
                                      ),
                                    ),
                                    const Positioned(
                                      left: 14,
                                      top: 14,
                                      child: Icon(
                                        Icons.chat_bubble_outline,
                                        size: 24,
                                        color: Color(0xFF52525B),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 20),
                              Container(
                                width: double.infinity,
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  mainAxisAlignment: MainAxisAlignment.start,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    SizedBox(
                                      width: double.infinity,
                                      child: const Text(
                                        'Немає повідомлень',
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          color: Color(0xFF667084),
                                          fontSize: 16,
                                          fontFamily: 'Inter',
                                          fontWeight: FontWeight.w400,
                                          height: 1.40,
                                          letterSpacing: 0.16,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  )
                : Container(
                    color: const Color(0xFFFAFAFA),
                    child: ListView.builder(
                      key: ValueKey(_messages.length),
                      controller: _scrollController,
                      padding: const EdgeInsets.symmetric(
                        vertical: 16,
                        horizontal: 13,
                      ),
                      itemCount: _messages.length,
                      itemBuilder: (context, index) {
                        final msg = _messages[index];
                        final String? initiatorId =
                            _currentUserId ?? _anonymousUserId;
                        final isMe = msg['sender_id'] == initiatorId;
                        final senderName = isMe ? 'Ви' : widget.userName;
                        final senderAvatarUrl = isMe
                            ? null
                            : widget.userAvatarUrl;
                        final text = msg['content'] as String?;
                        final imageUrl = msg['image_url'] as String?;
                        final createdAt =
                            DateTime.tryParse(msg['created_at'] ?? '') ??
                            DateTime.now();
                        final time = _formatMessageTime(createdAt);
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: MessageBubble(
                            isMe: isMe,
                            senderName: senderName,
                            senderAvatarUrl: senderAvatarUrl,
                            text: text,
                            imageUrl: imageUrl,
                            time: time,
                          ),
                        );
                      },
                    ),
                  ),
          ),
          // Прибрати Divider або border в самому низу сторінки відкритого чату
          // const Divider(height: 1),
          if (widget.listingTitle != 'Оголошення видалено')
            Container(
              width: double.infinity,
              padding: const EdgeInsets.only(left: 16, right: 16, bottom: 36),
              decoration: const BoxDecoration(color: Colors.white),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.end,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.start,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: double.infinity,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            mainAxisAlignment: MainAxisAlignment.start,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: double.infinity,
                                height: 44,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 0,
                                ),
                                clipBehavior: Clip.antiAlias,
                                decoration: ShapeDecoration(
                                  color: const Color(0xFFFAFAFA) /* Zinc-50 */,
                                  shape: RoundedRectangleBorder(
                                    side: const BorderSide(
                                      width: 1,
                                      color: Color(0xFFE4E4E7) /* Zinc-200 */,
                                    ),
                                    borderRadius: BorderRadius.circular(200),
                                  ),
                                  shadows: const [
                                    BoxShadow(
                                      color: Color(0x0C101828),
                                      blurRadius: 2,
                                      offset: Offset(0, 1),
                                      spreadRadius: 0,
                                    ),
                                  ],
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  mainAxisAlignment: MainAxisAlignment.start,
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    Expanded(
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        mainAxisAlignment:
                                            MainAxisAlignment.start,
                                        crossAxisAlignment:
                                            CrossAxisAlignment.center,
                                        children: [
                                          GestureDetector(
                                            onTap: _pickAndUploadImage,
                                            child: Container(
                                              width: 24,
                                              height: 24,
                                              clipBehavior: Clip.antiAlias,
                                              decoration: const BoxDecoration(),
                                              child: const Icon(
                                                Icons.photo,
                                                color: Color(0xFF52525B),
                                                size: 24,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: TextField(
                                              controller: _textController,
                                              textAlignVertical:
                                                  TextAlignVertical.center,
                                              decoration: const InputDecoration(
                                                hintText:
                                                    'Написати повідомлення',
                                                hintStyle: TextStyle(
                                                  color: Color(
                                                    0xFFA1A1AA,
                                                  ) /* Zinc-400 */,
                                                  fontSize: 16,
                                                  fontFamily: 'Inter',
                                                  fontWeight: FontWeight.w400,
                                                  height: 1.50,
                                                  letterSpacing: 0.16,
                                                ),
                                                border: InputBorder.none,
                                                isDense: true,
                                                contentPadding: EdgeInsets.zero,
                                              ),
                                              minLines: 1,
                                              maxLines: 1,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  GestureDetector(
                    onTap: () => _sendMessage(),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      clipBehavior: Clip.antiAlias,
                      decoration: ShapeDecoration(
                        color: const Color(0xFF015873) /* Primary */,
                        shape: RoundedRectangleBorder(
                          side: const BorderSide(
                            width: 1,
                            color: Color(0xFF015873) /* Primary */,
                          ),
                          borderRadius: BorderRadius.circular(200),
                        ),
                        shadows: const [
                          BoxShadow(
                            color: Color(0x0C101828),
                            blurRadius: 2,
                            offset: Offset(0, 1),
                            spreadRadius: 0,
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Container(
                            width: 20,
                            height: 20,
                            clipBehavior: Clip.antiAlias,
                            decoration: const BoxDecoration(),
                            child: const Icon(
                              Icons.send,
                              color: Colors.white,
                              size: 20,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  String _formatMessageTime(DateTime dateTime) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final messageDate = DateTime(dateTime.year, dateTime.month, dateTime.day);

    // Форматуємо час
    final time =
        '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';

    if (messageDate == today) {
      return 'Сьогодні $time';
    } else if (messageDate == yesterday) {
      return 'Вчора $time';
    } else if (now.difference(dateTime).inDays < 7) {
      // Цього тижня - показуємо день тижня
      return '${_weekdayName(dateTime.weekday)} $time';
    } else {
      // Старіше - показуємо дату
      return '${dateTime.day.toString().padLeft(2, '0')}.${dateTime.month.toString().padLeft(2, '0')}.${dateTime.year} $time';
    }
  }

  String _formatChatListTime(DateTime dateTime) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final messageDate = DateTime(dateTime.year, dateTime.month, dateTime.day);

    // Форматуємо час
    final time =
        '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';

    if (messageDate == today) {
      return time; // Тільки час для сьогодні
    } else if (messageDate == yesterday) {
      return 'Вчора';
    } else if (now.difference(dateTime).inDays < 7) {
      // Цього тижня - показуємо короткий день тижня
      return _shortWeekdayName(dateTime.weekday);
    } else {
      // Старіше - показуємо коротку дату
      return '${dateTime.day.toString().padLeft(2, '0')}.${dateTime.month.toString().padLeft(2, '0')}';
    }
  }

  String _shortWeekdayName(int weekday) {
    const names = ['', 'Пн', 'Вт', 'Ср', 'Чт', 'Пт', 'Сб', 'Нд'];
    return names[weekday];
  }

  String _weekdayName(int weekday) {
    const names = [
      '',
      'Понеділок',
      'Вівторок',
      'Середа',
      'Четвер',
      'Пʼятниця',
      'Субота',
      'Неділя',
    ];
    return names[weekday];
  }
}

class MessageBubble extends StatelessWidget {
  final bool isMe;
  final String senderName;
  final String? senderAvatarUrl;
  final String? text;
  final String? imageUrl;
  final String time;

  const MessageBubble({
    super.key,
    required this.isMe,
    required this.senderName,
    this.senderAvatarUrl,
    this.text,
    this.imageUrl,
    required this.time,
  });

  @override
  Widget build(BuildContext context) {
    final bubbleColor = isMe
        ? const Color(0xFF015873)
        : const Color(0xFFF4F4F5);
    final textColor = isMe ? Colors.white : Colors.black;
    final borderRadius = isMe
        ? const BorderRadius.only(
            topLeft: Radius.circular(8),
            bottomRight: Radius.circular(8),
            bottomLeft: Radius.circular(8),
          )
        : const BorderRadius.only(
            topRight: Radius.circular(8),
            bottomRight: Radius.circular(8),
            bottomLeft: Radius.circular(8),
          );

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: isMe
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        children: [
          if (!isMe)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: senderAvatarUrl != null && senderAvatarUrl!.isNotEmpty
                  ? CircleAvatar(
                      radius: 20,
                      backgroundImage: NetworkImage(senderAvatarUrl!),
                    )
                  : const CircleAvatar(
                      radius: 20,
                      backgroundColor: Color(0xFFE4E4E7),
                      child: Icon(Icons.person, color: Color(0xFF71717A)),
                    ),
            ),
          Expanded(
            child: Column(
              crossAxisAlignment: isMe
                  ? CrossAxisAlignment.end
                  : CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: isMe
                      ? MainAxisAlignment.end
                      : MainAxisAlignment.start,
                  children: [
                    Text(
                      isMe ? 'Ви' : senderName,
                      style: const TextStyle(
                        color: Color(0xFF344054),
                        fontSize: 14,
                        fontFamily: 'Inter',
                        fontWeight: FontWeight.w500,
                        height: 1.43,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      time,
                      style: const TextStyle(
                        color: Color(0xFF52525B),
                        fontSize: 12,
                        fontFamily: 'Inter',
                        fontWeight: FontWeight.w400,
                        height: 1.3,
                        letterSpacing: 0.24,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                if (text != null)
                  Align(
                    alignment: isMe
                        ? Alignment.centerRight
                        : Alignment.centerLeft,
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        maxWidth: MediaQuery.of(context).size.width * 0.8,
                        minWidth: 0,
                      ),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: bubbleColor,
                          borderRadius: borderRadius,
                        ),
                        child: Text(
                          text!,
                          style: TextStyle(
                            color: textColor,
                            fontSize: 16,
                            fontFamily: 'Inter',
                            fontWeight: FontWeight.w400,
                            height: 1.5,
                          ),
                        ),
                      ),
                    ),
                  ),
                if (imageUrl != null)
                  ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: MediaQuery.of(context).size.width * 0.8,
                      minWidth: 0,
                    ),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: bubbleColor,
                        borderRadius: borderRadius,
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: GestureDetector(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => FullScreenImageSliderPage(
                                  imageUrls: [imageUrl!],
                                  initialIndex: 0,
                                  showNavigation:
                                      false, // Приховуємо навігацію для одного зображення в чаті
                                ),
                              ),
                            );
                          },
                          child: Image.network(
                            imageUrl!,
                            height: 200,
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class ChatAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String userName;
  final String userAvatarUrl;
  final VoidCallback onBack;
  final VoidCallback? onMenu;

  const ChatAppBar({
    super.key,
    required this.userName,
    required this.userAvatarUrl,
    required this.onBack,
    this.onMenu,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      child: SafeArea(
        bottom: false,
        child: Container(
          height: 56,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              // Back button
              IconButton(
                onPressed: onBack,
                icon: const Icon(
                  Icons.chevron_left,
                  size: 28,
                  color: Colors.black,
                ),
                style: IconButton.styleFrom(
                  padding: const EdgeInsets.all(10),
                  shape: const CircleBorder(),
                  backgroundColor: Colors.transparent,
                ),
              ),
              // Avatar and name
              Expanded(
                child: Row(
                  children: [
                    // Avatar
                    userAvatarUrl.isNotEmpty
                        ? CircleAvatar(
                            radius: 20,
                            backgroundImage: NetworkImage(userAvatarUrl),
                          )
                        : const CircleAvatar(
                            radius: 20,
                            backgroundColor: Color(0xFFE4E4E7),
                            child: Icon(Icons.person, color: Color(0xFF71717A)),
                          ),
                    const SizedBox(width: 8),
                    // Name
                    Expanded(
                      child: Text(
                        userName,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          fontFamily: 'Inter',
                          color: Colors.black,
                          letterSpacing: 0.14,
                          height: 1.4,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              // Menu button
              IconButton(
                onPressed: onMenu,
                icon: const Icon(Icons.more_vert, color: Colors.black),
                style: IconButton.styleFrom(
                  padding: const EdgeInsets.all(10),
                  shape: const CircleBorder(),
                  backgroundColor: Colors.transparent,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(56);
}

class ChatListingCard extends StatelessWidget {
  final String imageUrl;
  final String title;
  final String price;
  final String date;
  final String location;

  const ChatListingCard({
    super.key,
    required this.imageUrl,
    required this.title,
    required this.price,
    required this.date,
    required this.location,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(height: 1, color: Color(0xFFE4E4E7)),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Фото оголошення або заглушка (без заокруглень)
              imageUrl.isNotEmpty
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(
                        8,
                      ), // Заокруглення країв для зображення
                      child: Image.network(
                        imageUrl,
                        width: 40,
                        height: 40,
                        fit: BoxFit.cover,
                      ),
                    )
                  : Container(
                      width: 40,
                      height: 40,
                      color: Colors.grey[200],
                      child: const Icon(
                        Icons.image_not_supported,
                        color: Colors.grey,
                        size: 24,
                      ),
                    ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            style: const TextStyle(
                              color: Colors.black,
                              fontSize: 14,
                              fontFamily: 'Inter',
                              fontWeight: FontWeight.w500, // medium
                              height: 1.4,
                              letterSpacing: 0.14,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 16),
                        if (date.isNotEmpty)
                          Text(
                            date,
                            style: const TextStyle(
                              color: Color(0xFF838583),
                              fontSize: 12,
                              fontFamily: 'Inter',
                              fontWeight: FontWeight.w400,
                              height: 1.3,
                              letterSpacing: 0.24,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(
                          child: Text(
                            price.isNotEmpty ? price : 'Ціна не вказана',
                            style: const TextStyle(
                              color: Color(0xFF52525B),
                              fontSize: 12,
                              fontFamily: 'Inter',
                              fontWeight: FontWeight.w500, // medium
                              height: 1.3,
                              letterSpacing: 0.24,
                            ),
                          ),
                        ),
                        if (location.isNotEmpty)
                          Text(
                            location,
                            style: const TextStyle(
                              color: Color(0xFFA1A1AA),
                              fontSize: 12,
                              fontFamily: 'Inter',
                              fontWeight: FontWeight.w500, // medium
                              height: 1.3,
                              letterSpacing: 0.24,
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        Container(height: 1, color: Color(0xFFE4E4E7)),
      ],
    );
  }
}
