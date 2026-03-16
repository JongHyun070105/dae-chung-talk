import 'package:flutter/material.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Auto-Me 설정'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          const Text(
            '접근성 권한 및 알림 접근 권한',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          ListTile(
            title: const Text('접근성 서비스 설정'),
            subtitle: const Text('발신 메시지 학습을 위해 필요합니다.'),
            trailing: const Icon(Icons.arrow_forward_ios),
            onTap: () {
              // TODO: 네이티브 접근성 서비스 설정 화면 호출
            },
          ),
          ListTile(
            title: const Text('알림 접근 허용'),
            subtitle: const Text('수신 메시지 학습 및 알림 파싱을 위해 필요합니다.'),
            trailing: const Icon(Icons.arrow_forward_ios),
            onTap: () {
              // TODO: 네이티브 알림 접근 설정 화면 호출
            },
          ),
          const Divider(),
          const Text(
            '데이터 관리',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          ListTile(
            title: const Text('TXT 파일로 내보낸 대화 Import'),
            subtitle: const Text('기존 대화 내역을 모델 학습에 사용합니다.'),
            trailing: const Icon(Icons.upload_file),
            onTap: () {
              // TODO: 파일 픽커 구현
            },
          ),
          ListTile(
            title: const Text('로컬 DB 뷰어'),
            subtitle: const Text('학습된 데이터를 로컬에서 확인합니다.'),
            trailing: const Icon(Icons.storage),
            onTap: () {
              // TODO: 로컬 DB 확인 화면
            },
          ),
        ],
      ),
    );
  }
}
