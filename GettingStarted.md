# Use `react-natrive-xr-client` in MagicScript Components project

1. Create project

```bash
react-native init <project name>
```

2. Update the `package.json`. Add the following dependencies:
```javascript
"react-native-xr-client": "0.0.6",
"react-native-app-auth": "^4.4.0",
"magic-script-components": "^2.0.2",
"magic-script-components-react-native": "^1.0.2"
```
3. add `.npmrc` file:
```bash
registry=https://nexus.magicleap.blue/repository/npm-group/
```

4. Remove `*.lock` files:
- yarn.lock
- ios/Podfile.lock

5. Copy `proxy_mobile` folder to the project root folder 
6. Update `index.js` file: 
```javascript
import React from 'react';
import { MagicScript } from './proxy_mobile';
import MyApp from './App';

MagicScript.registerApp('<your project name>', <MyApp clientId='your.client.id.for.oauth'/>, false);
```

7. Update `App.js` file (demo code):
```javascript
import React from 'react';
import { View, Text } from 'magic-script-components';
import AnchorCube from './anchor-cube.js';

import { authorize } from 'react-native-app-auth';
import { NativeModules } from 'react-native';

const { XrApp, XrClientBridge } = NativeModules;

const oAuthConfig = {
  cacheKey: 'auth/prod',
  issuer: 'https://auth.magicleap.com',
  clientId: 'com.magicleap.mobile.magicscript',
  redirectUrl: 'magicscript://code-callback',
  scopes: [
    'openid',
    'profile',
    'email'
  ],
  serviceConfiguration: {
    authorizationEndpoint: 'https://oauth.magicleap.com/auth',
    tokenEndpoint: 'https://oauth.magicleap.com/token'
  }
};

const sleep = ms => new Promise(resolve => setTimeout(resolve, ms));
const getUUID = (id, pose) => `${id}#[${pose}]`;

class MyApp extends React.Component {
  constructor (props) {
    super(props);

    this.state = {
      scenes: {},
      anchorCount: 0
    };
  }

  componentDidMount () {
    setTimeout(async () => {
      console.log('MyXrDemoApp: sharing ARSession');
      await XrApp.shareSession();

      await sleep(1000);

      const oauth = await this.authorizeToXrServer(oAuthConfig);

      await sleep(1000);

      const status = await this.connectToXrServer(oauth);

      this._updateInterval = setInterval(() => this.updateAnchors(), 1000);

    }, 1000);
  }

  componentWillUnmount () {
    if (Object.keys(this.state.scenes).length > 0) {
      XrClientBridge.removeAllAnchors();
    }
  }

  async authorizeToXrServer (config) {
    console.log('MyXrDemoApp: authorizing');
    const result = await authorize(config);
    console.log('MyXrDemoApp: oAuthData', result);
    return result;
  }

  async connectToXrServer (config) {
    console.log('MyXrDemoApp: XrClientBridge.connecting');
    const result = await XrClientBridge.connect(config.accessToken);
    console.log('MyXrDemoApp: XrClientBridge.connect result', result);
    return result;
  }

  async updateAnchors () {
    const status = await XrClientBridge.getLocalizationStatus();
    console.log('MyXrDemoApp: localization status', status);

    if (status === 'localized' && this.state.anchorCount === 0) {
      const pcfList = await XrClientBridge.getAllPCFs();
      console.log(`MyXrDemoApp: received ${pcfList.length} PCFs`);

      if (pcfList.length > 0) {
        clearInterval(this._updateInterval);
      }

      var scenes = {};

      pcfList.forEach(pcfData => this.updateScenes(scenes, pcfData));

      Object.values(scenes).forEach(scene => {
        XrClientBridge.createAnchor(scene.uuid, scene.pcfPose);
      });

      this.setState({ scenes: scenes, anchorCount: pcfList.length });
    }
  }

  updateScenes (scenes, pcfData) {
    const uuid = getUUID(pcfData.anchorId, pcfData.pose);

    if (scenes[pcfData.anchorId] === undefined) {
      scenes[pcfData.anchorId] = {
        uuid: uuid,
        pcfId: pcfData.anchorId,
        pcfPose: pcfData.pose
      };
    }
  }

  render () {
    const scenes = Object.values(this.state.scenes);
    return (
      <View name='main-view'>
        { scenes.length === 0
          ? (<Text text='Initializing ...' />)
          : scenes.map( scene => <AnchorCube key={scene.uuid} uuid={scene.uuid} id={scene.pcfId} />)
        }
      </View>
    );
  }
}

export default MyApp;
```

8. Delete `app.json` file.

9. Run `yarn` from the terminal (main project folder)
```bash
yarn
```

## iOS Instructions:

1. Edit the Podfile (from `ios` folder)
- Remove unnecessary targets
- Update the `platform :ios` to `12`
```python
platform :ios, '12.0'
```

2. Save `MLXR.framework` to local folder

3. Run `pod install` from the terminal (ios folder)
```bash
pod install
```

4. Open XCode and open `ios/<ProjectName>.xcworkspace` file
    1. Add `EmptySwift.swift` to the `<ProjectName>` and create the `<ProjectName>-Brigging-Header.h`
    2. Add `MLXR.framework` to the project from `General / Libraries`
    3. Select team for signing form `Signing / Team`
    4. Add `path` to the `MLXR.Framework` to `Build Settings / Search Paths` Framework and Header
    5. Add `path` to the `MLXR.Framework` to `RNXrClient.xcconfig` (from `Pods/Development Pods/RNXrClient/Supported Files/RNXrClient.xcconfig)
    ```
    FRAMEWORK_SEARCH_PATHS = $(inherited) "${PODS_ROOT}/path/to/MLXR/framework"
    HEADER_SEARCH_PATHS = <previous entry> "${PODS_ROOT}/path/to/MLXR/framework"
    ```
    6. Add to `Info.plist` the following item `Privacy - Camera Usage Description`

5. Add `XrApp.h` file to the project:
```objective-c
#import <React/RCTBridgeModule.h>

@interface XrApp : NSObject <RCTBridgeModule>

@end
```
6. Add `XrApp.m` file to the project:
```objective-c
#import "XrApp.h"
#import <ARKit/ARKit.h>

@import RNMagicScript;
@import RNXrClient;

@implementation XrApp

RCT_EXPORT_MODULE()

RCT_EXPORT_METHOD(shareSession:(RCTPromiseResolveBlock)resolve reject:(RCTPromiseRejectBlock)reject)
{
      [RNXrClient registerSession: RCTARView.arSession];
      resolve(@"success");
}

@end
```

7. Update `AppDelegate.h` file:
```objective-c
#import <React/RCTBridgeDelegate.h>
#import <UIKit/UIKit.h>
#import "RNAppAuthAuthorizationFlowManager.h"

@interface AppDelegate : UIResponder <UIApplicationDelegate, RCTBridgeDelegate, RNAppAuthAuthorizationFlowManager>

@property (nonatomic, strong) UIWindow *window;
@property (nonatomic, weak)id<RNAppAuthAuthorizationFlowManagerDelegate>authorizationFlowManagerDelegate;

@end
```

8. Add to `AppDelegate.m` file:
```objective-c
#import "AppDelegate.h"

#import <React/RCTBridge.h>
#import <React/RCTBundleURLProvider.h>
#import <React/RCTRootView.h>
#import <React/RCTLinkingManager.h>

@implementation AppDelegate

- (BOOL)application:(UIApplication *)app openURL:(NSURL *)url options:(NSDictionary<NSString *, id> *) options {
  return [self.authorizationFlowManagerDelegate resumeExternalUserAgentFlowWithURL:url];
}

...
```

9. Build and run the project:
- from the terminal:
```bash
react-native run-ios --device
```

- or from XCode `build` & `run` 

## Android Instructions:

1. Delete Android source files `MainActivity.java` and `MainApplication.java`.

2. Add `MainActivity.kt` file to the project:
```kotlin
package com.magicscriptxrsample

import android.Manifest
import android.content.pm.PackageManager
import android.os.Bundle
import android.util.Log
import android.widget.Toast
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import com.facebook.react.ReactActivity

class MainActivity : ReactActivity() {

    private val permissionRequestCode = 1

    /**
     * Returns the name of the main component registered from JavaScript. This is used to schedule
     * rendering of the component.
     */
    override fun getMainComponentName(): String? {
        return "MagicScriptXRSample"
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        permissionRequest()
    }

    private fun permissionRequest(): Boolean {
        var permissions = arrayListOf<String>()
        if (ContextCompat.checkSelfPermission(this, Manifest.permission.CAMERA) != PackageManager.PERMISSION_GRANTED) {
            if (!ActivityCompat.shouldShowRequestPermissionRationale(this, Manifest.permission.CAMERA)) {
                permissions.add(Manifest.permission.CAMERA)
            }
        }
        if (ContextCompat.checkSelfPermission(this, Manifest.permission.ACCESS_FINE_LOCATION) != PackageManager.PERMISSION_GRANTED) {
            if (!ActivityCompat.shouldShowRequestPermissionRationale(this, Manifest.permission.ACCESS_FINE_LOCATION)) {
                permissions.add(Manifest.permission.ACCESS_FINE_LOCATION)
            }
        }

        if (permissions.size > 0) {
            ActivityCompat.requestPermissions(this, permissions.toArray(arrayOfNulls(permissions.size)), permissionRequestCode)
        }
        return when (permissions.size) {
            0 -> true
            else -> false
        }
    }

    override fun onRequestPermissionsResult(
            requestCode: Int,
            permissions: Array<out String>,
            grantResults: IntArray
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)

        when (requestCode) {
            permissionRequestCode -> {
                if (grantResults.isEmpty() || grantResults[0] != PackageManager.PERMISSION_GRANTED) {
                    Log.e("RNXRClient", "fine location permission request denied")
                    Toast.makeText(this, "Requires all permissions to use the app.", Toast.LENGTH_LONG).show()
                }
            }
        }
    }
}
```

3. Add `MainApplication.kt` file to the project:
```kotlin
package com.magicscriptxrsample

import android.app.Application
import android.content.Context
import com.facebook.react.*
import com.facebook.soloader.SoLoader
import java.lang.reflect.InvocationTargetException

class MainApplication : Application(), ReactApplication {
    private val mReactNativeHost: ReactNativeHost = object : ReactNativeHost(this) {
        override fun getUseDeveloperSupport(): Boolean {
            return BuildConfig.DEBUG
        }

        override fun getPackages(): List<ReactPackage> {
            val packages: MutableList<ReactPackage> = PackageList(this).packages
            // Packages that cannot be autolinked yet can be added manually here, for example:
            packages.add(XrAppPackage())
            return packages
        }

        override fun getJSMainModuleName(): String {
            return "index"
        }
    }

    override fun getReactNativeHost(): ReactNativeHost {
        return mReactNativeHost
    }

    override fun onCreate() {
        super.onCreate()
        SoLoader.init(this,  /* native exopackage */false)
        initializeFlipper(this) // Remove this line if you don't want Flipper enabled
    }

    companion object {
        /**
         * Loads Flipper in React Native templates.
         *
         * @param context
         */
        private fun initializeFlipper(context: Context) {
            if (BuildConfig.DEBUG) {
                try { /*
         We use reflection here to pick up the class that initializes Flipper,
        since Flipper library is not available in release mode
        */
                    val aClass = Class.forName("com.facebook.flipper.ReactNativeFlipper")
                    aClass.getMethod("initializeFlipper", Context::class.java).invoke(null, context)
                } catch (e: ClassNotFoundException) {
                    e.printStackTrace()
                } catch (e: NoSuchMethodException) {
                    e.printStackTrace()
                } catch (e: IllegalAccessException) {
                    e.printStackTrace()
                } catch (e: InvocationTargetException) {
                    e.printStackTrace()
                }
            }
        }
    }
}
```

4. Add `XrAppModule.kt` file to the project:
```kotlin
package com.magicscriptxrsample

import com.facebook.react.bridge.Promise
import com.facebook.react.bridge.ReactApplicationContext
import com.facebook.react.bridge.ReactContextBaseJavaModule
import com.facebook.react.bridge.ReactMethod

class XrAppModule internal constructor(context: ReactApplicationContext?) : ReactContextBaseJavaModule(context!!) {
    override fun getName(): String {
        return "XrApp"
    }

    @ReactMethod
    fun shareSession(promise: Promise) {
        promise.resolve("success")
    }
}
```

5. Add `XrAppPackage.kt` file to the project:
```kotlin
package com.magicscriptxrsample

import com.facebook.react.ReactPackage
import com.facebook.react.bridge.NativeModule
import com.facebook.react.bridge.ReactApplicationContext
import com.facebook.react.uimanager.ViewManager

class XrAppPackage : ReactPackage {
    override fun createNativeModules(reactContext: ReactApplicationContext): List<NativeModule> {
        return listOf<NativeModule>(XrAppModule(reactContext))
    }

    override fun createViewManagers(reactContext: ReactApplicationContext): List<ViewManager<*, *>> {
        return emptyList()
    }
}
```

6. Add required permissions to `AndroidManifest.xml`:
```xml
    <uses-permission android:name="android.permission.CAMERA" />
    <uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />
```

7. Increase max JVM memory by adding to `android/gradle.properties`:
```
org.gradle.jvmargs=-Xmx1536m
```

8. Update top-level android/build.gradle:
    1. Add kotlin version (under `buildscript`):
    ```groovy
    ext.kotlin_version = '1.3.50'
    ```

    2. Change `minSdkVersion`:
    ```groovy
    minSdkVersion = 26
    ```

    3. Add dependencies:
    ```groovy
    classpath "org.jetbrains.kotlin:kotlin-gradle-plugin:$kotlin_version"
    classpath 'com.google.ar.sceneform:plugin:1.13.0'
    ```

9. Update android/app/build.gradle:
    1. Add auth config (under `android / defaultConfig`):
    ```groovy
    manifestPlaceholders = [
        appAuthRedirectScheme: 'magicscript'
    ]
    ```

    2. Add dependencies:
    ```groovy
    implementation 'androidx.appcompat:appcompat:1.1.0'
    implementation 'androidx.constraintlayout:constraintlayout:1.1.3'
    implementation 'com.google.android.material:material:1.0.0'
    implementation "org.jetbrains.kotlin:kotlin-stdlib-jdk7:$kotlin_version"
    implementation 'androidx.core:core-ktx:1.1.0'
    implementation 'androidx.constraintlayout:constraintlayout:1.1.3'
    implementation 'com.google.ar:core:1.13.0'
    implementation 'com.google.ar.sceneform.ux:sceneform-ux:1.13.0'
    implementation 'com.google.ar.sceneform:core:1.13.0'
    implementation 'com.google.android.gms:play-services-location:17.0.0'
    ```

    3. Add kotlin plugins:
    ```groovy
    apply plugin: 'kotlin-android'
    apply plugin: 'kotlin-android-extensions'
    ```

10. Build and run the project:
- from the terminal:
```bash
react-native run-android
```

- or from Android Studio `Run`
