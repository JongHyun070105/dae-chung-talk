# Auto-Me (On-Device AI 기반 발신 데이터 학습 모델)

## 프로젝트 개요
**Auto-Me**는 백그라운드에서 메신저 알림과 화면 텍스트 데이터를 수집해 사용자의 발신/수신 대화 맥락을 모두 로컬 DB에 학습하고, 온디바이스 AI(Gemini Nano)를 통해 특정 대화 상대에 맞춤화된 답장을 생성 및 전송하는 안드로이드 전용 애플리케이션입니다.
UI가 최소화된 백그라운드 서비스 중심 설계로, 사용자의 직접 발신 메시지까지 수집하기 위해 `AccessibilityService`와 `NotificationListenerService`를 하이브리드로 운용합니다.

## 데이터 수집 아키텍처
*   **발신 데이터 (사용자 본인 말투 학습)**: `AccessibilityService`를 활용해 메신저 앱 내 텍스트 입력창에서 전송 이벤트를 가로채어 수집합니다.
*   **수신 데이터 (상대방 맥락 파악)**: `NotificationListenerService`를 통해 푸시 알림 데이터 구조(MessagingStyle)를 파싱하고 최근 대화 히스토리를 저장합니다.
*   **수동 수집 (Fallback)**: 권한 이슈나 OS 제한 시, 대화 내역 내보내기 텍스트 파일(.txt)을 앱에 Import하여 정규식 기반으로 일괄 파싱 및 적재합니다.

## 핵심 기능 정의
*   **Background Data Aggregator**: 기기 부팅 시 자동 실행되며 Room DB에 Room_ID 단위로 메시지를 로깅합니다.
*   **On-Device AI Generation (Gemini Nano)**: 안드로이드 AICore를 호출해 외부 네트워크 연결 없이 개인화된 답장을 3가지 페르소나(수락, 거절, 모호함)로 생성합니다.
*   **Floating Options & Inline Reply**: 플로팅 뷰(System_Alert_Window)로 생성된 텍스트를 노출하고 터치 시 백그라운드로 답장을 전송합니다.

## 기술 스택
*   **Frontend**: Flutter (설정 UI, 권한 안내, 로컬 DB 뷰어)
*   **Native Core**: Kotlin (Android AccessibilityService, NotificationListenerService, Room Database)
*   **AI Engine**: Google AICore (Gemini Nano)

## 리스크 대응 및 보안
*   **모듈 분리 개발 전략**: 접근성 기반 자동 수집 기능은 숨겨진 옵션으로 제공하고 텍스트 파싱을 메인으로 사용하는 투트랙 대응.
*   **PII 마스킹**: 모든 수집 데이터는 정규식 기반 개인식별정보(PII) 마스킹 모듈을 거쳐 저장하여 로컬 보안 환경이라도 신뢰성을 극대화합니다.
