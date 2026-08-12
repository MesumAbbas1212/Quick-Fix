import 'package:flutter/material.dart';
import 'package:quickfix/core/theme/app_theme.dart';
import 'package:quickfix/core/widgets/user_avatar.dart';
import 'package:quickfix/models/user_model.dart';
import 'package:quickfix/models/worker_profile.dart';
import 'package:quickfix/services/chat_service.dart';
import 'package:quickfix/services/profile_service.dart';
import 'package:quickfix/views/chat/chat_screen.dart';

/// Search workers and start a new conversation.
class NewChatScreen extends StatefulWidget {
  final UserModel user;
  final ProfileService? profileService;
  final ChatService? chatService;

  const NewChatScreen({
    super.key,
    required this.user,
    this.profileService,
    this.chatService,
  });

  @override
  State<NewChatScreen> createState() => _NewChatScreenState();
}

class _NewChatScreenState extends State<NewChatScreen> {
  late final ProfileService _profileService =
      widget.profileService ?? ProfileService();
  late final ChatService _chatService = widget.chatService ?? ChatService();
  final _searchController = TextEditingController();
  late final Future<List<WorkerProfile>> _workersFuture;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _workersFuture = _profileService.searchWorkers();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<WorkerProfile> _filter(List<WorkerProfile> workers) {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return workers;
    return workers.where((w) {
      final matchesName = w.fullName.toLowerCase().contains(q);
      final matchesProfession = w.professions
          .any((p) => p.name.toLowerCase().contains(q));
      return matchesName || matchesProfession;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bgLight,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Padding(
              padding: const EdgeInsets.all(14),
              child: TextField(
                controller: _searchController,
                onChanged: (value) => setState(() => _query = value),
                decoration: InputDecoration(
                  hintText: 'Search workers...',
                  prefixIcon: const Icon(Icons.search, size: 20),
                  filled: true,
                  fillColor: AppTheme.surfaceWhite,
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(vertical: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: AppTheme.borderGray),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: AppTheme.borderGray),
                  ),
                ),
              ),
            ),
            Expanded(
              child: FutureBuilder<List<WorkerProfile>>(
                future: _workersFuture,
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return const Center(
                      child: Text(
                        'Could not load workers',
                        style: TextStyle(fontSize: 12, color: AppTheme.textMuted),
                      ),
                    );
                  }
                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final workers = _filter(snapshot.data!);
                  if (workers.isEmpty) {
                    return const Center(
                      child: Text(
                        'No workers found',
                        style: TextStyle(fontSize: 12, color: AppTheme.textMuted),
                      ),
                    );
                  }
                  return ListView.separated(
                    padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                    itemCount: workers.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (context, index) =>
                        _buildWorkerTile(workers[index]),
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
    return Container(
      width: double.infinity,
      color: AppTheme.brandBlue,
      padding: const EdgeInsets.fromLTRB(8, 10, 16, 14),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.arrow_back, color: Colors.white, size: 22),
          ),
          const Text(
            'New Chat',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWorkerTile(WorkerProfile worker) {
    return Material(
      color: AppTheme.surfaceWhite,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppTheme.borderGray),
      ),
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        leading: UserAvatar(
          fullName: worker.fullName,
          avatarUrl: worker.avatarUrl,
        ),
        title: Text(
          worker.fullName,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: AppTheme.textDark,
          ),
        ),
        subtitle: Text(
          worker.professions.map((p) => p.name).join(', '),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 12, color: AppTheme.textMuted),
        ),
        trailing: const Icon(Icons.chevron_right, color: AppTheme.textMuted),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ChatScreen(
              peerName: worker.fullName,
              peerId: worker.uid,
              myId: widget.user.uid,
              chatService: _chatService,
            ),
          ),
        ),
      ),
    );
  }
}