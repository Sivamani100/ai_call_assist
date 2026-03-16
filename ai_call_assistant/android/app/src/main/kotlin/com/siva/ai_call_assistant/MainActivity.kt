// android/app/src/main/kotlin/com/siva/ai_call_assistant/MainActivity.kt
package com.siva.ai_call_assistant

import android.content.Intent
import android.net.Uri
import android.telephony.TelephonyManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import android.Manifest
import android.content.pm.PackageManager
import androidx.core.app.ActivityCompat

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.siva.ai_call_assistant/call_forwarding"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
            when (call.method) {
                "enableForwarding" -> {
                    val exotelNumber = call.argument<String>("exotelNumber") ?: ""
                    enableCallForwarding(exotelNumber, result)
                }
                "disableForwarding" -> disableCallForwarding(result)
                "checkForwardingStatus" -> checkForwardingStatus(result)
                else -> result.notImplemented()
            }
        }
    }

    private fun enableCallForwarding(exotelNumber: String, result: MethodChannel.Result) {
        if (ActivityCompat.checkSelfPermission(this, Manifest.permission.CALL_PHONE)
            != PackageManager.PERMISSION_GRANTED) {
            result.error("PERMISSION_DENIED", "CALL_PHONE permission required", null)
            return
        }
        // exotelNumber should be in E.164 format: +918047123456
        // URL-encode: + becomes %2B, # becomes %23
        // Full USSD: *21*%2B918047123456%23
        val encoded = exotelNumber.replace("+", "%2B")
        val ussdCode = "*21*${encoded}%23"
        val intent = Intent(Intent.ACTION_CALL, Uri.parse("tel:$ussdCode"))
        intent.flags = Intent.FLAG_ACTIVITY_NEW_TASK
        startActivity(intent)
        result.success("Forwarding enabled to $exotelNumber")
    }

    private fun disableCallForwarding(result: MethodChannel.Result) {
        if (ActivityCompat.checkSelfPermission(this, Manifest.permission.CALL_PHONE)
            != PackageManager.PERMISSION_GRANTED) {
            result.error("PERMISSION_DENIED", "CALL_PHONE permission required", null)
            return
        }
        // ##21# cancels all unconditional forwarding
        val intent = Intent(Intent.ACTION_CALL, Uri.parse("tel:%23%2321%23"))
        intent.flags = Intent.FLAG_ACTIVITY_NEW_TASK
        startActivity(intent)
        result.success("Forwarding disabled")
    }

    private fun checkForwardingStatus(result: MethodChannel.Result) {
        val manager = getSystemService(TELEPHONY_SERVICE) as TelephonyManager
        manager.sendUssdRequest("*#21#",
            object : TelephonyManager.UssdResponseCallback() {
                override fun onReceiveUssdResponse(tm: TelephonyManager,
                    request: String, response: CharSequence) {
                    result.success(response.toString())
                }
                override fun onReceiveUssdResponseFailed(tm: TelephonyManager,
                    request: String, failureCode: Int) {
                    result.error("USSD_FAILED", "Code: $failureCode", null)
                }
            }, android.os.Handler(mainLooper))
    }
}
