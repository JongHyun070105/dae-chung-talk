package com.jonghyun.autome.services

import android.service.notification.NotificationListenerService
import android.service.notification.StatusBarNotification
import android.util.Log

class AutoMeNotificationListenerService : NotificationListenerService() {
    companion object {
        private const val TAG = "AutoMeAI_Notification"
    }

    override fun onNotificationPosted(sbn: StatusBarNotification?) {
        super.onNotificationPosted(sbn)
        // TODO: 수신 푸시 알림 파싱 및 로컬 DB 저장 로직 구현
        // Notification.MessagingStyle 내의 EXTRA_HISTORIC_MESSAGES 탐색
    }

    override fun onNotificationRemoved(sbn: StatusBarNotification?) {
        super.onNotificationRemoved(sbn)
    }
}
