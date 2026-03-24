package com.jonghyun.autome.services

import android.app.Notification
import android.app.PendingIntent
import android.app.RemoteInput
import android.os.Build
import android.service.notification.NotificationListenerService
import android.service.notification.StatusBarNotification
import android.util.Log
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

    override fun onNotificationPosted(sbn: StatusBarNotification?) {
        if (sbn == null) return

        val extras = sbn.notification?.extras
        val title = extras?.getString("android.title") ?: "Unknown"
        val text = extras?.getCharSequence("android.text")?.toString() ?: ""
        val packageName = sbn.packageName ?: ""

        if (text.isEmpty()) return

        Log.d(TAG, "Captured Notification: pkg=$packageName, From=$title, Text=$text")

        // roomId를 패키지명 + 발신자 기반으로 세분화
        val appName = getAppLabel(packageName)
        val roomId = "notification_${appName}_$title"

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
        tryShowFloatingReply(sbn, title, roomId, remoteInputInfo)
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
        sbn: StatusBarNotification,
        sender: String,
        roomId: String,
        remoteInputInfo: Pair<String, PendingIntent>?
    ) {
        scope.launch {
            try {
                val aiManager = AICoreManager(applicationContext)
                val replies = aiManager.generateReplyFromDb(roomId)
                aiManager.close()

                if (replies.size >= 3) {
                    val intent = FloatingReplyService.createIntent(
                        context = applicationContext,
                        replies = ArrayList(replies),
                        sender = sender,
                        replyKey = remoteInputInfo?.first,
                        replyPendingIntent = remoteInputInfo?.second
                    )

                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                        applicationContext.startForegroundService(intent)
                    } else {
                        applicationContext.startService(intent)
                    }
                    Log.d(TAG, "FloatingReplyService started for: $sender (roomId=$roomId)")
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
        notification.actions?.forEach { action ->
            val remoteInputs = action.remoteInputs
            if (remoteInputs != null && remoteInputs.isNotEmpty()) {
                val key = remoteInputs[0].resultKey
                val pendingIntent = action.actionIntent
                if (key != null && pendingIntent != null) {
                    Log.d(TAG, "Found RemoteInput key: $key")
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
