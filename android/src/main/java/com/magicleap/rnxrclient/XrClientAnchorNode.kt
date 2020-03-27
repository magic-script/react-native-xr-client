package com.magicleap.rnxrclient

import android.util.Log
import com.google.ar.core.Pose
import com.google.ar.core.TrackingState
import com.google.ar.sceneform.AnchorNode
import com.google.ar.sceneform.ArSceneView

/**
 * An AnchorNode that facilitates delayed creation of the Anchor itself until the
 * AR Scene tracking state allows for it.
 */
class XrClientAnchorNode(anchorUuid: String, private val pose: Pose) : AnchorNode() {
    companion object {
        private const val TAG = "XrClientAnchorNode"
    }

    init {
        name = anchorUuid
        Log.i(TAG, "Init XrClientAnchorNode: $name")
    }

    fun tryCreateAnchor(sceneView: ArSceneView): Boolean {
        if (anchor == null && sceneView.arFrame?.camera?.trackingState == TrackingState.TRACKING) {
            anchor = sceneView.session?.createAnchor(pose);
            Log.i(TAG, "Create anchor for XrClientAnchorNode: $name")
            return true
        }
        return false
    }
}