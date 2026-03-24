import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/native_bridge.dart';
import '../../../core/theme/app_theme.dart';
import 'ai_reply_sheet.dart';

/// 채팅 상세 화면
/// 특정 채팅방의 메시지를 카카오톡 스타일 버블 UI로 표시합니다.
class ChatDetailScreen extends StatefulWidget {
  final String roomId;
  final String displayName;

  const ChatDetailScreen({
    super.key,
    required this.roomId,
    required this.displayName,
  });

  @override
  State<ChatDetailScreen> createState() => _ChatDetailScreenState();
}

class _ChatDetailScreenState extends State<ChatDetailScreen> {
  List<Map<String, dynamic>> _messages = [];
  bool _isLoading = false;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _loadMessages();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadMessages() async {
    setState(() => _isLoading = true);
    try {
      final messages = await NativeBridge.getChatMessages(widget.roomId);
      setState(() {
        _messages = messages;
      });
      // 로딩 후 맨 아래로 스크롤
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
        }
      });
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showAiReplySheet() {
    showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => AiReplySheet(roomId: widget.roomId),
    ).then((shouldRefresh) {
      if (shouldRefresh == true) {
        _loadMessages();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            // 작은 아바타
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [AppColors.primary, AppColors.primaryLight],
                ),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Center(
                child: Text(
                  widget.displayName.isNotEmpty
                      ? widget.displayName[0].toUpperCase()
                      : '?',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.displayName,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    '${_messages.length}개의 메시지',
                    style: TextStyle(
                      fontSize: 11,
                      color: context.textTertiary,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, size: 22),
            onPressed: _loadMessages,
          ),
        ],
      ),
      body: Column(
        children: [
          // ── 메시지 리스트 ──
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _messages.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.chat_outlined, size: 48, color: context.textTertiary),
                            const SizedBox(height: 12),
                            Text('메시지가 없습니다', style: TextStyle(color: context.textSecondary)),
                          ],
                        ),
                      )
                    : ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                        itemCount: _messages.length,
                        itemBuilder: (context, index) {
                          final msg = _messages[index];
                          final prevMsg = index > 0 ? _messages[index - 1] : null;
                          return _buildMessageBubble(msg, prevMsg, isDark);
                        },
                      ),
          ),

          // ── AI 답장 버튼 ──
          Container(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkSurface : Colors.white,
              border: Border(
                top: BorderSide(
                  color: context.dividerColor,
                  width: 0.5,
                ),
              ),
            ),
            child: SafeArea(
              top: false,
              child: SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton.icon(
                  onPressed: _messages.isEmpty ? null : _showAiReplySheet,
                  icon: const Icon(Icons.auto_awesome_rounded, size: 20),
                  label: const Text('AI 답장 생성'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    elevation: 0,
                    textStyle: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(
    Map<String, dynamic> msg,
    Map<String, dynamic>? prevMsg,
    bool isDark,
  ) {
    final isSentByMe = msg['isSentByMe'] ?? false;
    final sender = msg['sender']?.toString() ?? '';
    final message = msg['message']?.toString() ?? '';
    final timestamp = msg['timestamp'] as int? ?? 0;

    // 날짜 구분선
    Widget? dateDivider;
    if (prevMsg != null) {
      final prevTime = DateTime.fromMillisecondsSinceEpoch(prevMsg['timestamp'] as int? ?? 0);
      final curTime = DateTime.fromMillisecondsSinceEpoch(timestamp);
      if (prevTime.day != curTime.day || prevTime.month != curTime.month) {
        dateDivider = _buildDateDivider(curTime);
      }
    } else if (timestamp > 0) {
      dateDivider = _buildDateDivider(DateTime.fromMillisecondsSinceEpoch(timestamp));
    }

    // 같은 발신자 연속인지 확인
    final showSender = !isSentByMe &&
        (prevMsg == null || prevMsg['sender'] != sender);

    return Column(
      children: [
        if (dateDivider != null) dateDivider,
        Align(
          alignment: isSentByMe ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            margin: EdgeInsets.only(
              top: showSender ? 12 : 3,
              bottom: 3,
              left: isSentByMe ? 60 : 0,
              right: isSentByMe ? 0 : 60,
            ),
            child: Column(
              crossAxisAlignment:
                  isSentByMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                // 발신자 이름 (수신 메시지만)
                if (showSender)
                  Padding(
                    padding: const EdgeInsets.only(left: 12, bottom: 4),
                    child: Text(
                      sender,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: context.textSecondary,
                      ),
                    ),
                  ),

                // 버블
                Row(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    if (isSentByMe) ...[
                      Text(
                        _formatTime(timestamp),
                        style: TextStyle(fontSize: 10, color: context.textTertiary),
                      ),
                      const SizedBox(width: 6),
                    ],
                    Flexible(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: isSentByMe
                              ? AppColors.primary
                              : (isDark ? AppColors.darkCard : const Color(0xFFF4F1ED)),
                          borderRadius: BorderRadius.only(
                            topLeft: const Radius.circular(18),
                            topRight: const Radius.circular(18),
                            bottomLeft: Radius.circular(isSentByMe ? 18 : 4),
                            bottomRight: Radius.circular(isSentByMe ? 4 : 18),
                          ),
                          border: isSentByMe
                              ? null
                              : Border.all(
                                  color: context.cardBorder.withValues(alpha: 0.5),
                                  width: 0.5,
                                ),
                        ),
                        child: Text(
                          message,
                          style: TextStyle(
                            fontSize: 14,
                            height: 1.4,
                            color: isSentByMe
                                ? Colors.white
                                : context.textPrimary,
                          ),
                        ),
                      ),
                    ),
                    if (!isSentByMe) ...[
                      const SizedBox(width: 6),
                      Text(
                        _formatTime(timestamp),
                        style: TextStyle(fontSize: 10, color: context.textTertiary),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDateDivider(DateTime date) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Row(
        children: [
          Expanded(child: Divider(color: context.dividerColor)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(
              '${date.year}년 ${date.month}월 ${date.day}일',
              style: TextStyle(
                fontSize: 12,
                color: context.textTertiary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(child: Divider(color: context.dividerColor)),
        ],
      ),
    );
  }

  String _formatTime(int timestamp) {
    if (timestamp == 0) return '';
    final dt = DateTime.fromMillisecondsSinceEpoch(timestamp);
    final period = dt.hour < 12 ? '오전' : '오후';
    final hour = dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
    return '$period $hour:${dt.minute.toString().padLeft(2, '0')}';
  }
}
