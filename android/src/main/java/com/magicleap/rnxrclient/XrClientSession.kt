package com.magicleap.rnxrclient

import android.location.Location
import android.os.ConditionVariable
import android.os.Handler
import android.os.Looper
import android.util.Log
import android.view.LayoutInflater
import android.view.View
import android.view.ViewGroup
import android.widget.TextView
import androidx.annotation.AnyThread
import androidx.annotation.MainThread
import androidx.annotation.WorkerThread
import androidx.appcompat.app.AppCompatActivity
import com.google.android.gms.location.FusedLocationProviderClient
import com.google.android.gms.location.LocationServices
import com.google.ar.core.Pose
import com.google.ar.core.TrackingState
import com.google.ar.sceneform.AnchorNode
import com.google.ar.sceneform.Scene
import com.google.ar.sceneform.ux.ArFragment
import com.magicleap.xrkit.MLXRAnchor
import com.magicleap.xrkit.MLXRSession
import java.util.*
import java.util.concurrent.TimeoutException


private const val DEBUG_MODE = false

class XrClientSession {
    companion object {
        private const val TAG = "XRKit"
    }

    private lateinit var arFragment: ArFragment
    private lateinit var mlxrSession: MLXRSession
    private lateinit var fusedLocationClient: FusedLocationProviderClient

    private var currentLocStatus: MLXRSession.LocalizationStatus? = null
    private var currentConnectionStatus: MLXRSession.Status? = null

    private var conStatusText: TextView? = null
    private var locStatusText: TextView? = null
    private var pcfCountText: TextView? = null
    private var debugMessageText: TextView? = null

    private val mainThreadHandler = Handler(Looper.getMainLooper())

    private val anchorNodeMap: MutableMap<String, XrClientAnchorNode> = HashMap()
    private val pendingAnchorIds: MutableSet<String> = HashSet()

    private var sceneOnUpdateListener: Scene.OnUpdateListener? = null

    enum class CollectionEventType { ADDED, UPDATED, REMOVED }

    data class AnchorEventData (
            val type: CollectionEventType,
            var anchor: MLXRAnchor
    )

    private val anchorsById = hashMapOf<String, MLXRAnchor>()

    private var sessionAnchorEvents: Queue<AnchorEventData> = ArrayDeque()

    val localizationStatus: MLXRSession.LocalizationStatus
        get() = currentLocStatus ?: MLXRSession.LocalizationStatus.LocalizationFailed

    val sessionStatus: MLXRSession.Status
        get() = currentConnectionStatus ?: MLXRSession.Status.Disconnected

    @WorkerThread
    fun connect(activity: AppCompatActivity, token: String): Boolean {
        waitForArFragment(activity)
        runOnMainThreadBlocking {
            fusedLocationClient = LocationServices.getFusedLocationProviderClient(activity)
            startArSession(activity)
            startMlxrSession(activity, token)
        }
        return true
    }

    @AnyThread
    fun stop() {
        runOnMainThreadBlocking {
            stopArSession()
            stopMlxrSession()
        }
    }

    @AnyThread
    fun getAllAnchors(): List<MLXRAnchor> {
        val anchors = ArrayList<MLXRAnchor>()
        runOnMainThreadBlocking {
            anchors.addAll(anchorsById.values)
        }
        return anchors
    }

    @WorkerThread
    private fun waitForArFragment(activity: AppCompatActivity) {
        var foundArFragment = false
        val waitTime = 30 * 1000 // Poll for 30 seconds
        val sleepTime = 50L // Sleep for 50ms between polling
        repeat((waitTime / sleepTime).toInt()) {
            runOnMainThreadBlocking {
                val frag = activity.supportFragmentManager.findFragmentByTag("arFragment") as ArFragment?
                frag?.let {
                    arFragment = it
                    foundArFragment = true
                }
            }
            if (foundArFragment) {
                return
            } else {
                try {
                    Thread.sleep(sleepTime)
                } catch (ignore: InterruptedException) {}
            }
        }
        throw TimeoutException("Timed out waiting for ArFragment")
    }

    @MainThread
    private fun startArSession(activity: AppCompatActivity) {
        if (DEBUG_MODE) {
            addDebugOverlay(activity, arFragment)
        }

        sceneOnUpdateListener = Scene.OnUpdateListener { frameTime ->
            arFragment.onUpdate(frameTime)
            if (arFragment.arSceneView.arFrame?.camera?.trackingState == TrackingState.TRACKING) {
                onUpdate()
            }
        }
        arFragment.arSceneView.scene.addOnUpdateListener(sceneOnUpdateListener)
    }

    @MainThread
    private fun stopArSession() {
        sceneOnUpdateListener?.let {
            arFragment.arSceneView.scene.removeOnUpdateListener(it)
        }
    }

    @AnyThread
    private fun addDebugOverlay(activity: AppCompatActivity, arFragment: ArFragment) {
        val parent = arFragment.view?.rootView as ViewGroup?
        parent?.post {
            if (parent.findViewById<View>(R.id.debugOverlay) == null) {
                LayoutInflater.from(activity).inflate(R.layout.debug_overlay, parent)
                conStatusText = activity.findViewById(R.id.sessionStatus)
                locStatusText = activity.findViewById(R.id.localizationStatus)
                pcfCountText = activity.findViewById(R.id.pcfCount)
                debugMessageText = activity.findViewById(R.id.debugMessage)
            }
        }
    }

    private fun startMlxrSession(activity: AppCompatActivity, token: String) {
        mlxrSession = MLXRSession(activity)
        mlxrSession.start(token)
        mlxrSession.setOnAnchorUpdateListener(object : MLXRSession.OnAnchorUpdateListener {
            @Synchronized
            override fun onAdd(added: List<MLXRAnchor>) {
                for (anchor in added) {
                    addAnchorEvents(AnchorEventData(CollectionEventType.ADDED, anchor))
                }
            }

            @Synchronized
            override fun onUpdate(updated: List<MLXRAnchor>) {
                for (anchor in updated) {
                    addAnchorEvents(AnchorEventData(CollectionEventType.UPDATED, anchor))
                }
            }

            @Synchronized
            override fun onRemove(removed: List<MLXRAnchor>) {
                for (anchor in removed) {
                    addAnchorEvents(AnchorEventData(CollectionEventType.REMOVED, anchor))
                }
            }
        })
    }

    private fun stopMlxrSession() {
        mlxrSession.stop()
    }

    @MainThread
    private fun updateConnectionStatus() {
        val conStatus = mlxrSession.getConnectionStatus()
        if (currentConnectionStatus != conStatus) {
            currentConnectionStatus = conStatus
            val conStatusString = currentConnectionStatus.statusString
            conStatusText?.let { it.text = conStatusString }
        }
    }

    @MainThread
    private fun updateLocStatus() {
        val locStatus = mlxrSession.getLocalizationStatus()
        if (currentLocStatus != locStatus) {
            currentLocStatus = locStatus
            val locStatusString = locStatus.statusString
            locStatusText?.let { it.text = locStatusString }
        }
    }

    @MainThread
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

    @MainThread
    private fun updateMlxrAnchors() {
        val updatedAnchorEvents = getAnchorEvents()
        for (anchorEvent in updatedAnchorEvents) {
            when (anchorEvent.type) {
                CollectionEventType.ADDED -> {
                    addAnchorToMap(anchorEvent.anchor)
                }
                CollectionEventType.UPDATED -> {
                    removeAnchorFromMap(anchorEvent.anchor)
                    addAnchorToMap(anchorEvent.anchor)
                }
                CollectionEventType.REMOVED -> {
                    removeAnchorFromMap(anchorEvent.anchor)
                }
            }
        }
    }

    @MainThread
    private fun updateLocalAnchors() {
        val iterator = pendingAnchorIds.iterator()
        iterator.forEach {
            if (anchorNodeMap[it]?.tryCreateAnchor(arFragment.arSceneView) == true) {
                iterator.remove()
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

        val anchorId = anchor.getId().toString()
        anchorsById[anchorId] = anchor
    }

    @MainThread
    fun removeAnchorFromMap(anchor: MLXRAnchor) {
        val anchorId = anchor.getId().toString()
        anchorsById.remove(anchorId)
    }

    @MainThread
    private fun onUpdate() {
        updateConnectionStatus()
        updateLocStatus()
        updateMlxrAnchors()
        updateLocalAnchors()
        updateFrame()

        if (DEBUG_MODE) {
            updateDebugData()
        }
    }

    @MainThread
    private fun updateDebugData() {
        val anchors = getAllAnchors()
        pcfCountText?.let { it.text = "PCFs : ${anchors.size}" }
    }

    @AnyThread
    fun createAnchor(anchorId: String, pose: Pose) {
        arFragment.view?.post {
            val scene = arFragment.arSceneView.scene

            if (anchorNodeMap.containsKey(anchorId)) {
                throw IllegalArgumentException("createAnchor called with existing anchor ID")
            }

            val anchorNode = XrClientAnchorNode(anchorId, pose)
            scene.addChild(anchorNode)
            anchorNodeMap[anchorId] = anchorNode

            if (!anchorNode.tryCreateAnchor(arFragment.arSceneView)) {
                pendingAnchorIds.add(anchorId)
            }

        } ?: throw IllegalStateException("createAnchor called with no AR Scene View")
    }

    @AnyThread
    fun removeAnchor(anchorId: String) {
        arFragment.view?.post {
            anchorNodeMap.remove(anchorId)
            pendingAnchorIds.remove(anchorId)

            val scene = arFragment.arSceneView.scene

            val anchorNode = scene.findByName(anchorId)
            if (anchorNode !is AnchorNode) {
                throw IllegalArgumentException("No AnchorNode found with ID $anchorId")
            }
            arFragment.arSceneView.scene.removeChild(anchorNode)

            anchorNode.anchor?.detach()

        } ?: throw IllegalStateException("removeAnchor called with no AR Scene View")
    }

    @AnyThread
    fun removeAllAnchors() {
        arFragment.view?.post {
            anchorNodeMap.forEach { (anchorId, _) ->
                removeAnchor(anchorId)
            }
        }
    }

    @AnyThread
    private fun runOnMainThreadBlocking(task: () -> Unit) {
        if (Looper.myLooper() == mainThreadHandler.looper) {
            task()
            return
        }

        val done = ConditionVariable()
        var ex: Throwable? = null
        mainThreadHandler.post {
            try {
                task()
            } catch (t: Throwable) {
                ex = t
            } finally {
                done.open()
            }
        }
        if (!done.block(30 * 1000)) {
            throw TimeoutException("Timed out waiting for main thread task")
        }
        ex?.let {
            throw it
        }
    }
}

val MLXRSession.LocalizationStatus?.statusString: String
    get() = when(this) {
        MLXRSession.LocalizationStatus.AwaitingLocation -> "awaitingLocation"
        MLXRSession.LocalizationStatus.ScanningLocation -> "scanningLocation"
        MLXRSession.LocalizationStatus.Localized -> "localized"
        MLXRSession.LocalizationStatus.LocalizationFailed -> "localizationFailed"
        else -> "localizationFailed"
    }

val MLXRSession.Status?.statusString: String
    get() = when(this) {
        MLXRSession.Status.Connected -> "connected"
        MLXRSession.Status.Connecting -> "connecting"
        MLXRSession.Status.Disconnected -> "disconnected"
        else -> "disconnected"
    }
