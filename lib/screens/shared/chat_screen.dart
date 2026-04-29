import 'package:flutter/material.dart';
import '../../services/auth_service.dart';
import '../../services/connectivity_service.dart';
import '../../services/database_service.dart';
import '../../utils/app_colors.dart';
import '../../widgets/shared_widgets.dart';

class ChatScreen extends StatefulWidget {
  final String conversationId;
  final String otherUserName;
  final String otherUserInitials;

  const ChatScreen({
    super.key,
    this.conversationId = '',
    this.otherUserName = 'User',
    this.otherUserInitials = 'U',
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _msgController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  String? _myUserId;

  @override
  void initState() {
    super.initState();
    _myUserId = AuthService.getCurrentUserId();
    // Mark messages as read when entering chat
    if (widget.conversationId.isNotEmpty && _myUserId != null) {
      DatabaseService.markMessagesAsRead(
        conversationId: widget.conversationId,
        readerId: _myUserId!,
      );
    }
  }

  @override
  void dispose() {
    _msgController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _sendMessage() async {
    final text = _msgController.text.trim();
    if (text.isEmpty || widget.conversationId.isEmpty || _myUserId == null) return;

    _msgController.clear();

    final hasNet = await ConnectivityService.hasInternet();
    if (!hasNet) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No internet connection')),
        );
      }
      return;
    }

    await DatabaseService.sendMessage(
      conversationId: widget.conversationId,
      senderId: _myUserId!,
      content: text,
    );

    // Scroll to bottom after sending
    Future.delayed(const Duration(milliseconds: 300), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.navy,
        foregroundColor: Colors.white,
        elevation: 0,
        leading: Padding(
          padding: const EdgeInsets.all(8),
          child: GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.arrow_back_rounded, size: 18, color: Colors.white),
            ),
          ),
        ),
        titleSpacing: 0,
        title: Row(
          children: [
            ProviderAvatar(initials: widget.otherUserInitials, size: 34),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(widget.otherUserName,
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white)),
                Row(
                  children: [
                    Container(width: 6, height: 6,
                        decoration: const BoxDecoration(color: AppColors.success, shape: BoxShape.circle)),
                    const SizedBox(width: 5),
                    const Text('Online', style: TextStyle(fontSize: 11, color: Colors.white60, fontWeight: FontWeight.w400)),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          // Messages list
          Expanded(
            child: widget.conversationId.isEmpty
                ? const Center(
                    child: Text('Start a conversation', style: TextStyle(color: AppColors.textTertiary, fontSize: 14)),
                  )
                : StreamBuilder<List<Map<String, dynamic>>>(
                    stream: DatabaseService.streamMessages(widget.conversationId),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator(color: AppColors.navy));
                      }

                      final messages = snapshot.data ?? [];

                      if (messages.isEmpty) {
                        return const Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.chat_bubble_outline_rounded, size: 48, color: AppColors.textTertiary),
                              SizedBox(height: 12),
                              Text('No messages yet', style: TextStyle(color: AppColors.textSecondary, fontSize: 14, fontWeight: FontWeight.w600)),
                              SizedBox(height: 4),
                              Text('Send the first message!', style: TextStyle(color: AppColors.textTertiary, fontSize: 12)),
                            ],
                          ),
                        );
                      }

                      return ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.all(16),
                        itemCount: messages.length,
                        itemBuilder: (context, i) {
                          final msg = messages[i];
                          final isSender = msg['senderId'] == _myUserId;
                          final content = msg['content'] ?? '';
                          final type = msg['messageType'] ?? 'text';
                          final createdAt = msg['createdAt'];
                          String? timeStr;
                          if (createdAt != null) {
                            try {
                              final dt = createdAt.toDate();
                              timeStr = '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
                            } catch (_) {}
                          }

                          if (type == 'location') {
                            return _LocationBubble(isSender: isSender, label: content);
                          }

                          return _ChatBubble(text: content, isSender: isSender, time: timeStr);
                        },
                      );
                    },
                  ),
          ),

          // Input bar
          Container(
            padding: EdgeInsets.fromLTRB(14, 10, 14, MediaQuery.of(context).padding.bottom + 10),
            decoration: const BoxDecoration(
              color: AppColors.surface,
              border: Border(top: BorderSide(color: AppColors.border)),
            ),
            child: Row(
              children: [
                Container(
                  width: 38, height: 38,
                  decoration: BoxDecoration(
                    color: AppColors.surfaceAlt, borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: IconButton(
                    onPressed: () {},
                    icon: const Icon(Icons.attach_file_rounded, color: AppColors.textSecondary, size: 16),
                    padding: EdgeInsets.zero,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Container(
                    height: 40,
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceAlt, borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: TextField(
                      controller: _msgController,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _sendMessage(),
                      decoration: const InputDecoration(
                        hintText: 'Type a message...',
                        hintStyle: TextStyle(color: AppColors.textTertiary, fontSize: 13),
                        border: InputBorder.none, isDense: true,
                        contentPadding: EdgeInsets.symmetric(vertical: 11),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Container(
                  width: 40, height: 40,
                  decoration: const BoxDecoration(color: AppColors.navy, shape: BoxShape.circle),
                  child: IconButton(
                    onPressed: _sendMessage,
                    icon: const Icon(Icons.send_rounded, color: Colors.white, size: 17),
                    padding: EdgeInsets.zero,
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

// ─── Chat Bubble ──────────────────────────────────────────────────────────────

class _ChatBubble extends StatelessWidget {
  final String text;
  final bool isSender;
  final String? time;
  const _ChatBubble({required this.text, required this.isSender, this.time});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: isSender ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        Container(
          margin: EdgeInsets.only(bottom: 4, left: isSender ? 56 : 0, right: isSender ? 0 : 56),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
          decoration: BoxDecoration(
            color: isSender ? AppColors.navy : AppColors.surface,
            borderRadius: BorderRadius.circular(12).copyWith(
              bottomRight: isSender ? const Radius.circular(3) : null,
              bottomLeft: !isSender ? const Radius.circular(3) : null,
            ),
            border: isSender ? null : Border.all(color: AppColors.border),
          ),
          child: Text(text, style: TextStyle(
            color: isSender ? Colors.white : AppColors.textPrimary, fontSize: 14, height: 1.45)),
        ),
        if (time != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Text(time!, style: const TextStyle(fontSize: 10, color: AppColors.textTertiary)),
              if (isSender) ...[
                const SizedBox(width: 4),
                const Icon(Icons.done_all_rounded, size: 13, color: AppColors.success),
              ],
            ]),
          )
        else
          const SizedBox(height: 8),
      ],
    );
  }
}

class _LocationBubble extends StatelessWidget {
  final bool isSender;
  final String label;
  const _LocationBubble({required this.isSender, required this.label});

  @override
  Widget build(BuildContext context) => Align(
    alignment: isSender ? Alignment.centerRight : Alignment.centerLeft,
    child: Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.navyLight, borderRadius: BorderRadius.circular(12).copyWith(
          bottomRight: isSender ? const Radius.circular(3) : null,
          bottomLeft: !isSender ? const Radius.circular(3) : null,
        ),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.location_on_rounded, color: AppColors.urgent, size: 17),
        const SizedBox(width: 8),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Location Shared', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: AppColors.textPrimary)),
          Text(label.isNotEmpty ? label : 'View location', style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
        ]),
      ]),
    ),
  );
}

// Public ChatBubble for backward compatibility with other screens
class ChatBubble extends StatelessWidget {
  final String text;
  final bool isSender;
  final String? time;
  const ChatBubble({super.key, required this.text, required this.isSender, this.time});

  @override
  Widget build(BuildContext context) => _ChatBubble(text: text, isSender: isSender, time: time);
}

class LocationBubble extends StatelessWidget {
  const LocationBubble({super.key});
  @override
  Widget build(BuildContext context) => const _LocationBubble(isSender: true, label: 'Mirpur-2S');
}
