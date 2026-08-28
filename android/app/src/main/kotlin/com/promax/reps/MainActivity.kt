package com.promax.reps

import android.Manifest
import android.app.Activity
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.location.LocationListener
import android.location.LocationManager
import android.net.Uri
import android.os.Build
import android.os.Looper
import android.provider.OpenableColumns
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileOutputStream

/**
 * اختيار مستند (PDF أو صورة) من غير أي باكدج خارجي.
 * بنستخدم ACTION_OPEN_DOCUMENT اللي جوه أندرويد نفسه،
 * وبننسخ الملف المختار لمجلد الكاش عشان فلاتر يقدر يرفعه.
 */
class MainActivity : FlutterActivity() {

    private val channelName = "promax/doc_picker"

    /**
     * ⚠️ **مرجع محفوظ للقناة عشان نبعت تقدم التنزيل.**
     * `MethodChannel` بيبعت في الاتجاهين — بس محتاجين نمسك النسخة
     * اللي اتعملت في `configureFlutterEngine` عشان نندهها من جوّه
     * تريد التنزيل. من غير كده الأبلكيشن بيوري سبينر مبهم دقيقتين
     * والمندوب يفتكره معلّق ويقفله في نص التنزيل.
     */
    private var updaterChannel: MethodChannel? = null
    private val pickRequestCode = 4711
    private var pendingResult: MethodChannel.Result? = null

    // ═══ اللوكيشن — نفس فلسفة doc_picker: أندرويد نفسه من غير باكدج ═══
    private val locatorChannel = "promax/locator"
    private val locPermissionCode = 4712
    private var pendingLocResult: MethodChannel.Result? = null

    /**
     * ⚠️ **قناة الإشعارات لازم تتعمل بكود — الـmanifest بيسمّيها بس.**
     * الـmeta-data في الـmanifest بتقول لفاير بيز «استخدم القناة
     * `promax_ops`»، بس أندرويد مابيعملهاش لوحده: لو القناة مش
     * موجودة بيرمي الإشعار في قناة افتراضية بأهمية منخفضة — من غير
     * صوت ومن غير ظهور على شاشة القفل. المندوب في الشارع مش هيحسّ
     * بالإشعار أصلاً.
     *
     * `IMPORTANCE_HIGH` = صوت + بانر منبثق فوق الشاشة (heads-up).
     * وبعد ما القناة تتعمل مرة، إعداداتها **مش بتتغيّر** بالكود —
     * المستخدم هو اللي يتحكم فيها من إعدادات التليفون. عشان كده
     * الأهمية بتتحدد صح من أول مرة.
     */
    private fun ensureNotificationChannel() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return

        val manager = getSystemService(NotificationManager::class.java) ?: return

        val channel = NotificationChannel(
            "promax_ops",
            "PROMAX",
            NotificationManager.IMPORTANCE_HIGH,
        ).apply {
            description = "أوامر التجهيز والتوريد وطلبات العملاء"
            enableVibration(true)
            lockscreenVisibility = Notification.VISIBILITY_PUBLIC
        }

        manager.createNotificationChannel(channel)
    }

    /**
     * تنزيل الـAPK وفتح شاشة التسطيب.
     *
     * ⚠️ **الملف بيتحفظ في `getExternalFilesDir` مش `cacheDir`.**
     * مسطّب الحزم بتاع أندرويد بيقرا الملف من عملية تانية خالص —
     * والكاش الداخلي مش متشارك عبر FileProvider في كل الأجهزة.
     * الطريق ده هو اللي `file_paths.xml` معرّف عليه.
     *
     * ⚠️ **التنزيل في ثريد منفصل والرد على الـMain.** أي شغل شبكة
     * على الـmain thread بيرمي `NetworkOnMainThreadException`،
     * و`MethodChannel.Result` ممنوع يترد عليه من غير الـmain.
     */
    private fun downloadAndInstall(url: String, result: MethodChannel.Result) {
        Thread {
            var error: String? = null
            var file: File? = null

            try {
                val conn = (java.net.URL(url).openConnection() as java.net.HttpURLConnection).apply {
                    connectTimeout = 20000
                    readTimeout = 120000
                    instanceFollowRedirects = true
                }

                if (conn.responseCode !in 200..299) {
                    error = "HTTP ${conn.responseCode}"
                } else {
                    val dir = File(getExternalFilesDir(null), "update").apply { mkdirs() }
                    val target = File(dir, "promax.apk")

                    // ⚠️ نسخة قديمة فاضلة بتخلي أندرويد يسطّبها هي —
                    // فالمندوب يدوس تحديث ويلاقي نفس الإصدار
                    if (target.exists()) target.delete()

                    // ⚠️ **بافر يدوي مش `copyTo`.** `copyTo` بينقل الملف
                    // كله في نداء واحد ومابيديش أي فرصة نقول وصلنا
                    // فين — والـAPK بتاعنا ~40 ميجا على شبكة مندوب،
                    // يعني دقيقة كاملة شاشة واقفة.
                    val total = conn.contentLength.toLong()
                    var received = 0L
                    var lastSent = 0L

                    conn.inputStream.use { input ->
                        FileOutputStream(target).use { output ->
                            val buf = ByteArray(64 * 1024)

                            while (true) {
                                val n = input.read(buf)
                                if (n <= 0) break

                                output.write(buf, 0, n)
                                received += n

                                // ⚠️ **بنبعت كل 200 كيلو مش كل بافر.**
                                // نداء على الـUI thread لكل 64 كيلو =
                                // مئات النداءات في الثانية، بتزحم
                                // الرسايل وبتخلي الواجهة تهنج فعلاً —
                                // يعني البار اللي المفروض يطمّن بيوقّف.
                                if (received - lastSent >= 200_000 || received == total) {
                                    lastSent = received
                                    val r = received

                                    runOnUiThread {
                                        updaterChannel?.invokeMethod(
                                            "progress",
                                            mapOf("received" to r, "total" to total),
                                        )
                                    }
                                }
                            }
                        }
                    }

                    file = target
                }
            } catch (e: Exception) {
                error = e.message ?: "download_failed"
            }

            runOnUiThread {
                val f = file

                if (f == null || error != null) {
                    result.error("download_failed", error ?: "unknown", null)
                    return@runOnUiThread
                }

                try {
                    val uri = androidx.core.content.FileProvider.getUriForFile(
                        this, "$packageName.fileprovider", f,
                    )

                    startActivity(
                        Intent(Intent.ACTION_VIEW).apply {
                            setDataAndType(uri, "application/vnd.android.package-archive")
                            // ⚠️ الاتنين مطلوبين: الأول عشان المسطّب
                            // يقدر يقرا الملف، والتاني عشان الشاشة
                            // تفتح من خارج ستاك الأكتيفيتي بتاعنا
                            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                        },
                    )

                    result.success(true)
                } catch (e: Exception) {
                    result.error("install_failed", e.message, null)
                }
            }
        }.start()
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        ensureNotificationChannel()

        // ═══ إشعار محلي بصوت (فلو الليد المطور ٢٦/٨) ═══
        //
        // «عميل محتمل جمبك» والأبلكيشن في الخلفية: فلاتر مش بيقدر
        // يرسم بوتوم شيت، فالنبضة بتتحول لإشعار heads-up على قناة
        // `promax_ops` (IMPORTANCE_HIGH = صوت + بانر) — والدوسة عليه
        // بتفتح الأبلكيشن والشيت بيطلع من هناك.
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "promax/notify")
            .setMethodCallHandler { call, result ->
                if (call.method != "show") {
                    result.notImplemented()
                    return@setMethodCallHandler
                }

                val title = call.argument<String>("title") ?: ""
                val body = call.argument<String>("body") ?: ""
                val id = call.argument<Int>("id") ?: 9901

                val launch = packageManager.getLaunchIntentForPackage(packageName)
                val pending = android.app.PendingIntent.getActivity(
                    this,
                    0,
                    launch,
                    android.app.PendingIntent.FLAG_UPDATE_CURRENT or
                        android.app.PendingIntent.FLAG_IMMUTABLE,
                )

                val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                    Notification.Builder(this, "promax_ops")
                } else {
                    @Suppress("DEPRECATION")
                    Notification.Builder(this).setPriority(Notification.PRIORITY_HIGH)
                }

                val notification = builder
                    .setSmallIcon(applicationInfo.icon)
                    .setContentTitle(title)
                    .setContentText(body)
                    .setAutoCancel(true)
                    .setContentIntent(pending)
                    .build()

                val manager = getSystemService(NotificationManager::class.java)
                // أندرويد ١٣+ من غير إذن الإشعارات بيتجاهل بصمت — مش كراش
                try {
                    manager?.notify(id, notification)
                    result.success(true)
                } catch (e: Exception) {
                    result.success(false)
                }
            }

        // ═══ التحديث الذاتي — تنزيل APK وتسطيبه ═══
        //
        // ⚠️ **الأبلكيشن مش على جوجل بلاي**، فالتحديث بيتوزّع من
        // السيرفر بتاعنا. مفيش باكدج هنا عن قصد (نفس سياسة
        // doc_picker/locator): التنزيل بـHttpURLConnection والتسطيب
        // بـIntent — الاتنين جوّه أندرويد نفسه.
        updaterChannel =
            MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "promax/updater")
        updaterChannel!!
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "downloadAndInstall" -> {
                        val url = call.argument<String>("url")
                        if (url.isNullOrBlank()) {
                            result.error("no_url", "url is required", null)
                        } else {
                            downloadAndInstall(url, result)
                        }
                    }
                    else -> result.notImplemented()
                }
            }

        // ═══ مشاركة الفاتورة كصورة (2026-08-08) ═══
        //
        // ⚠️ **مفيش باكدج share_plus** — نفس سياسة باقي القنوات.
        // الأبلكيشن بيصوّر كارت الفاتورة ويبعت البايتس، وإحنا بنكتبها
        // في الكاش ونفتح شيت المشاركة. المندوب بيبعتها للعميل واتساب.
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "promax/share")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "shareImage" -> {
                        val bytes = call.argument<ByteArray>("bytes")
                        val name = call.argument<String>("name") ?: "invoice.png"
                        if (bytes == null) {
                            result.error("no_bytes", "bytes is required", null)
                        } else {
                            shareImage(bytes, name, call.argument<String>("text"), result)
                        }
                    }
                    else -> result.notImplemented()
                }
            }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "pickDocument" -> openDocumentPicker(result)
                    else -> result.notImplemented()
                }
            }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, locatorChannel)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "getLocation" -> getLocation(result)
                    // فتح لينك خارجي (ملاحة جوجل ماب للعميل المحتمل) —
                    // من غير باكدج url_launcher عشان البيلد يفضل ثابت
                    "openUrl" -> {
                        try {
                            val url = call.argument<String>("url")
                            startActivity(Intent(Intent.ACTION_VIEW, Uri.parse(url)))
                            result.success(true)
                        } catch (e: Exception) {
                            result.success(false)
                        }
                    }
                    else -> result.notImplemented()
                }
            }

        // ═══ تخزين بسيط (توكن الجلسة) — SharedPreferences أندرويد نفسه ═══
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "promax/prefs")
            .setMethodCallHandler { call, result ->
                val prefs = getSharedPreferences("promax", MODE_PRIVATE)
                when (call.method) {
                    "get" -> result.success(prefs.getString(call.argument<String>("key"), null))
                    "set" -> {
                        prefs.edit()
                            .putString(call.argument<String>("key"), call.argument<String>("value"))
                            .apply()
                        result.success(true)
                    }
                    "remove" -> {
                        prefs.edit().remove(call.argument<String>("key")).apply()
                        result.success(true)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    // ==================== اللوكيشن ====================

    // ⚠️ من غير androidx عن قصد — مش مضمونة في تبعيات المشروع،
    // وميثودات الـActivity نفسها موجودة من API 23
    private fun hasLocPermission(): Boolean {
        if (Build.VERSION.SDK_INT < 23) return true

        return checkSelfPermission(Manifest.permission.ACCESS_FINE_LOCATION) ==
            PackageManager.PERMISSION_GRANTED ||
            checkSelfPermission(Manifest.permission.ACCESS_COARSE_LOCATION) ==
            PackageManager.PERMISSION_GRANTED
    }

    private fun getLocation(result: MethodChannel.Result) {
        if (pendingLocResult != null) {
            result.success(null) // طلب شغال بالفعل — مانعلقش الاتنين
            return
        }

        if (!hasLocPermission()) {
            pendingLocResult = result
            requestPermissions(
                arrayOf(
                    Manifest.permission.ACCESS_FINE_LOCATION,
                    Manifest.permission.ACCESS_COARSE_LOCATION
                ),
                locPermissionCode
            )
            return
        }

        resolveLocation(result)
    }

    override fun onRequestPermissionsResult(
        requestCode: Int, permissions: Array<out String>, grantResults: IntArray
    ) {
        if (requestCode == locPermissionCode) {
            val result = pendingLocResult
            pendingLocResult = null

            if (result == null) return
            if (hasLocPermission()) resolveLocation(result) else result.success(null)
            return
        }
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
    }

    /**
     * آخر موقع معروف فوراً، ولو مفيش بنطلب تحديث واحد بمهلة.
     * ⚠️ بنرجّع null بدل error — التشيك إن **مايتعطلش** عشان اللوكيشن؛
     * الزيارة بتتسجل من غير إحداثيات واللايف بيتصرف.
     */
    private fun resolveLocation(result: MethodChannel.Result) {
        try {
            val lm = getSystemService(Context.LOCATION_SERVICE) as LocationManager

            val last = listOf(
                LocationManager.GPS_PROVIDER,
                LocationManager.NETWORK_PROVIDER,
                LocationManager.PASSIVE_PROVIDER
            ).mapNotNull { p ->
                try { lm.getLastKnownLocation(p) } catch (_: Exception) { null }
            }.maxByOrNull { it.time }

            // آخر موقع في خلال 3 دقايق كفاية للتشيك إن
            if (last != null && System.currentTimeMillis() - last.time < 180_000) {
                result.success(mapOf("lat" to last.latitude, "lng" to last.longitude))
                return
            }

            val provider = when {
                lm.isProviderEnabled(LocationManager.GPS_PROVIDER) -> LocationManager.GPS_PROVIDER
                lm.isProviderEnabled(LocationManager.NETWORK_PROVIDER) -> LocationManager.NETWORK_PROVIDER
                else -> null
            }

            if (provider == null) {
                result.success(last?.let { mapOf("lat" to it.latitude, "lng" to it.longitude) })
                return
            }

            var done = false
            val listener = object : LocationListener {
                override fun onLocationChanged(location: android.location.Location) {
                    if (done) return
                    done = true
                    lm.removeUpdates(this)
                    result.success(mapOf("lat" to location.latitude, "lng" to location.longitude))
                }

                @Deprecated("Deprecated in Java")
                override fun onStatusChanged(p: String?, s: Int, e: android.os.Bundle?) {}
                override fun onProviderEnabled(p: String) {}
                override fun onProviderDisabled(p: String) {}
            }

            lm.requestLocationUpdates(provider, 0L, 0f, listener, Looper.getMainLooper())

            // مهلة 8 ثواني — بعدها بنرجّع آخر معروف (أو null) ومانعلقش الشاشة
            android.os.Handler(Looper.getMainLooper()).postDelayed({
                if (!done) {
                    done = true
                    lm.removeUpdates(listener)
                    result.success(last?.let { mapOf("lat" to it.latitude, "lng" to it.longitude) })
                }
            }, 8_000)
        } catch (e: Exception) {
            result.success(null)
        }
    }

    private fun openDocumentPicker(result: MethodChannel.Result) {
        if (pendingResult != null) {
            result.error("busy", "فيه اختيار ملف شغال بالفعل", null)
            return
        }
        pendingResult = result

        val intent = Intent(Intent.ACTION_OPEN_DOCUMENT).apply {
            addCategory(Intent.CATEGORY_OPENABLE)
            type = "*/*"
            putExtra(
                Intent.EXTRA_MIME_TYPES,
                arrayOf("application/pdf", "image/jpeg", "image/png", "image/webp")
            )
        }

        try {
            startActivityForResult(intent, pickRequestCode)
        } catch (e: Exception) {
            pendingResult = null
            result.error("unavailable", "مفيش تطبيق يقدر يفتح الملفات", null)
        }
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        if (requestCode == pickRequestCode) {
            val result = pendingResult
            pendingResult = null

            val uri = data?.data
            if (resultCode != Activity.RESULT_OK || uri == null) {
                result?.success(null) // المستخدم لغى الاختيار
                return
            }

            try {
                val name = displayName(uri)
                val file = copyToCache(uri, name)
                result?.success(mapOf("path" to file.absolutePath, "name" to name))
            } catch (e: Exception) {
                result?.error("copy_failed", e.message ?: "مش قادر يقرأ الملف", null)
            }
            return
        }

        super.onActivityResult(requestCode, resultCode, data)
    }

    /** اسم الملف زي ما المستخدم شايفه */
    private fun displayName(uri: Uri): String {
        var name = "document"
        contentResolver.query(uri, null, null, null, null)?.use { cursor ->
            val index = cursor.getColumnIndex(OpenableColumns.DISPLAY_NAME)
            if (index >= 0 && cursor.moveToFirst()) {
                cursor.getString(index)?.let { name = it }
            }
        }
        return name
    }

    /** نسخ الـ content:// لملف حقيقي في الكاش عشان نقدر نرفعه */
    private fun copyToCache(uri: Uri, name: String): File {
        val dir = File(cacheDir, "picked").apply { mkdirs() }
        val safeName = name.replace(Regex("[^A-Za-z0-9._\\-]"), "_")
        val out = File(dir, "${System.currentTimeMillis()}_$safeName")

        contentResolver.openInputStream(uri).use { input ->
            requireNotNull(input) { "مش قادر يفتح الملف" }
            FileOutputStream(out).use { output -> input.copyTo(output) }
        }
        return out
    }

    /**
     * بيكتب الصورة في الكاش وبيفتح شيت المشاركة.
     *
     * ⚠️ **`FLAG_GRANT_READ_URI_PERMISSION` مش اختياري.** من غيره
     * واتساب بيفتح ويقول «تعذّر إرفاق الملف» — الأبلكيشن التاني
     * عملية منفصلة ومالهاش إذن تقرا ملفاتنا إلا لما ندّيه صراحةً.
     *
     * ⚠️ و`createChooser` مش `startActivity` مباشرة: من غيره أندرويد
     * بيفتح آخر أبلكيشن اتستخدم على طول، والمندوب اللي عايز يبعت
     * لعميل تاني مالوش طريقة يغيّر.
     */
    private fun shareImage(bytes: ByteArray, name: String, text: String?, result: MethodChannel.Result) {
        try {
            val dir = File(cacheDir, "invoices")
            if (!dir.exists()) dir.mkdirs()

            // ⚠️ اسم ثابت لكل فاتورة — إعادة المشاركة بتستبدل مش بتكوّم
            val file = File(dir, name)
            FileOutputStream(file).use { it.write(bytes) }

            val uri = androidx.core.content.FileProvider.getUriForFile(
                this, "$packageName.fileprovider", file)

            val send = Intent(Intent.ACTION_SEND).apply {
                type = "image/png"
                putExtra(Intent.EXTRA_STREAM, uri)
                if (!text.isNullOrBlank()) putExtra(Intent.EXTRA_TEXT, text)
                addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
            }

            startActivity(Intent.createChooser(send, null))
            result.success(true)
        } catch (e: Exception) {
            result.error("share_failed", e.message, null)
        }
    }
}
