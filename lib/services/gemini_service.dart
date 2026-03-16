import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:http/http.dart' as http;

/// AI 분석 결과 모델
class AnalysisResult {
  final Uint8List? generatedImage;
  final String guide;
  final int harmonyScore;
  final List<CleanupTip> tips;

  AnalysisResult({
    this.generatedImage,
    required this.guide,
    required this.harmonyScore,
    required this.tips,
  });
}

/// 정리 팁 모델
class CleanupTip {
  final String title;
  final String description;

  CleanupTip({required this.title, required this.description});
}

/// Gemini API 서비스
/// 텍스트 분석: SDK 사용, 이미지 생성: REST API 직접 호출
class GeminiService {
  static GeminiService? _instance;
  GenerativeModel? _model;
  String? _apiKey;

  GeminiService._();

  static GeminiService get instance {
    _instance ??= GeminiService._();
    return _instance!;
  }

  /// Gemini 모델 초기화
  void initialize() {
    _apiKey = dotenv.env['GEMINI_API_KEY'];
    if (_apiKey == null || _apiKey!.isEmpty || _apiKey == 'your_api_key_here') {
      throw Exception('GEMINI_API_KEY가 .env 파일에 설정되지 않았습니다.');
    }

    // 텍스트 분석용 모델 (SDK)
    _model = GenerativeModel(model: 'gemini-2.5-flash-lite', apiKey: _apiKey!);
  }

  /// API 키 유효 여부
  bool get isInitialized => _model != null && _apiKey != null;

  /// AI 클린업 분석 - 공간 사진을 분석하여 정리 가이드 생성
  Future<AnalysisResult> analyzeAndCleanup(Uint8List imageBytes) async {
    _ensureInitialized();

    // 1단계: 텍스트 분석 (정리 가이드 + 점수)
    final textResult = await _analyzeSpace(imageBytes);

    // 2단계: 이미지 생성 (정리된 모습) - REST API
    Uint8List? cleanedImage;
    try {
      cleanedImage = await _generateCleanedImage(imageBytes);
    } catch (e) {
      debugPrint('이미지 생성 실패: $e');
    }

    return AnalysisResult(
      generatedImage: cleanedImage,
      guide: textResult['guide'] ?? '분석 결과를 가져오지 못했습니다.',
      harmonyScore: textResult['score'] ?? 50,
      tips: textResult['tips'] ?? [],
    );
  }

  /// 오브젝트 배치 분석 - 물건이 공간에 어울리는지 분석
  Future<AnalysisResult> placeObject({
    required Uint8List roomImageBytes,
    required Uint8List objectImageBytes,
    String objectDescription = '',
  }) async {
    _ensureInitialized();

    // 1단계: 텍스트 분석 (조화도 + 배치 가이드)
    final textResult = await _analyzePlacement(
      roomImageBytes,
      objectImageBytes,
      objectDescription,
    );

    // 2단계: 합성 이미지 생성 - REST API
    Uint8List? compositeImage;
    try {
      compositeImage = await _generatePlacementImage(
        roomImageBytes,
        objectImageBytes,
        objectDescription,
      );
    } catch (e) {
      debugPrint('합성 이미지 생성 실패: $e');
    }

    return AnalysisResult(
      generatedImage: compositeImage,
      guide: textResult['guide'] ?? '배치 분석 결과를 가져오지 못했습니다.',
      harmonyScore: textResult['score'] ?? 50,
      tips: textResult['tips'] ?? [],
    );
  }

  // ── 텍스트 분석 (SDK) ──

  Future<Map<String, dynamic>> _analyzeSpace(Uint8List imageBytes) async {
    final prompt = '''
당신은 공간 정리 전문가입니다. 이 사진의 공간을 분석하고 정리 방법을 알려주세요.

다음 형식으로 정확히 응답하세요:
SCORE: [0~100 사이 정수, 현재 정리 상태 점수]
GUIDE: [전체적인 정리 방향 한 줄 요약]
TIP1_TITLE: [첫번째 정리 팁 제목]
TIP1_DESC: [첫번째 정리 팁 구체적 설명]
TIP2_TITLE: [두번째 정리 팁 제목]
TIP2_DESC: [두번째 정리 팁 구체적 설명]
TIP3_TITLE: [세번째 정리 팁 제목]
TIP3_DESC: [세번째 정리 팁 구체적 설명]

한국어로 답변하세요. 구체적이고 실행 가능한 팁을 주세요.
''';

    final response = await _model!.generateContent([
      Content.multi([TextPart(prompt), DataPart('image/jpeg', imageBytes)]),
    ]);

    return _parseAnalysisResponse(response.text ?? '');
  }

  Future<Map<String, dynamic>> _analyzePlacement(
    Uint8List roomBytes,
    Uint8List objectBytes,
    String description,
  ) async {
    final desc = description.isNotEmpty ? '(물건 설명: $description)' : '';
    final prompt =
        '''
당신은 인테리어 전문가입니다.
첫번째 이미지는 방 사진이고, 두번째 이미지는 이 방에 놓으려는 물건입니다. $desc

이 물건이 이 공간에 어울리는지 분석하고 배치 가이드를 제공하세요.

다음 형식으로 정확히 응답하세요:
SCORE: [0~100 사이 정수, 공간과의 조화도 점수]
GUIDE: [전체적인 조화도 평가 한 줄 요약]
TIP1_TITLE: [첫번째 배치 팁 제목]
TIP1_DESC: [첫번째 배치 팁 구체적 설명]
TIP2_TITLE: [두번째 배치 팁 제목]
TIP2_DESC: [두번째 배치 팁 구체적 설명]
TIP3_TITLE: [세번째 배치 팁 제목]
TIP3_DESC: [세번째 배치 팁 구체적 설명]

한국어로 답변하세요. 색감, 크기, 스타일 어울림을 고려하세요.
''';

    final response = await _model!.generateContent([
      Content.multi([
        TextPart(prompt),
        DataPart('image/jpeg', roomBytes),
        DataPart('image/jpeg', objectBytes),
      ]),
    ]);

    return _parseAnalysisResponse(response.text ?? '');
  }

  // ── 이미지 생성 (REST API 직접 호출) ──

  Future<Uint8List?> _generateCleanedImage(Uint8List imageBytes) async {
    final base64Image = base64Encode(imageBytes);
    return _callImageGenerationApi(
      '이 사진 속 공간을 깔끔하게 정리한 모습으로 변환해주세요. '
      '물건들을 정돈하고, 어수선한 요소를 정리하여 깨끗한 공간을 보여주세요. '
      '공간의 구조는 유지하되 정돈된 느낌으로 만들어주세요.',
      [base64Image],
    );
  }

  Future<Uint8List?> _generatePlacementImage(
    Uint8List roomBytes,
    Uint8List objectBytes,
    String description,
  ) async {
    final roomBase64 = base64Encode(roomBytes);
    final objectBase64 = base64Encode(objectBytes);
    final desc = description.isNotEmpty ? ' ($description)' : '';

    return _callImageGenerationApi(
      '첫번째 이미지는 방이고, 두번째는 배치할 물건$desc입니다. '
      '물건을 방에 자연스럽게 배치한 합성 이미지를 생성해주세요.',
      [roomBase64, objectBase64],
    );
  }

  Future<Uint8List?> _callImageGenerationApi(
    String prompt,
    List<String> base64Images,
  ) async {
    final parts = <Map<String, dynamic>>[
      {'text': prompt},
    ];

    for (final img in base64Images) {
      parts.add({
        'inlineData': {'mimeType': 'image/jpeg', 'data': img},
      });
    }

    final body = {
      'contents': [
        {'parts': parts},
      ],
      'generationConfig': {
        'responseModalities': ['TEXT', 'IMAGE'],
      },
    };

    final url = Uri.parse(
      'https://generativelanguage.googleapis.com/v1beta/models/'
      'gemini-2.0-flash-preview-image-generation:generateContent?key=$_apiKey',
    );

    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(body),
    );

    if (response.statusCode != 200) {
      debugPrint('이미지 생성 API 오류: ${response.statusCode} ${response.body}');
      return null;
    }

    final json = jsonDecode(response.body) as Map<String, dynamic>;
    final candidates = json['candidates'] as List?;
    if (candidates == null || candidates.isEmpty) return null;

    final content = candidates[0]['content'] as Map<String, dynamic>?;
    final responseParts = content?['parts'] as List?;
    if (responseParts == null) return null;

    for (final part in responseParts) {
      if (part is Map<String, dynamic> && part.containsKey('inlineData')) {
        final inlineData = part['inlineData'] as Map<String, dynamic>;
        final data = inlineData['data'] as String?;
        if (data != null) {
          return base64Decode(data);
        }
      }
    }

    return null;
  }

  // ── 응답 파싱 ──

  Map<String, dynamic> _parseAnalysisResponse(String text) {
    int score = 50;
    String guide = '';
    final tips = <CleanupTip>[];

    for (final line in text.split('\n')) {
      final trimmed = line.trim();
      if (trimmed.startsWith('SCORE:')) {
        final scoreStr = trimmed.substring(6).trim();
        score = int.tryParse(scoreStr) ?? 50;
        score = score.clamp(0, 100);
      } else if (trimmed.startsWith('GUIDE:')) {
        guide = trimmed.substring(6).trim();
      } else if (trimmed.startsWith('TIP') && trimmed.contains('_TITLE:')) {
        final title = trimmed.substring(trimmed.indexOf(':') + 1).trim();
        tips.add(CleanupTip(title: title, description: ''));
      } else if (trimmed.startsWith('TIP') && trimmed.contains('_DESC:')) {
        final desc = trimmed.substring(trimmed.indexOf(':') + 1).trim();
        if (tips.isNotEmpty) {
          tips[tips.length - 1] = CleanupTip(
            title: tips.last.title,
            description: desc,
          );
        }
      }
    }

    if (tips.isEmpty) {
      tips.addAll([
        CleanupTip(title: '정리 시작', description: '사용 빈도가 낮은 물건부터 치워보세요.'),
        CleanupTip(title: '수납 활용', description: '수납함이나 정리함을 활용하여 물건을 분류하세요.'),
        CleanupTip(title: '동선 확보', description: '자주 사용하는 물건은 손이 닿는 곳에 배치하세요.'),
      ]);
    }

    return {
      'score': score,
      'guide': guide.isEmpty ? '공간 분석이 완료되었습니다.' : guide,
      'tips': tips,
    };
  }

  void _ensureInitialized() {
    if (_model == null || _apiKey == null) {
      throw Exception('GeminiService가 초기화되지 않았습니다. initialize()를 먼저 호출하세요.');
    }
  }
}
