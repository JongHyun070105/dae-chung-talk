package com.jonghyun.autome.utils

object PiiMasker {
    // 주민/외국인번호 (Hyphen 포함 여부도 처리 가능하도록 단순화)
    private val rrnRegex = Regex("\\b(?:[0-9]{2}(?:0[1-9]|1[0-2])(?:0[1-9]|[1,2][0-9]|3[0,1]))-?[1-4][0-9]{6}\\b")
    // 휴대전화번호
    private val phoneRegex = Regex("\\b01[016789]-?[0-9]{3,4}-?[0-9]{4}\\b")
    // 임의의 계좌번호 (한국 은행 포맷 근사치)
    private val accountRegex = Regex("\\b\\d{3,6}-\\d{2,6}-\\d{3,6}\\b")
    // 이메일 주소
    private val emailRegex = Regex("\\b[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}\\b")
    // 카드 번호 (13~16자리 숫자, 중간 공백/하이픈 허용)
    private val cardRegex = Regex("\\b(?:\\d[ -]*?){13,16}\\b")

    /**
     * 학습 불가능한 메시지 패턴 목록.
     * 카카오톡 내보내기 TXT에서 실질적 대화 내용이 아닌
     * 시스템/미디어/이벤트 메시지를 필터링합니다.
     */
    private val nonLearnablePatterns = listOf(
        // 삭제된 메시지
        Regex("^메시지(를|가) 삭제(했습니다|되었습니다)\\.?\$"),
        // 사진/동영상/파일 전송
        Regex("^사진$"),
        Regex("^사진 \\d+장$"),
        Regex("^동영상$"),
        Regex("^동영상 \\d+개$"),
        Regex("^파일: .+$"),
        // 이모티콘/스티커
        Regex("^이모티콘$"),
        Regex("^\\(이모티콘\\)$"),
        Regex("^스티커$"),
        // 음성/영상 통화
        Regex("^(음성|영상)통화.*$"),
        Regex("^통화시간 .+$"),
        Regex("^부재중 (음성|영상)통화$"),
        // 입금/송금
        Regex("^(송금|입금).*$"),
        // 채팅방 이벤트
        Regex("^.+님이 들어왔습니다\\.?\$"),
        Regex("^.+님이 나갔습니다\\.?\$"),
        Regex("^.+님을 초대했습니다\\.?\$"),
        Regex("^.+님이 .+님을 초대했습니다\\.?\$"),
        // 카카오톡 시스템 메시지
        Regex("^채팅방 관리자가.*$"),
        Regex("^오픈채팅봇$"),
        // 지도/위치 공유
        Regex("^(지도|위치)$"),
        Regex("^라이브톡.*$"),
        // 투표/일정/공지
        Regex("^(투표|일정|공지)$"),
        // 카카오페이
        Regex("^카카오페이.*$"),
        // 삭제된 메시지 (다른 형태)
        Regex("^삭제된 메시지입니다\\.?\$"),
    )

    /**
     * 학습 불가능한 메시지인지 판별 및 마스킹합니다.
     */
    fun maskText(text: String): String {
        val trimmed = text.trim()
        
        // 1. 학습 불가능한 전체 메시지 패턴 매칭
        // 매칭될 경우 메시지 전체를 마스킹 처리하여 반환합니다.
        for (pattern in nonLearnablePatterns) {
            if (pattern.matches(trimmed)) {
                return "[학습 불가 데이터]"
            }
        }

        // 2. 일반 텍스트 내의 개인정보 마스킹 처리
        var masked = text
        masked = rrnRegex.replace(masked, "[주민번호 마스킹]")
        masked = phoneRegex.replace(masked, "[전화번호 마스킹]")
        masked = accountRegex.replace(masked, "[계좌번호 마스킹]")
        masked = emailRegex.replace(masked, "[이메일 마스킹]")
        masked = cardRegex.replace(masked, "[카드번호 마스킹]")
        return masked
    }
}
