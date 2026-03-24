import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/native_bridge.dart';
import '../../../core/theme/app_theme.dart';

/// AI 답장 바텀시트
/// 3가지 페르소나(수락, 거절, 모호함)의 AI 생성 답변을 표시하고,
/// 선택하면 RemoteInput을 통해 직접 카톡으로 전송합니다.
/// 직접 전송이 불가능한 경우 클립보드 복사로 폴백합니다.
class AiReplySheet extends StatefulWidget {
  final String roomId;

  const AiReplySheet({super.key, required this.roomId});

  @override
  State<AiReplySheet> createState() => _AiReplySheetState();
}

class _AiReplySheetState extends State<AiReplySheet>
    with SingleTickerProviderStateMixin {
  List<String> _replies = [];
  bool _isLoading = true;
  bool _isSending = false;
  bool _canDirectReply = false;
  late AnimationController _animController;

  static const _personaLabels = ['수락', '거절', '모호함'];
  static const _personaIcons = [
    Icons.check_circle_outline_rounded,
    Icons.cancel_outlined,
    Icons.help_outline_rounded,
  ];
  static const _personaColors = [
    Color(0xFF4CAF50),
    Color(0xFFE57373),
    Color(0xFFFFB74D),
  ];

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _initialize();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  Future<void> _initialize() async {
    // 직접 전송 가능 여부 확인 + AI 답변 생성 병렬 실행
    final canReplyFuture = NativeBridge.canDirectReply(widget.roomId);
    final repliesFuture = NativeBridge.generateAiReply(widget.roomId);

    final results = await Future.wait([canReplyFuture, repliesFuture]);

    setState(() {
      _canDirectReply = results[0] as bool;
      _replies = results[1] as List<String>;
      _isLoading = false;
    });
    _animController.forward();
  }

  Future<void> _regenerate() async {
    setState(() => _isLoading = true);
    _animController.reset();
    try {
      final replies = await NativeBridge.generateAiReply(widget.roomId);
      setState(() => _replies = replies);
      _animController.forward();
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _onReplySelected(String text) async {
    if (_isSending) return;
    setState(() => _isSending = true);

    if (_canDirectReply) {
      // RemoteInput을 통해 직접 전송
      final success = await NativeBridge.sendDirectReply(widget.roomId, text);
      if (mounted) {
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Row(
                children: [
                  Icon(Icons.send_rounded, color: Colors.white, size: 18),
                  SizedBox(width: 8),
                  Expanded(child: Text('답장을 전송했습니다')),
                ],
              ),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              backgroundColor: const Color(0xFF4CAF50),
              duration: const Duration(seconds: 2),
            ),
          );
        } else {
          // 전송 실패 시 클립보드 복사 폴백
          _copyToClipboard(text);
          return;
        }
        Navigator.pop(context, true); // true = 메시지 목록 새로고침 필요
      }
    } else {
      // 직접 전송 불가 → 클립보드 복사
      _copyToClipboard(text);
    }
  }

  void _copyToClipboard(String text) {
    Clipboard.setData(ClipboardData(text: text));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.copy_rounded, color: Colors.white, size: 18),
              SizedBox(width: 8),
              Expanded(child: Text('답장이 클립보드에 복사되었습니다')),
            ],
          ),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          backgroundColor: AppColors.primary,
          duration: const Duration(seconds: 2),
        ),
      );
      Navigator.pop(context, false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bottomPadding = MediaQuery.of(context).viewPadding.bottom;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkBg : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(20, 12, 20, 16 + bottomPadding),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 드래그 핸들
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: context.dividerColor,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 20),

          // 헤더
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppColors.primary, AppColors.primaryLight],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.auto_awesome_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'AI 답장 생성',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: context.textPrimary,
                      ),
                    ),
                    Text(
                      _canDirectReply
                          ? '선택하면 카카오톡으로 바로 전송됩니다'
                          : '선택하면 클립보드에 복사됩니다',
                      style: TextStyle(
                        fontSize: 12,
                        color: _canDirectReply
                            ? const Color(0xFF4CAF50)
                            : context.textTertiary,
                      ),
                    ),
                  ],
                ),
              ),
              // 전송 모드 표시 아이콘
              if (!_isLoading)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _canDirectReply
                        ? const Color(0xFF4CAF50).withValues(alpha: 0.1)
                        : context.textTertiary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _canDirectReply ? Icons.send_rounded : Icons.copy_rounded,
                        size: 14,
                        color: _canDirectReply
                            ? const Color(0xFF4CAF50)
                            : context.textTertiary,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _canDirectReply ? '직접 전송' : '복사',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: _canDirectReply
                              ? const Color(0xFF4CAF50)
                              : context.textTertiary,
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(width: 4),
              // 재생성 버튼
              IconButton(
                onPressed: _isLoading ? null : _regenerate,
                icon: Icon(
                  Icons.refresh_rounded,
                  color: _isLoading ? context.textTertiary : AppColors.primary,
                ),
                tooltip: '다시 생성',
              ),
            ],
          ),
          const SizedBox(height: 20),

          // 전송 중 표시
          if (_isSending) ...[
            const SizedBox(height: 40),
            const CircularProgressIndicator(color: Color(0xFF4CAF50)),
            const SizedBox(height: 16),
            Text(
              '답장을 전송하고 있습니다...',
              style: TextStyle(fontSize: 13, color: context.textSecondary),
            ),
            const SizedBox(height: 40),
          ]
          // 로딩 중
          else if (_isLoading) ...[
            const SizedBox(height: 40),
            const CircularProgressIndicator(color: AppColors.primary),
            const SizedBox(height: 16),
            Text(
              'AI가 답변을 생성하고 있습니다...',
              style: TextStyle(fontSize: 13, color: context.textSecondary),
            ),
            const SizedBox(height: 40),
          ]
          // 답변 카드
          else ...[
            for (int i = 0; i < _replies.length && i < 3; i++)
              _buildReplyCard(i, isDark),
          ],
        ],
      ),
    );
  }

  Widget _buildReplyCard(int index, bool isDark) {
    return FadeTransition(
      opacity: CurvedAnimation(
        parent: _animController,
        curve: Interval(index * 0.2, 0.6 + index * 0.2, curve: Curves.easeOut),
      ),
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.2),
          end: Offset.zero,
        ).animate(CurvedAnimation(
          parent: _animController,
          curve: Interval(index * 0.2, 0.6 + index * 0.2, curve: Curves.easeOut),
        )),
        child: GestureDetector(
          onTap: () => _onReplySelected(_replies[index]),
          child: Container(
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkCard : const Color(0xFFFAF9F6),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: _personaColors[index].withValues(alpha: 0.3),
                width: 1,
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 페르소나 아이콘
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: _personaColors[index].withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    _personaIcons[index],
                    color: _personaColors[index],
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),

                // 텍스트
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _personaLabels[index],
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: _personaColors[index],
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _replies[index],
                        style: TextStyle(
                          fontSize: 14,
                          height: 1.5,
                          color: context.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),

                // 전송/복사 아이콘
                Icon(
                  _canDirectReply ? Icons.send_rounded : Icons.copy_rounded,
                  size: 16,
                  color: _canDirectReply
                      ? const Color(0xFF4CAF50)
                      : context.textTertiary,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
