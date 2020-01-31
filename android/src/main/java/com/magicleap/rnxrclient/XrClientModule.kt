package com.magicleap.rnxrclient

import androidx.appcompat.app.AppCompatActivity
import com.facebook.react.bridge.*
import com.google.ar.core.Pose
import com.google.ar.sceneform.math.Matrix
import com.google.ar.sceneform.math.Quaternion
import com.google.ar.sceneform.math.Vector3
import com.magicleap.xrkit.MLXRAnchor
import java.util.concurrent.Executors

class XrClientModule(private val reactContext: ReactApplicationContext) : ReactContextBaseJavaModule(reactContext) {
    val xrClientSession = XrClientSession()
    val bgExecutor = Executors.newSingleThreadExecutor()

    override fun getName(): String {
        return "XrClientBridge"
    }

    @ReactMethod
    fun connect(token: String, promise: Promise) {
        tryResolveInBackground(promise) {
            xrClientSession.connect(currentActivity as AppCompatActivity, token)
        }
    }

    @ReactMethod
    fun setUpdateInterval(interval: Double, promise: Promise) {
        // no-op for now
        promise.resolve("success")
    }

    @ReactMethod
    fun getAllPCFs(promise: Promise) {
        tryResolveInBackground(promise) {
            val anchors = xrClientSession.getAllAnchors()
            val pcfArray = Arguments.createArray()
            anchors.forEach {
                pcfArray.pushMap(it.toWritableMap())
            }
            pcfArray
        }
    }

    @ReactMethod
    fun getLocalizationStatus(promise: Promise) {
        promise.resolve(xrClientSession.localizationStatus.statusString)
    }

    @ReactMethod
    fun createAnchor(anchorId: String, position: ReadableArray, promise: Promise) {
        tryResolveInBackground(promise) {
            val matrixRaw = FloatArray(16)
            for (i in 0..15) {
                matrixRaw[i] = position.getDouble(i).toFloat()
            }
            val matrix = Matrix(matrixRaw)

            val translation = Vector3()
            val rotationVector = Vector3()
            val quaternion = Quaternion()

            matrix.decomposeTranslation(translation)
            matrix.decomposeRotation(rotationVector, quaternion)

            val pose = Pose(
                    floatArrayOf(translation.x, translation.y, translation.z),
                    floatArrayOf(quaternion.x, quaternion.y, quaternion.z, quaternion.w))

            xrClientSession.createAnchor(anchorId, pose)
            "success"
        }
    }

    @ReactMethod
    fun removeAnchor(anchorId: String, promise: Promise) {
        tryResolveInBackground(promise) {
            xrClientSession.removeAnchor(anchorId)
            "success"
        }
    }

    @ReactMethod
    fun removeAllAnchors(promise: Promise) {
        tryResolveInBackground(promise) {
            xrClientSession.removeAllAnchors()
            "success"
        }
    }

    private fun MLXRAnchor.toWritableMap() : WritableMap {
        val confidence = Arguments.createMap()
        this.getConfidence()?.let {
            confidence.putDouble("confidence", it.confidence.toDouble())
            confidence.putDouble("validRadiusM", it.validRadiusM.toDouble())
            confidence.putDouble("rotationErrDeg", it.rotationErrDeg.toDouble())
            confidence.putDouble("translationErrM", it.translationErrM.toDouble())
        }

        val pose = Arguments.createArray()
        val matrix = FloatArray(16)
        this.getPose()?.let {
            it.toMatrix(matrix, 0)
            matrix.forEach { num -> pose.pushDouble(num.toDouble()) }
        }

        val anchorId = this.getId()?.toString() ?: "DEFAULT"

        val pcf = Arguments.createMap()
        pcf.putMap("confidence", confidence)
        pcf.putArray("pose", pose)
        pcf.putString("anchorId", anchorId)
        return pcf
    }

    private fun tryResolveInBackground(promise: Promise, resolver: () -> Any) {
        bgExecutor.submit {
            tryResolve(promise, resolver)
        }
    }

    private fun tryResolve(promise: Promise, resolver: () -> Any) {
        try {
            val result = resolver()
            promise.resolve(result)
        } catch (throwable: Throwable) {
            promise.reject(throwable)
        }
    }
}
