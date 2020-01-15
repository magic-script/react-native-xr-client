package com.rnxrclient

import android.location.Location
import android.util.Log
import android.view.LayoutInflater
import android.view.ViewGroup
import android.widget.TextView
import androidx.annotation.MainThread
import androidx.appcompat.app.AppCompatActivity
import com.google.android.gms.location.FusedLocationProviderClient
import com.google.android.gms.location.LocationServices
import com.google.ar.core.Pose
import com.google.ar.core.TrackingState
import com.google.ar.sceneform.AnchorNode
import com.google.ar.sceneform.ux.ArFragment
import com.magicleap.xrkit.MLXRAnchor
import com.magicleap.xrkit.MLXRSession
import com.magicleap.xrkit.MLXRSessionEx
import java.lang.IllegalArgumentException
import java.lang.IllegalStateException
import java.util.*


private const val DEBUG_MODE = true

class XrClientSession {
    private val TAG: String = "XRKit"

    private lateinit var arFragment: ArFragment
    private lateinit var mlxrSession: MLXRSessionEx
    private lateinit var fusedLocationClient: FusedLocationProviderClient

    private val anchorIds: MutableSet<String> = mutableSetOf()

    private var currentLocStatus: MLXRSession.LocalizationStatus? = null
    private var currentConnectionStatus: MLXRSession.Status? = null

    private var conStatusText: TextView? = null
    private var locStatusText: TextView? = null
    private var pcfCountText: TextView? = null
    private var debugMessageText: TextView? = null

    enum class AnchorEventType { ADDED, UPDATED, REMOVED }

    data class AnchorEventData (
            val type: AnchorEventType,
            var anchor: MLXRAnchor
    )

    private var anchorsById = hashMapOf<String, MLXRAnchor>()
    private var sessionAnchorEvents: Queue<AnchorEventData> = ArrayDeque<AnchorEventData>()

    val localizationStatus: MLXRSession.LocalizationStatus
        get() = currentLocStatus ?: MLXRSession.LocalizationStatus.LocalizationFailed

    fun connect(activity: AppCompatActivity, token: String): String {
        startArSession(activity)
        startMlxrSession(token)
        return mlxrSession.getConnectionStatus()?.name ?: "null"
    }

    fun getAllAnchors(): List<MLXRAnchor> {
        return ArrayList<MLXRAnchor>(anchorsById.values)
    }

    private fun startArSession(activity: AppCompatActivity) {
        mlxrSession = MLXRSessionEx(activity)
        fusedLocationClient = LocationServices.getFusedLocationProviderClient(activity)
        arFragment = activity.supportFragmentManager.findFragmentByTag("arFragment") as ArFragment

        if (DEBUG_MODE) {
            addDebugOverlay(activity, arFragment)
        }

        arFragment.arSceneView.scene.addOnUpdateListener { frameTime ->
            arFragment.onUpdate(frameTime)
            if (arFragment.arSceneView.arFrame?.camera?.trackingState == TrackingState.TRACKING) {
                onUpdate()
            }
        }
    }

    private fun addDebugOverlay(activity: AppCompatActivity, arFragment: ArFragment) {
        val parent = arFragment.view?.rootView as ViewGroup?
        parent?.post {
            LayoutInflater.from(activity).inflate(R.layout.debug_overlay, parent)
            conStatusText = activity.findViewById(R.id.sessionStatus)
            locStatusText = activity.findViewById(R.id.localizationStatus)
            pcfCountText = activity.findViewById(R.id.pcfCount)
            debugMessageText = activity.findViewById(R.id.debugMessage)
        }
    }

    private fun startMlxrSession(token: String) {
        // Staging
        val gatewayAddress = "ssl://dcg.staging.mglp.net:443"
        val pwAddress = "pwg.staging.mglp.net:443"
        val deviceId = ""

        mlxrSession.configure(gatewayAddress, pwAddress, deviceId)
        Log.i(TAG, "mlxrSession.configure($gatewayAddress, $pwAddress, $deviceId)")
        mlxrSession.setToken(token)
        mlxrSession.start()
        mlxrSession.setOnAnchorUpdateListener(object : MLXRSession.OnAnchorUpdateListener {
            @Synchronized
            override fun onAdd(added: List<MLXRAnchor>) {
                Log.i(TAG, "anchor added event called")
                for (anchor in added) {
                    addAnchorEvents(AnchorEventData(AnchorEventType.ADDED, anchor))
                }
            }

            @Synchronized
            override fun onUpdate(updated: List<MLXRAnchor>) {
                Log.i(TAG, "anchor updated event called")
                for (anchor in updated) {
                    addAnchorEvents(AnchorEventData(AnchorEventType.UPDATED, anchor))
                }
            }

            @Synchronized
            override fun onRemove(removed: List<MLXRAnchor>) {
                Log.i(TAG, "anchor removed event called")
                for (anchor in removed) {
                    addAnchorEvents(AnchorEventData(AnchorEventType.REMOVED, anchor))
                }
            }
        })
    }

    private fun updateConnectionStatus() {
        val conStatus = mlxrSession.getConnectionStatus()
        if (currentConnectionStatus != conStatus) {
            currentConnectionStatus = conStatus
            val conStatusString = currentConnectionStatus.statusString
            Log.i(TAG, conStatusString)
            conStatusText?.let { it.text = conStatusString }
        }
    }

    private fun updateLocStatus() {
        val locStatus = mlxrSession.getLocalizationStatus()
        if (currentLocStatus != locStatus) {
            currentLocStatus = locStatus
            val locStatusString = locStatus.statusString
            Log.i(TAG, locStatusString)
            locStatusText?.let { it.text = locStatusString }
        }
    }

    private fun updateFrame() {
        fusedLocationClient.lastLocation
            .addOnSuccessListener { location: Location? ->
                val arFrame = arFragment.arSceneView.arFrame
                if (arFrame != null && location != null) {
                    mlxrSession.update(arFrame, location)
                }
            }
            .addOnFailureListener { e : Exception ->
                Log.e(TAG, "failed to get the location data - " + e.localizedMessage)
            }
    }

    private fun updateAnchors() {
        val updatedAnchorEvents = getAnchorEvents()
        for (anchorEvent in updatedAnchorEvents) {
            when (anchorEvent.type) {
                AnchorEventType.ADDED -> {
                    addAnchorToMap(anchorEvent.anchor)
                }
                AnchorEventType.UPDATED -> {
                    removeAnchorFromMap(anchorEvent.anchor)
                    addAnchorToMap(anchorEvent.anchor)
                }
                AnchorEventType.REMOVED -> {
                    removeAnchorFromMap(anchorEvent.anchor)
                }
            }
        }
    }

    @Synchronized
    private fun addAnchorEvents(anchorData: AnchorEventData) {
        sessionAnchorEvents.add(anchorData)
    }

    @Synchronized
    private fun getAnchorEvents(): Queue<AnchorEventData> {
        var sessionAnchorEventsCopy: Queue<AnchorEventData> = ArrayDeque<AnchorEventData>()
        sessionAnchorEventsCopy = sessionAnchorEvents.also {
            sessionAnchorEvents = sessionAnchorEventsCopy
        }
        return sessionAnchorEventsCopy
    }

    @MainThread
    fun addAnchorToMap(anchor: MLXRAnchor) {
        val pose = anchor.getPose()
        if (pose === null) {
            return
        }

        val confidence = anchor.getConfidence()
        if (confidence === null) {
            return
        }

        var anchorId = anchor.getId().toString()
        anchorsById[anchorId] = anchor
    }

    @MainThread
    fun removeAnchorFromMap(anchor: MLXRAnchor) {
        val anchorId = anchor.getId().toString()
        anchorsById.remove(anchorId)
    }

    private fun onUpdate() {
        updateConnectionStatus()
        updateLocStatus()
        updateAnchors()
        updateFrame()

        if (DEBUG_MODE) {
            updateDebugData()
        }
    }

    private fun updateDebugData() {
        val anchors = getAllAnchors()
        pcfCountText?.let { it.text = "PCFs : ${anchors.size}" }
    }

    fun createAnchor(anchorId: String, pose: Pose) {
        arFragment.view?.post {
            val scene = arFragment.arSceneView.scene
            val session = arFragment.arSceneView.session ?:
            throw IllegalStateException("createAnchor called with no AR Session")

            val anchor = session.createAnchor(pose)
            val anchorNode = AnchorNode(anchor)
            anchorNode.name = anchorId
            scene.addChild(anchorNode)

            anchorIds.add(anchorId)
        } ?: throw IllegalStateException("createAnchor called with no AR Scene View")
    }

    fun removeAnchor(anchorId: String) {
        arFragment.view?.post {
            val scene = arFragment.arSceneView.scene

            val anchorNode = scene.findByName(anchorId)
            if (anchorNode !is AnchorNode) {
                throw IllegalArgumentException("No AnchorNode found with ID $anchorId")
            }
            scene.removeChild(anchorNode)
            anchorNode.anchor?.let {
                it.detach()
            }

            anchorIds.remove(anchorId)
        } ?: throw IllegalStateException("removeAnchor called with no AR Scene View")
    }

    fun removeAllAnchors() {
        arFragment.view?.post {
            anchorIds.forEach {
                removeAnchor(it)
            }
        }
    }
}

val MLXRSession.LocalizationStatus?.statusString: String
    get() = when(this) {
        MLXRSession.LocalizationStatus.AwaitingLocation -> "awaiting location"
        MLXRSession.LocalizationStatus.ScanningLocation -> "scanning location"
        MLXRSession.LocalizationStatus.Localized -> "localized"
        MLXRSession.LocalizationStatus.LocalizationFailed -> "localization failed"
        else -> "localization status unknown"
    }

val MLXRSession.Status?.statusString: String
    get() = when(this) {
        MLXRSession.Status.Connected -> "connected"
        MLXRSession.Status.Connecting -> "connecting"
        MLXRSession.Status.Disconnected -> "disconnected"
        else -> "disconnected"
    }
