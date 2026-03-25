package com.jonghyun.autome

import android.content.Intent
import android.os.Bundle
import android.app.RemoteInput
import com.jonghyun.autome.ai.AICoreManager
import com.jonghyun.autome.services.ReplyActionStore
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import com.jonghyun.autome.data.AppDatabase
import com.jonghyun.autome.data.MessageEntity
import com.jonghyun.autome.utils.PiiMasker

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.jonghyun.autome/native"

    override fun onCreate(savedInstanceState: android.os.Bundle?) {
        super.onCreate(savedInstanceState)
        handleIntent(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        handleIntent(intent)
    }
    private fun handleIntent(intent: Intent?) {
        if (intent?.action == Intent.ACTION_SEND) {
            val uri = intent.getParcelableExtra<android.net.Uri>(Intent.EXTRA_STREAM)
            if (uri != null) {
                processSharedFile(uri)
            }
        }
    }

    private fun processSharedFile(uri: android.net.Uri) {
        CoroutineScope(Dispatchers.IO).launch {
            try {
                val inputStream = contentResolver.openInputStream(uri)
                val reader = inputStream?.bufferedReader()
                val content = reader?.readText() ?: ""
                parseAndInsertChatLog(content, "shared_file_import", "나")
            } catch (e: Exception) {
                android.util.Log.e("AutoMeCaptured", "Failed to process shared file: $e")
            }
        }
    }



    private suspend fun parseAndInsertChatLog(content: String, source: String, meSenderName: String) {
        // --- 1. 날짜 구분선 및 메시지 파싱용 Regex (모바일/PC 공통 지원) ---
        // 모바일 날짜: --------------- 2024년 3월 24일 일요일 ---------------
        val mobileDateRegex = Regex("-+ (\\d{4})년 (\\d{1,2})월 (\\d{1,2})일 .+ -+")
        // 모바일 메시지: [홍길동] [오후 8:44] 안녕하세요
        val mobileMessageRegex = Regex("^\\[(.+?)\\] \\[(.+?)\\] (.+)$")
        
        val messages = mutableListOf<MessageEntity>()
        var currentSender = ""
        var currentMessage = StringBuilder()
        var currentTimestamp = System.currentTimeMillis() - 100000000 // 기준 시간 (과거)

        var totalLines = 0
        var matchedLines = 0

        content.lines().forEach { line ->
            totalLines++
            val trimmedLine = line.trim()
            if (trimmedLine.isEmpty()) return@forEach

            // 날짜 구분선 스킵
            if (mobileDateRegex.matches(trimmedLine)) return@forEach

            // 1. 모바일 형식 매칭 시도
            val mobileMatch = mobileMessageRegex.find(trimmedLine)
            if (mobileMatch != null) {
                flushCurrentMessage(messages, source, currentSender, currentMessage, currentTimestamp++, meSenderName)
                currentSender = mobileMatch.groupValues[1]
                currentMessage.append(mobileMatch.groupValues[3])
                matchedLines++
                return@forEach
            }

            // 2. PC/유연한 형식 매칭 시도 (극도로 관대한 패턴)
            // 패턴: [숫자포함텍스트] [구분자] [이름] [구분자] [메세지]
            val flexiblePcRegex = Regex("(\\d+.+?\\d+:\\d+)\\s*[,:]\\s*(.+?)\\s*[:|,]\\s*(.+)$")
            val pcMatch = flexiblePcRegex.find(trimmedLine)
            if (pcMatch != null) {
                flushCurrentMessage(messages, source, currentSender, currentMessage, currentTimestamp++, meSenderName)
                currentSender = pcMatch.groupValues[2]
                currentMessage.append(pcMatch.groupValues[3])
                matchedLines++
                if (matchedLines <= 5) {
                    android.util.Log.e("AutoMeCaptured", "Match Success! Sender: $currentSender, Msg: ${pcMatch.groupValues[3]}")
                }
                return@forEach
            }
            
            if (totalLines <= 10) {
                android.util.Log.e("AutoMeCaptured", "Line $totalLines No Match: $trimmedLine")
            }

            // 3. 이전 메시지의 연속 (멀티라인) 처리
            if (currentSender.isNotEmpty()) {
                currentMessage.append("\n").append(line)
            }
        }
        
        // 마지막 남은 메시지 처리
        flushCurrentMessage(messages, source, currentSender, currentMessage, currentTimestamp, meSenderName)
        
        if (messages.isNotEmpty()) {
            val db = AppDatabase.getDatabase(applicationContext)
            db.messageDao().insertMessages(messages)
            android.util.Log.d("AutoMeCaptured", "Success: $matchedLines msgs parsed from $totalLines lines. Room: $source")
        } else {
            android.util.Log.w("AutoMeCaptured", "No messages parsed! Check your file format. Total lines: $totalLines")
        }
    }

    private fun flushCurrentMessage(
        messages: MutableList<MessageEntity>,
        roomId: String,
        sender: String,
        messageBuf: StringBuilder,
        timestamp: Long,
        meSenderName: String
    ) {
        if (sender.isNotEmpty() && messageBuf.isNotEmpty()) {
            val rawMsg = messageBuf.toString().trim()
            // 사용자의 요청에 따라 마스킹 로직이 파싱을 방해하는지 확인하기 위해 원본 유지 (나중에 다시 활성화 가능)
            val maskedMsg = com.jonghyun.autome.utils.PiiMasker.maskText(rawMsg)
            
            messages.add(
                MessageEntity(
                    roomId = roomId,
                    sender = sender,
                    message = maskedMsg, 
                    timestamp = timestamp,
                    isSentByMe = (sender == meSenderName || sender == "나" || sender == "회원님")
                )
            )
            messageBuf.setLength(0)
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "openAccessibilitySettings" -> {
                    startActivity(Intent(android.provider.Settings.ACTION_ACCESSIBILITY_SETTINGS))
                    result.success(null)
                }
                "openNotificationSettings" -> {
                    startActivity(Intent(android.provider.Settings.ACTION_NOTIFICATION_LISTENER_SETTINGS))
                    result.success(null)
                }
                "extractSenders" -> {
                    val filePath = call.argument<String>("filePath")
                    if (filePath != null) {
                        CoroutineScope(Dispatchers.IO).launch {
                            try {
                                val file = java.io.File(filePath)
                                val content = readEncodedFile(file)
                                
                                // 샘플 로그 (첫 3줄만)
                                content.lines().take(3).forEach { line ->
                                    android.util.Log.d("AutoMeCaptured", "Sample Line: $line") 
                                }

                                val mobileRegex = Regex("\\[(.+?)\\] \\[(.+?)\\] (.+)$")
                                val pcRegex = Regex("(\\d+.+?\\d+:\\d+)\\s*[,:]\\s*(.+?)\\s*[:|,]\\s*(.+)$")
                                val senders = mutableSetOf<String>()
                                
                                content.lines().forEachIndexed { index, line ->
                                    val trimmed = line.trim()
                                    if (trimmed.isEmpty()) return@forEachIndexed
                                    
                                    if (index < 5) {
                                        android.util.Log.e("AutoMeCaptured", "Line $index: $trimmed")
                                    }

                                    val mobileMatch = mobileRegex.find(trimmed)
                                    if (mobileMatch != null) {
                                        senders.add(mobileMatch.groupValues[1])
                                        return@forEachIndexed
                                    }
                                    val pcMatch = pcRegex.find(trimmed)
                                    if (pcMatch != null) {
                                        senders.add(pcMatch.groupValues[2])
                                        return@forEachIndexed
                                    }
                                }
                                
                                launch(Dispatchers.Main) {
                                    result.success(senders.toList())
                                }
                            } catch (e: Exception) {
                                launch(Dispatchers.Main) {
                                    result.error("FILE_ERROR", "Failed to read file: $e", null)
                                }
                            }
                        }
                    } else {
                        result.error("INVALID_ARGUMENT", "filePath is required", null)
                    }
                }
                "processFile" -> {
                    val filePath = call.argument<String>("filePath")
                    val meSenderName = call.argument<String>("meSenderName") ?: "나"
                    if (filePath != null) {
                        CoroutineScope(Dispatchers.IO).launch {
                            try {
                                val file = java.io.File(filePath)
                                val fileName = file.nameWithoutExtension
                                val content = readEncodedFile(file)
                                parseAndInsertChatLog(content, fileName, meSenderName)
                                launch(Dispatchers.Main) {
                                    result.success(true)
                                }
                            } catch (e: Exception) {
                                launch(Dispatchers.Main) {
                                    result.error("PARSE_ERROR", "Failed to process file: $e", null)
                                }
                            }
                        }
                    } else {
                        result.error("INVALID_ARGUMENT", "filePath is required", null)
                    }
                }
                "checkServicesEnabled" -> {
                    val accessibilityEnabled = isAccessibilityServiceEnabled()
                    val notificationListenerEnabled = isNotificationListenerServiceEnabled()
                    val overlayEnabled = android.provider.Settings.canDrawOverlays(applicationContext)
                    
                    val permissions = mapOf(
                        "accessibility" to accessibilityEnabled,
                        "notification" to notificationListenerEnabled,
                        "overlay" to overlayEnabled
                    )
                    result.success(permissions)
                }
                "openOverlaySettings" -> {
                    val intent = Intent(android.provider.Settings.ACTION_MANAGE_OVERLAY_PERMISSION)
                    intent.data = android.net.Uri.parse("package:$packageName")
                    startActivity(intent)
                    result.success(null)
                }
                "getMessageCount" -> {
                    CoroutineScope(Dispatchers.IO).launch {
                        val db = AppDatabase.getDatabase(applicationContext)
                        val count = db.messageDao().getMessageCount()
                        launch(Dispatchers.Main) {
                            result.success(count)
                        }
                    }
                }
                "getLatestMessages" -> {
                    CoroutineScope(Dispatchers.IO).launch {
                        val db = AppDatabase.getDatabase(applicationContext)
                        val messages = db.messageDao().getAllRecentMessages()
                        val resultList = messages.map {
                            mapOf(
                                "sender" to it.sender,
                                "message" to it.message,
                                "timestamp" to it.timestamp,
                                "isSentByMe" to it.isSentByMe
                            )
                        }
                        launch(Dispatchers.Main) {
                            result.success(resultList)
                        }
                    }
                }
                "getChatRooms" -> {
                    CoroutineScope(Dispatchers.IO).launch {
                        val db = AppDatabase.getDatabase(applicationContext)
                        val rooms = db.messageDao().getDistinctRooms()
                        val resultList = rooms.map {
                            mapOf(
                                "roomId" to it.roomId,
                                "lastSender" to it.lastSender,
                                "lastMessage" to it.lastMessage,
                                "lastTimestamp" to it.lastTimestamp,
                                "messageCount" to it.messageCount
                            )
                        }
                        launch(Dispatchers.Main) {
                            result.success(resultList)
                        }
                    }
                }
                "getChatMessages" -> {
                    val roomId = call.argument<String>("roomId")
                    val limit = call.argument<Int>("limit") ?: 50
                    val offset = call.argument<Int>("offset") ?: 0
                    if (roomId != null) {
                        CoroutineScope(Dispatchers.IO).launch {
                            val db = AppDatabase.getDatabase(applicationContext)
                            val messages = db.messageDao().getMessagesForRoomPaged(roomId, limit, offset)
                            val resultList = messages.map {
                                mapOf(
                                    "id" to it.id,
                                    "roomId" to it.roomId,
                                    "sender" to it.sender,
                                    "message" to it.message,
                                    "timestamp" to it.timestamp,
                                    "isSentByMe" to it.isSentByMe
                                )
                            }
                            launch(Dispatchers.Main) {
                                result.success(resultList)
                            }
                        }
                    } else {
                        result.error("INVALID_ARGUMENT", "roomId is required", null)
                    }
                }
                "saveRoomRule" -> {
                    val roomId = call.argument<String>("roomId")
                    val rule = call.argument<String>("rule")
                    if (roomId != null && rule != null) {
                        CoroutineScope(Dispatchers.IO).launch {
                            val db = AppDatabase.getDatabase(applicationContext)
                            db.roomRuleDao().insertRule(com.jonghyun.autome.data.RoomRuleEntity(roomId, rule))
                            launch(Dispatchers.Main) {
                                result.success(true)
                            }
                        }
                    } else {
                        result.error("INVALID_ARGUMENT", "roomId and rule are required", null)
                    }
                }
                "getRoomRule" -> {
                    val roomId = call.argument<String>("roomId")
                    if (roomId != null) {
                        CoroutineScope(Dispatchers.IO).launch {
                            val db = AppDatabase.getDatabase(applicationContext)
                            val rule = db.roomRuleDao().getRuleForRoom(roomId)
                            launch(Dispatchers.Main) {
                                result.success(rule)
                            }
                        }
                    } else {
                        result.error("INVALID_ARGUMENT", "roomId is required", null)
                    }
                }
                "generateAiReply" -> {
                    val roomId = call.argument<String>("roomId")
                    if (roomId != null) {
                        CoroutineScope(Dispatchers.IO).launch {
                            try {
                                val db = AppDatabase.getDatabase(applicationContext)
                                val rule = db.roomRuleDao().getRuleForRoom(roomId)

                                val aiCoreManager = AICoreManager(applicationContext)
                                val replies = aiCoreManager.generateReplyFromDb(roomId, roomRule = rule)
                                aiCoreManager.close()
                                launch(Dispatchers.Main) {
                                    result.success(replies)
                                }
                            } catch (e: Exception) {
                                launch(Dispatchers.Main) {
                                    result.success(listOf(
                                        "네, 확인했습니다.",
                                        "지금은 어렵습니다.",
                                        "글쎄요, 조금 더 생각해볼게요."
                                    ))
                                }
                            }
                        }
                    } else {
                        result.error("INVALID_ARGUMENT", "roomId is required", null)
                    }
                }
                "canDirectReply" -> {
                    val roomId = call.argument<String>("roomId")
                    if (roomId != null) {
                        result.success(ReplyActionStore.hasReplyAction(roomId))
                    } else {
                        result.success(false)
                    }
                }
                "sendDirectReply" -> {
                    val roomId = call.argument<String>("roomId")
                    val replyText = call.argument<String>("text")
                    if (roomId != null && replyText != null) {
                        val action = ReplyActionStore.get(roomId)
                        if (action != null) {
                            try {
                                val remoteInputBundle = Bundle().apply {
                                    putCharSequence(action.replyKey, replyText)
                                }
                                val remoteInput = RemoteInput.Builder(action.replyKey).build()
                                val replyIntent = Intent().apply {
                                    RemoteInput.addResultsToIntent(arrayOf(remoteInput), this, remoteInputBundle)
                                }
                                action.pendingIntent.send(this, 0, replyIntent)

                                CoroutineScope(Dispatchers.IO).launch {
                                    val db = AppDatabase.getDatabase(applicationContext)
                                    db.messageDao().insertMessage(
                                        MessageEntity(
                                            roomId = roomId,
                                            sender = "나",
                                            message = PiiMasker.maskText(replyText),
                                            timestamp = System.currentTimeMillis(),
                                            isSentByMe = true
                                        )
                                    )
                                }
                                result.success(true)
                            } catch (e: Exception) {
                                result.success(false)
                            }
                        } else {
                            result.success(false)
                        }
                    } else {
                        result.error("INVALID_ARGUMENT", "roomId and text are required", null)
                    }
                }
                "deleteChatRoom" -> {
                    val roomId = call.argument<String>("roomId")
                    if (roomId != null) {
                        CoroutineScope(Dispatchers.IO).launch {
                            try {
                                val db = AppDatabase.getDatabase(applicationContext)
                                db.messageDao().deleteMessagesByRoom(roomId)
                                db.roomRuleDao().deleteRule(roomId)
                                ReplyActionStore.remove(roomId)
                                launch(Dispatchers.Main) {
                                    result.success(true)
                                }
                            } catch (e: Exception) {
                                launch(Dispatchers.Main) {
                                    result.error("DELETE_ERROR", "Failed to delete room: $e", null)
                                }
                            }
                        }
                    } else {
                        result.error("INVALID_ARGUMENT", "roomId is required", null)
                    }
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun isAccessibilityServiceEnabled(): Boolean {
        val expectedService = "$packageName/${com.jonghyun.autome.services.AutoMeAccessibilityService::class.java.canonicalName}"
        val enabledServices = android.provider.Settings.Secure.getString(contentResolver, android.provider.Settings.Secure.ENABLED_ACCESSIBILITY_SERVICES)
        return enabledServices?.contains(expectedService) == true
    }

    private fun isNotificationListenerServiceEnabled(): Boolean {
        val flat = android.provider.Settings.Secure.getString(contentResolver, "enabled_notification_listeners")
        return flat?.contains(packageName) == true
    }

    private fun readEncodedFile(file: java.io.File): String {
        val bytes = file.readBytes()
        if (bytes.size >= 2) {
            // UTF-16 LE BOM: FF FE
            if (bytes[0] == 0xFF.toByte() && bytes[1] == 0xFE.toByte()) {
                return String(bytes, 2, bytes.size - 2, Charsets.UTF_16LE)
            }
            // UTF-16 BE BOM: FE FF
            if (bytes[0] == 0xFE.toByte() && bytes[1] == 0xFF.toByte()) {
                return String(bytes, 2, bytes.size - 2, Charsets.UTF_16BE)
            }
        }
        
        // BOM이 없는 경우, 첫 몇 바이트를 보고 0(null)이 섞여있으면 UTF-16LE로 추측
        if (bytes.size >= 4) {
            if (bytes[1] == 0.toByte() && bytes[3] == 0.toByte()) {
                return String(bytes, Charsets.UTF_16LE)
            }
        }

        // 기본은 UTF-8로 시도하되, 실패 시 CP949(EUC-KR) 폴백
        return try {
            String(bytes, Charsets.UTF_8)
        } catch (e: Exception) {
            try {
                String(bytes, java.nio.charset.Charset.forName("EUC-KR"))
            } catch (e2: Exception) {
                String(bytes) // 최종 폴백
            }
        }
    }
}
