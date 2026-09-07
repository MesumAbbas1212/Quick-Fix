import 'package:flutter/material.dart';
import 'package:quickfix/core/theme/app_theme.dart';
import 'package:quickfix/models/chat_message.dart';
import 'package:quickfix/services/chat_service.dart';
import 'package:quickfix/services/location_service.dart';
import 'package:quickfix/services/map_launcher.dart';

class ChatScreen extends StatefulWidget {
  final String peerName;
  final String peerId;
  final String myId;
  final ChatService? chatService;
  final LocationService? locationService;
  final UrlLauncher? urlLauncher;

  const ChatScreen({
    super.key,
    required this.peerName,
    required this.peerId,
    required this.myId,
    this.chatService,
    this.locationService,
    this.urlLauncher,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  late final ChatService _chatService = widget.chatService ?? ChatService();
  late final LocationService _locationService =
      widget.locationService ?? LocationService();
  late final UrlLauncher _urlLauncher =
      widget.urlLauncher ?? const MapLauncher();
  bool _isSending = false;
  int _lastMessageCount = 0;

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _sendMessage({String? textOverride}) async {
    final text = textOverride ?? _messageController.text.trim();
    if (text.isEmpty || _isSending) return;
    setState(() => _isSending = true);
    try {
      await _chatService.sendMessage(
        senderId: widget.myId,
        receiverId: widget.peerId,
        text: text,
      );
      _messageController.clear();
      _scrollToBottom();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to send message. Check your connection.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  Future<void> _shareLocation() async {
    final location = await _locationService.getCurrentLocation();
    if (!mounted) return;
    if (location == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Location permission is required to share your location. '
            'Please enable it in app settings and try again.',
          ),
        ),
      );
      return;
    }
    await _chatService.sendMessage(
      senderId: widget.myId,
      receiverId: widget.peerId,
      text: 'Shared my location',
      attachmentType: 'location',
      attachmentUrl:
          '${location.latitude.toStringAsFixed(5)}, '
          '${location.longitude.toStringAsFixed(5)}',
    );
    _scrollToBottom();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _markConversationRead() {
    // Clear the unread badge for this conversation while the chat is open.
    _chatService
        .markAsRead(
          conversationId:
              _chatService.conversationIdFor(widget.myId, widget.peerId),
          userId: widget.myId,
        )
        .catchError((_) {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bgLight,
      body: _buildPhoneScreen(),
    );
  }

  Stream<List<ChatMessage>> _watchMessages() {
    try {
      return _chatService.watchMessages(
        user1: widget.myId,
        user2: widget.peerId,
      );
    } catch (_) {
      return Stream<List<ChatMessage>>.error('Chat unavailable');
    }
  }

  Widget _buildPhoneScreen() {
    return SafeArea(
      child: Column(
        children: [
          _buildHeader(),
          Expanded(
            child: StreamBuilder<List<ChatMessage>>(
              stream: _watchMessages(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return const Center(
                    child: Text(
                      'Could not load messages',
                      style: TextStyle(fontSize: 12, color: AppTheme.textMuted),
                    ),
                  );
                }
                final messages = snapshot.data;
                if (messages == null) {
                  return const Center(
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppTheme.brandBlue,
                    ),
                  );
                }
                if (messages.length > _lastMessageCount) {
                  _lastMessageCount = messages.length;
                  _scrollToBottom();
                  _markConversationRead();
                }
                if (messages.isEmpty) {
                  return const Center(
                    child: Text(
                      'No messages yet - say hi!',
                      style: TextStyle(fontSize: 12, color: AppTheme.textMuted),
                    ),
                  );
                }
                return _buildMessages(messages);
              },
            ),
          ),
          _buildInputBar(),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      color: AppTheme.brandBlue,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white, size: 20),
            onPressed: () => Navigator.pop(context),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              widget.peerName,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ),
          const Icon(Icons.more_vert, color: Colors.white, size: 20),
        ],
      ),
    );
  }

  Widget _buildMessages(List<ChatMessage> messages) {
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.all(14),
      itemCount: messages.length,
      itemBuilder: (context, index) {
        final msg = messages[index];
        final isMine = msg.senderId == widget.myId;
        return _buildMessageBubble(msg, isMine);
      },
    );
  }

  Widget _buildMessageBubble(ChatMessage msg, bool isMine) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: isMine
            ? CrossAxisAlignment.end
            : CrossAxisAlignment.start,
        children: [
          if (msg.attachmentType == 'location')
            _buildMapAttachment(msg)
          else
            Container(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.75,
              ),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: isMine ? AppTheme.chatBlue : AppTheme.surfaceWhite,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(16),
                  topRight: const Radius.circular(16),
                  bottomLeft: Radius.circular(isMine ? 16 : 4),
                  bottomRight: Radius.circular(isMine ? 4 : 16),
                ),
                border: isMine ? null : Border.all(color: AppTheme.borderGray),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 4,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              child: Text(
                msg.text,
                style: TextStyle(
                  fontSize: 12,
                  color: isMine ? Colors.white : AppTheme.textDark,
                ),
              ),
            ),
          const SizedBox(height: 2),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text(
              _formatTime(msg.createdAt),
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: AppTheme.textMuted,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openLocation(ChatMessage msg) async {
    final coords = _parseCoords(msg.attachmentUrl ?? msg.text);
    if (coords == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not open this location. It may be invalid.'),
        ),
      );
      return;
    }
    final opened = await _urlLauncher.openLocation(coords.$1, coords.$2);
    if (!opened && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No map app found on this device.'),
        ),
      );
    }
  }

  /// Parses "lat, lng" coordinate strings shared by the location picker.
  (double, double)? _parseCoords(String raw) {
    final parts = raw
        .split(RegExp(r'[,\s]+'))
        .map(double.tryParse)
        .whereType<double>()
        .toList();
    if (parts.length < 2) return null;
    final lat = parts[0];
    final lng = parts[1];
    if (lat < -90 || lat > 90 || lng < -180 || lng > 180) return null;
    return (lat, lng);
  }

  Widget _buildMapAttachment(ChatMessage msg) {
    return GestureDetector(
      key: const Key('location-bubble'),
      onTap: () => _openLocation(msg),
      child: Container(
        width: 200,
        decoration: BoxDecoration(
          color: AppTheme.surfaceWhite,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.borderGray),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 4,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height: 112,
              width: double.infinity,
              decoration: BoxDecoration(
                color: const Color(0xFFE5E9EC),
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(16),
                ),
                gradient: RadialGradient(
                  colors: [const Color(0xFFCBD5E1), const Color(0xFFE5E9EC)],
                  radius: 1.5,
                ),
              ),
              child: Center(
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: AppTheme.dangerRed,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.dangerRed.withValues(alpha: 0.4),
                        blurRadius: 8,
                      ),
                    ],
                  ),
                  child: const Center(
                    child: Text('📍', style: TextStyle(fontSize: 16)),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Shared Location',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textDark,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    msg.attachmentUrl ?? msg.text,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppTheme.textMuted,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(
                        Icons.map_outlined,
                        size: 12,
                        color: AppTheme.ctaOrange,
                      ),
                      const SizedBox(width: 3),
                      Flexible(
                        child: Text(
                          'Tap to open in Google Maps',
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.ctaOrange,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _formatTime(msg.createdAt),
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppTheme.textMuted,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInputBar() {
    return Container(
      color: AppTheme.surfaceWhite,
      padding: const EdgeInsets.all(10),
      child: Row(
        children: [
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9), // slate-100
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: AppTheme.borderGray),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _messageController,
                      decoration: const InputDecoration(
                        hintText: 'Type a message...',
                        hintStyle: TextStyle(
                          fontSize: 12,
                          color: AppTheme.textMuted,
                        ),
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: EdgeInsets.zero,
                      ),
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppTheme.textDark,
                      ),
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _sendMessage(),
                    ),
                  ),
                  GestureDetector(
                    onTap: _shareLocation,
                    child: const Icon(
                      Icons.location_on,
                      size: 18,
                      color: AppTheme.ctaOrange,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: _isSending ? null : () => _sendMessage(),
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: AppTheme.brandBlue,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.brandBlue.withValues(alpha: 0.3),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: const Icon(Icons.send, color: Colors.white, size: 16),
            ),
          ),
        ],
      ),
    );
  }

  String _formatTime(DateTime time) {
    final h = time.hour > 12 ? time.hour - 12 : time.hour;
    final period = time.hour >= 12 ? 'PM' : 'AM';
    return '$h:${time.minute.toString().padLeft(2, '0')} $period';
  }
}
