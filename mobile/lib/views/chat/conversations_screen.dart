import 'package:flutter/material.dart';
import 'package:quickfix/core/theme/app_theme.dart';
import 'package:quickfix/core/widgets/user_avatar.dart';
import 'package:quickfix/models/user_model.dart';
import 'package:quickfix/services/auth_service.dart';
import 'package:quickfix/services/chat_service.dart';
import 'package:quickfix/services/profile_service.dart';
import 'package:quickfix/views/chat/chat_screen.dart';
import 'package:quickfix/views/chat/new_chat_screen.dart';

/// Messages tab: list of recent conversations with the peer's name,
/// last message preview, unread badge and a New Chat worker search.
class ConversationsScreen extends StatefulWidget {
  final UserModel user;
  final ChatService? chatService;
  final AuthService? authService;
  final ProfileService? profileService;

  const ConversationsScreen({
    super.key,
    required this.user,
    this.chatService,
    this.authService,
    this.profileService,
  });

  @override
  State<ConversationsScreen> createState() => _ConversationsScreenState();
}

class _ConversationsScreenState extends State<ConversationsScreen> {
  late final ChatService _chatService = widget.chatService ?? ChatService();
  late final AuthService _authService = widget.authService ?? AuthService();
  final Map<String, String> _peerNames = {};
  final Map<String, String?> _peerAvatars = {};

  Future<String> _resolvePeerName(String peerId) async {
    final cached = _peerNames[peerId];
    if (cached != null) return cached;
    final peer = await _authService.getUserProfile(peerId);
    final name = peer?.fullName.isNotEmpty == true ? peer!.fullName : peerId;
    _peerNames[peerId] = name;
    if (peer?.avatarUrl != null) _peerAvatars[peerId] = peer!.avatarUrl;
    return name;
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final local = time.toLocal();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(local.year, local.month, local.day);
    if (day == today) {
      final h = local.hour.toString().padLeft(2, '0');
      final m = local.minute.toString().padLeft(2, '0');
      return '$h:$m';
    }
    return '${local.day}/${local.month}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bgLight,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: StreamBuilder<List<ConversationPreview>>(
                stream: _chatService.watchConversations(widget.user.uid),
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return const Center(
                      child: Text(
                        'Could not load conversations',
                        style: TextStyle(fontSize: 12, color: AppTheme.textMuted),
                      ),
                    );
                  }
                  if (!snapshot.hasData || snapshot.data!.isEmpty) {
                    return _buildEmptyState();
                  }
                  return ListView.separated(
                    padding: const EdgeInsets.all(14),
                    itemCount: snapshot.data!.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (context, index) =>
                        _buildConversationTile(snapshot.data![index]),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final titleBlock = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Messages',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 2),
        const Text(
          'Chat with workers on your jobs',
          style: TextStyle(fontSize: 12, color: Colors.white70),
        ),
      ],
    );
    final newChat = GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => NewChatScreen(
            user: widget.user,
            chatService: _chatService,
            profileService: widget.profileService,
          ),
        ),
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
        ),
        child: const Text(
          'New Chat',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: AppTheme.brandBlue,
          ),
        ),
      ),
    );
    // Above ~1.4x text scale the title block and the New Chat
    // action no longer fit one row; stack them so neither is
    // squeezed into unreadable wrapping.
    final stacked = MediaQuery.textScalerOf(context).scale(14) > 20;
    return Container(
      width: double.infinity,
      color: AppTheme.brandBlue,
      padding: const EdgeInsets.fromLTRB(16, 14, 12, 16),
      child: stacked
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                titleBlock,
                const SizedBox(height: 8),
                Align(alignment: Alignment.centerRight, child: newChat),
              ],
            )
          : Row(
              children: [
                Expanded(child: titleBlock),
                newChat,
              ],
            ),
    );
  }

  Widget _buildEmptyState() {
    // Scrollable so the state never overflows a tight viewport
    // at a large accessibility text scale.
    return SingleChildScrollView(
      child: Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.chat_bubble_outline,
              size: 48, color: AppTheme.textMuted),
          const SizedBox(height: 12),
          const Text(
            'No conversations yet',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppTheme.textDark,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Tap New Chat to find a worker and start messaging',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: AppTheme.textMuted),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => NewChatScreen(
                  user: widget.user,
                  chatService: _chatService,
                  profileService: widget.profileService,
                ),
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.ctaOrange,
              foregroundColor: Colors.white,
            ),
            child: const Text('New Chat'),
          ),
        ],
      ),
      ),
    );
  }

  Widget _buildConversationTile(ConversationPreview conversation) {
    final peerId = conversation.participants
        .where((p) => p != widget.user.uid)
        .firstOrNull;

    if (peerId == null) return const SizedBox.shrink();

    return FutureBuilder<String>(
      future: _resolvePeerName(peerId),
      builder: (context, snapshot) {
        final name = snapshot.data ?? peerId;
        final isUnread = conversation.unreadCount > 0;
        return Material(
          color: AppTheme.surfaceWhite,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: AppTheme.borderGray),
          ),
          clipBehavior: Clip.antiAlias,
          child: ListTile(
            leading: UserAvatar(
              fullName: name,
              avatarUrl: _peerAvatars[peerId],
            ),
            title: Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppTheme.textDark,
              ),
            ),
            subtitle: Text(
              conversation.lastMessage,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12, color: AppTheme.textMuted),
            ),
            trailing: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  _formatTime(conversation.lastMessageAt),
                  style: const TextStyle(fontSize: 10, color: AppTheme.textMuted),
                ),
                if (isUnread) ...[
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppTheme.ctaOrange,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '${conversation.unreadCount}',
                      style: const TextStyle(
                          fontSize: 10, color: Colors.white,
                          fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ],
            ),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ChatScreen(
                  peerName: name,
                  peerId: peerId,
                  myId: widget.user.uid,
                  chatService: _chatService,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}