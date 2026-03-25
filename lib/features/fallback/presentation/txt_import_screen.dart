import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';

class TxtImportScreen extends StatefulWidget {
  const TxtImportScreen({super.key});

  @override
  State<TxtImportScreen> createState() => _TxtImportScreenState();
}

class _TxtImportScreenState extends State<TxtImportScreen> {
  static const MethodChannel _channel = MethodChannel('com.jonghyun.autome/native');
  bool _isLoading = false;

  Future<void> _pickAndProcessFile() async {
    try {
      setState(() => _isLoading = true);
      
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['txt'],
      );

      if (result != null && result.files.single.path != null) {
        final filePath = result.files.single.path!;
        
        // 1. 발신자 목록 추출
        final List<dynamic> sendersDynamic = await _channel.invokeMethod('extractSenders', {'filePath': filePath});
        final List<String> senders = sendersDynamic.cast<String>();
        
        if (mounted) {
          setState(() => _isLoading = false); // 사용자 상호작용을 위해 로딩 해제 (바텀시트가 열리기 때문)
        }

        // 2. "나" 또는 "회원님" 식별
        if (senders.contains('나')) {
          _processWithSender(filePath, '나');
        } else if (senders.contains('회원님')) {
          _processWithSender(filePath, '회원님');
        } else if (senders.isNotEmpty) {
          // 3. 바텀시트로 사용자 선택 받기
          if (mounted) {
            _showSenderSelectionSheet(context, filePath, senders);
          }
        } else {
          // 발신자 목록이 없으면 그냥 던지기 (예외 상황)
          _processWithSender(filePath, '나');
        }
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('오류 발생: \$e')),
        );
        setState(() => _isLoading = false);
      }
    } 
  }

  Future<void> _processWithSender(String filePath, String meSenderName) async {
    if (mounted) setState(() => _isLoading = true);
    try {
      await _channel.invokeMethod('processFile', {'filePath': filePath, 'meSenderName': meSenderName});
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('파일 구조 분석 및 파싱이 성공적으로 완료되었습니다!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('파싱 오류: \$e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showSenderSelectionSheet(BuildContext context, String filePath, List<String> senders) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 드래그 핸들
                Center(
                  child: Container(
                    width: 40,
                    height: 5,
                    margin: const EdgeInsets.only(bottom: 24),
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(2.5),
                    ),
                  ),
                ),
                const Text(
                '본인 프로필을 선택해주세요',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              const Text(
                '선택한 이름이 "나의 발신 메시지"로 학습됩니다.',
                style: TextStyle(color: Colors.grey, fontSize: 14),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: senders.length,
                  itemBuilder: (context, index) {
                    final sender = senders[index];
                    return ListTile(
                      leading: const CircleAvatar(child: Icon(Icons.person)),
                      title: Text(sender),
                      onTap: () {
                        Navigator.pop(sheetContext);
                        _processWithSender(filePath, sender);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('TXT 데이터 Import')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Icon(Icons.upload_file, size: 64, color: Colors.blueGrey),
            const SizedBox(height: 16),
            const Text(
              '대화 내역 내보내기 파일 읽기',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            const Text(
              '카카오톡 등의 메신저에서 내보낸 텍스트(.txt) 파일을 선택하면, 앱 내부에서 자동 파싱 후 로컬 DB에 적재합니다.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.black54),
            ),
            const SizedBox(height: 32),
            _isLoading 
              ? const Center(child: CircularProgressIndicator())
              : ElevatedButton.icon(
                  icon: const Icon(Icons.folder_open),
                  label: const Text('텍스트 파일 선택하기 (.txt)'),
                  onPressed: _pickAndProcessFile,
                ),
          ],
        ),
      ),
    );
  }
}
