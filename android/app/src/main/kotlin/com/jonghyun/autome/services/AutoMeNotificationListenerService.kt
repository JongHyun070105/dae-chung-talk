package com.jonghyun.autome.services

import android.app.Notification
import android.app.PendingIntent
import android.app.RemoteInput
import android.os.Build
import android.service.notification.NotificationListenerService
import android.service.notification.StatusBarNotification
import android.util.Log
import androidx.core.app.NotificationCompat
import com.jonghyun.autome.ai.AICoreManager
import com.jonghyun.autome.data.AppDatabase
import com.jonghyun.autome.data.MessageEntity
import com.jonghyun.autome.utils.PiiMasker
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch

class AutoMeNotificationListenerService : NotificationListenerService() {
    private val scope = CoroutineScope(Dispatchers.IO)
    private val TAG = "AutoMeCaptured"

    // 카카오톡 패키지명
    private val KAKAO_PACKAGE = "com.kakao.talk"

    // 동일한 알림 업데이트로 인한 중복 처리 방지 (깜빡임 해결)
    private val lastCapturedTexts = mutableMapOf<String, String>()

    override fun onNotificationPosted(sbn: StatusBarNotification?) {
        if (sbn == null) return

        val packageName = sbn.packageName ?: ""
        
        // 1. 시스템 알림 및 우리 앱 알림 무시 (카카오톡, 메신저 등만 처리)
        if (packageName == "android" || packageName == "com.android.systemui" || packageName == applicationContext.packageName) {
            return
        }

        // 2. 카테고리가 메시지가 아닌 경우 필터링 (일부 앱은 null일 수 있어 유연하게 처리)
        val category = sbn.notification?.category
        if (category != null && category != Notification.CATEGORY_MESSAGE && category != Notification.CATEGORY_SOCIAL) {
            // 시스템 앱인 경우 더 엄격하게 필터링
            if (packageName.contains("android") || packageName.contains("system")) return
        }

        val extras = sbn.notification?.extras
        val title = extras?.getString("android.title") ?: "Unknown"
        val text = extras?.getCharSequence("android.text")?.toString() ?: ""

        // 3. 제목이나 내용에 시스템성 문구가 포함된 경우 제외
        if (title == "Android 시스템" || title.contains("Auto-Me") || text.contains("running in the background")) {
            return
        }

        if (text.isEmpty()) return

        // roomId 생성
        val appName = getAppLabel(packageName)
        val roomId = "notification_${appName}_$title"

        // 이전에 캡처한 내용과 동일하면 무시 (단순 메타데이터 업데이트 방지)
        if (lastCapturedTexts[roomId] == text) {
            return
        }
        lastCapturedTexts[roomId] = text

        Log.d(TAG, "Captured Notification: pkg=$packageName, From=$title, Text=$text")

        // DB에 메시지 저장
        saveReceivedMessage(roomId, title, text)

        // RemoteInput 추출 후 ReplyActionStore에 저장
        val remoteInputInfo = extractRemoteInput(sbn.notification)
        if (remoteInputInfo != null) {
            ReplyActionStore.put(roomId, ReplyActionStore.ReplyAction(
                replyKey = remoteInputInfo.first,
                pendingIntent = remoteInputInfo.second,
                sender = title
            ))
            Log.d(TAG, "RemoteInput stored for roomId=$roomId")
        }

        // AI 답변 생성 후 플로팅 뷰 표시
        tryShowFloatingReply(title, roomId, remoteInputInfo)
    }

    private fun saveReceivedMessage(roomId: String, sender: String, text: String) {
        val maskedText = PiiMasker.maskText(text)
        scope.launch {
            val db = AppDatabase.getDatabase(applicationContext)
            val message = MessageEntity(
                roomId = roomId,
                sender = sender,
                message = maskedText,
                timestamp = System.currentTimeMillis(),
                isSentByMe = false
            )
            db.messageDao().insertMessage(message)
            Log.d(TAG, "Received message saved to DB: roomId=$roomId, text=$maskedText")
        }
    }

    /**
     * AI 답변을 생성하고 FloatingReplyService로 전달합니다.
     */
    private fun tryShowFloatingReply(
        sender: String,
        roomId: String,
        remoteInputInfo: Pair<String, PendingIntent>?
    ) {
        scope.launch {
            try {
                val db = AppDatabase.getDatabase(applicationContext)
                val rule = db.roomRuleDao().getRuleForRoom(roomId)

                val aiManager = AICoreManager(applicationContext)
                val replies = aiManager.generateReplyFromDb(roomId, roomRule = rule)
                aiManager.close()
                if (replies.size >= 3) {
                    val intent = FloatingReplyService.createIntent(
                        context = applicationContext,
                        replies = ArrayList(replies),
                        sender = sender,
                        roomId = roomId,
                        replyKey = remoteInputInfo?.first,
                        replyPendingIntent = remoteInputInfo?.second
                    )

                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                        applicationContext.startForegroundService(intent)
                    } else {
                        applicationContext.startService(intent)
                    }
                    Log.d(TAG, "FloatingReplyService started for: $sender (roomId=$roomId) with rule: ${rule ?: "none"}")
                }
            } catch (e: Exception) {
                Log.e(TAG, "Failed to show floating reply: $e")
            }
        }
    }

    /**
     * 알림에서 RemoteInput 키와 PendingIntent를 추출합니다.
     */
    private fun extractRemoteInput(notification: Notification): Pair<String, PendingIntent>? {
        // 1. 일반 action 검사
        notification.actions?.forEach { action ->
            val remoteInputs = action.remoteInputs
            if (remoteInputs != null && remoteInputs.isNotEmpty()) {
                val key = remoteInputs[0].resultKey
                val pendingIntent = action.actionIntent
                if (key != null && pendingIntent != null) {
                    Log.d(TAG, "Found RemoteInput key: $key in standard actions")
                    return Pair(key, pendingIntent)
                }
            }
        }
        
        // 2. WearableExtender 검사 (카카오톡 등 일부 앱은 여기에 숨겨둠)
        val wearableExtender = NotificationCompat.WearableExtender(notification)
        wearableExtender.actions.forEach { action ->
            val remoteInputs = action.remoteInputs
            if (remoteInputs != null && remoteInputs.isNotEmpty()) {
                val key = remoteInputs[0].resultKey
                val pendingIntent = action.actionIntent
                if (pendingIntent != null) {
                    Log.d(TAG, "Found RemoteInput key: $key in WearableExtender")
                    return Pair(key, pendingIntent)
                }
            }
        }
        
        return null
    }

    /**
     * 패키지명에서 앱 이름을 추출합니다.
     */
    private fun getAppLabel(packageName: String): String {
        return try {
            val appInfo = packageManager.getApplicationInfo(packageName, 0)
            packageManager.getApplicationLabel(appInfo).toString()
        } catch (e: Exception) {
            // 패키지명에서 마지막 부분 추출
            packageName.substringAfterLast(".")
        }
    }

    override fun onNotificationRemoved(sbn: StatusBarNotification?) {
        super.onNotificationRemoved(sbn)
    }
}
