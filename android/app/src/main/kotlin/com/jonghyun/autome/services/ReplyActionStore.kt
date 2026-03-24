package com.jonghyun.autome.services

import android.app.PendingIntent
import android.util.Log

/**
 * ReplyActionStore: 알림에서 추출한 RemoteInput 정보를 roomId별로 보관합니다.
 *
 * NotificationListenerService에서 받은 RemoteInput 키와 PendingIntent를
 * roomId 기준으로 저장하여, Flutter에서 챗 화면의 AI 답장 버튼으로
 * 직접 메시지를 전송할 수 있도록 합니다.
 */
object ReplyActionStore {
    private const val TAG = "ReplyActionStore"

    data class ReplyAction(
        val replyKey: String,
        val pendingIntent: PendingIntent,
        val sender: String,
        val timestamp: Long = System.currentTimeMillis()
    )

    // roomId → 가장 최근의 ReplyAction
    private val store = mutableMapOf<String, ReplyAction>()

    /**
     * RemoteInput 액션을 저장합니다.
     */
    fun put(roomId: String, action: ReplyAction) {
        store[roomId] = action
        Log.d(TAG, "Stored ReplyAction for roomId=$roomId, sender=${action.sender}")
    }

    /**
     * 저장된 ReplyAction을 가져옵니다.
     */
    fun get(roomId: String): ReplyAction? {
        return store[roomId]
    }

    /**
     * 사용 후 ReplyAction을 제거합니다.
     */
    fun remove(roomId: String) {
        store.remove(roomId)
    }

    /**
     * 답장 가능 여부를 확인합니다.
     */
    fun hasReplyAction(roomId: String): Boolean {
        val action = store[roomId] ?: return false
        // 10분 이상 된 액션은 만료로 간주
        val isExpired = System.currentTimeMillis() - action.timestamp > 10 * 60 * 1000
        if (isExpired) {
            store.remove(roomId)
            return false
        }
        return true
    }

    /**
     * 답장 가능한 모든 roomId를 반환합니다.
     */
    fun getReplyableRoomIds(): Set<String> {
        // 만료된 것 제거
        val now = System.currentTimeMillis()
        store.entries.removeAll { now - it.value.timestamp > 10 * 60 * 1000 }
        return store.keys.toSet()
    }

    /**
     * 모든 저장된 액션을 정리합니다.
     */
    fun clear() {
        store.clear()
    }
}
