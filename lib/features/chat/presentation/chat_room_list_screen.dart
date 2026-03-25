import 'package:flutter/material.dart';
import '../../../core/native_bridge.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/glass_card.dart';
import 'chat_detail_screen.dart';
import '../../fallback/presentation/txt_import_screen.dart';

/// 채팅방 목록 화면
/// NotificationListenerService / AccessibilityService / TXT Import로 수집된
/// 메시지를 roomId별로 그루핑하여 채팅앱 스타일로 표시합니다.
class ChatRoomListScreen extends StatefulWidget {
  const ChatRoomListScreen({super.key});

  @override
  State<ChatRoomListScreen> createState() => _ChatRoomListScreenState();
}

class _ChatRoomListScreenState extends State<ChatRoomListScreen> {
  List<Map<String, dynamic>> _rooms = [];
  List<Map<String, dynamic>> _filteredRooms = [];
  bool _isLoading = false;
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadRooms();
    _searchController.addListener(_filterRooms);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadRooms() async {
    setState(() => _isLoading = true);
    try {
      final rooms = await NativeBridge.getChatRooms();
      setState(() {
        _rooms = rooms;
        _filteredRooms = rooms;
      });
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _filterRooms() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      if (query.isEmpty) {
        _filteredRooms = _rooms;
      } else {
        _filteredRooms = _rooms.where((room) {
          final roomId = (room['roomId'] ?? '').toString().toLowerCase();
          final lastMessage = (room['lastMessage'] ?? '').toString().toLowerCase();
          return roomId.contains(query) || lastMessage.contains(query);
        }).toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('채팅'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _loadRooms,
          ),
        ],
      ),
      body: Column(
        children: [
          // ── 검색 바 ──
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: '채팅방 검색...',
                prefixIcon: Icon(
                  Icons.search_rounded,
                  color: context.textTertiary,
                ),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded, size: 20),
                        onPressed: () => _searchController.clear(),
                      )
                    : null,
                filled: true,
                fillColor: isDark ? AppColors.darkSurface : const Color(0xFFF4F1ED),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
            ),
          ),
          const SizedBox(height: 4),

          // ── 채팅방 목록 ──
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredRooms.isEmpty
                    ? _buildEmptyState()
                    : RefreshIndicator(
                        onRefresh: _loadRooms,
                        color: AppColors.primary,
                        child: ListView.builder(
                          padding: const EdgeInsets.only(left: 12, right: 12, top: 4, bottom: 100),
                          itemCount: _filteredRooms.length,
                          itemBuilder: (context, index) {
                            return _buildRoomTile(_filteredRooms[index], index);
                          },
                        ),
                      ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const TxtImportScreen(),
            ),
          ).then((_) => _loadRooms());
        },
        icon: const Icon(Icons.add_rounded),
        label: const Text('대화 추가'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 2,
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.chat_bubble_outline_rounded,
            size: 64,
            color: context.textTertiary.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 16),
          Text(
            '수집된 채팅이 없습니다',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: context.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '알림 접근을 허용하거나, TXT 파일을 가져와 보세요',
            style: TextStyle(
              fontSize: 13,
              color: context.textTertiary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRoomTile(Map<String, dynamic> room, int index) {
    final roomId = room['roomId']?.toString() ?? '알 수 없는 방';
    final lastMessage = room['lastMessage']?.toString() ?? '';
    final lastTimestamp = room['lastTimestamp'] as int? ?? 0;
    final messageCount = room['messageCount'] as int? ?? 0;
    final lastSender = room['lastSender']?.toString() ?? '';

    // 방 이름 표시 (roomId에서 사람이 읽기 쉬운 형태로)
    final displayName = _formatRoomName(roomId);

    // 아바타 색상 (roomId 기반 해시)
    final avatarColors = [
      AppColors.primary,
      AppColors.secondary,
      AppColors.featureFitting,
      const Color(0xFF6B7B8D),
      const Color(0xFFB67D5C),
    ];
    final avatarColor = avatarColors[roomId.hashCode.abs() % avatarColors.length];

    return Dismissible(
      key: Key(roomId),
      direction: DismissDirection.endToStart,
      background: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        decoration: BoxDecoration(
          color: Colors.redAccent.withValues(alpha: 0.8),
          borderRadius: BorderRadius.circular(16),
        ),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: const Icon(Icons.delete_outline_rounded, color: Colors.white),
      ),
      confirmDismiss: (direction) async {
        return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('채팅방 삭제'),
            content: const Text('이 채팅방의 메시지와 설정된 규칙이 모두 삭제됩니다. 계속하시겠습니까?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('취소'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                style: TextButton.styleFrom(foregroundColor: Colors.red),
                child: const Text('삭제'),
              ),
            ],
          ),
        );
      },
      onDismissed: (direction) async {
        final success = await NativeBridge.deleteChatRoom(roomId);
        if (success) {
          _loadRooms();
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('채팅방이 삭제되었습니다.')),
            );
          }
        } else {
          _loadRooms();
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('삭제에 실패했습니다.')),
            );
          }
        }
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: SoftCard(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          margin: const EdgeInsets.symmetric(vertical: 2),
          borderRadius: 16,
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => ChatDetailScreen(
                  roomId: roomId,
                  displayName: displayName,
                ),
              ),
            ).then((_) => _loadRooms());
          },
          child: Row(
            children: [
              // 아바타
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [avatarColor, avatarColor.withValues(alpha: 0.7)],
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Center(
                  child: Text(
                    displayName.isNotEmpty ? displayName[0].toUpperCase() : '?',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 14),

              // 메시지 정보
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            displayName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: context.textPrimary,
                            ),
                          ),
                        ),
                        Text(
                          _formatTimestamp(lastTimestamp),
                          style: TextStyle(
                            fontSize: 12,
                            color: context.textTertiary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            lastSender.isNotEmpty ? '$lastSender: $lastMessage' : lastMessage,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 13,
                              color: context.textSecondary,
                            ),
                          ),
                        ),
                        if (messageCount > 0)
                          Container(
                            margin: const EdgeInsets.only(left: 8),
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              '$messageCount',
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: AppColors.primary,
                              ),
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
      ),
    );
  }

  String _formatRoomName(String roomId) {
    // "notification_카카오톡_홍길동" → "홍길동"
    // "shared_file_import" → "파일 가져오기"
    // "local_file_import" → "파일 가져오기"
    if (roomId.startsWith('notification_')) {
      final parts = roomId.split('_');
      return parts.length > 2 ? parts.sublist(2).join('_') : roomId;
    }
    if (roomId.contains('file_import')) return '파일 가져오기';
    return roomId;
  }

  String _formatTimestamp(int timestamp) {
    if (timestamp == 0) return '';
    final dt = DateTime.fromMillisecondsSinceEpoch(timestamp);
    final now = DateTime.now();
    final diff = now.difference(dt);

    if (diff.inMinutes < 1) return '방금';
    if (diff.inHours < 1) return '${diff.inMinutes}분 전';
    if (diff.inDays < 1) {
      return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    }
    if (diff.inDays < 7) return '${diff.inDays}일 전';
    return '${dt.month}/${dt.day}';
  }
}
