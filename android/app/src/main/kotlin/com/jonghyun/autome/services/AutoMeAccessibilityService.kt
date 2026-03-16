package com.jonghyun.autome.services

import android.accessibilityservice.AccessibilityService
import android.view.accessibility.AccessibilityEvent
import android.util.Log

class AutoMeAccessibilityService : AccessibilityService() {
    companion object {
        private const val TAG = "AutoMeAI_Accessibility"
    }

    override fun onAccessibilityEvent(event: AccessibilityEvent?) {
        // TODO: 발신 텍스트 캡처 및 로컬 DB 저장 로직 구현
        // TYPE_VIEW_CLICKED 등 이벤트 감지 후 텍스트 노드 탐색
    }

    override fun onInterrupt() {
        Log.d(TAG, "Accessibility Service Interrupted")
        // TODO: 서비스 인터럽트 처리
    }

    override fun onServiceConnected() {
        super.onServiceConnected()
        Log.d(TAG, "Accessibility Service Connected")
        // TODO: AccessibilityServiceInfo 설정
    }
}
