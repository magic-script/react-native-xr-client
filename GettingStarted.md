# Use `react-native-xr-client` in MagicScript Components project

1. Create project using interactive CLI
```
magic-script init

? What is the name of your application? MagicScriptXRSample
? What is the app ID of your application? com.magicscript.xrsample
? In which folder do you want to save this project? MagicScriptXRSample
? What app type do you want? Components
? What platform do you want develop on? iOS, Android
? Use TypeScript? No
```

2. Update `reactnative/package.json`. Add the following dependencies:
```javascript
"react-native-xr-client": "0.0.6",
"react-native-app-auth": "^4.4.0"
```

3. add `.npmrc` file:
```bash
registry=https://nexus.magicleap.blue/repository/npm-group/
```

4. Remove `*.lock` files:
- yarn.lock
- reactnative/ios/Podfile.lock

5. Update `src/app.js` file (demo code):
```javascript
import React from 'react';
import { View, Text } from 'magic-script-components';
import { authorize } from 'react-native-app-auth';
import { NativeModules } from 'react-native';

import AnchorCube from './anchor-cube.js';

const { XrClientBridge } = NativeModules;

const oAuthConfig = {
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

const getUUID = (id, pose) => `${id}#[${pose}]`;

class MyApp extends React.Component {
  constructor (props) {
    super(props);

    this.state = {
      scenes: {},
      anchorCount: 0
    };
  }

  async componentDidMount () {
    const oauth = await this.authorizeToXrServer(oAuthConfig);
    const status = await this.connectToXrServer(oauth);

    this._updateInterval = setInterval(() => this.updateAnchors(), 1000);
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

6. Add `src/anchor-cube.js` file:
```javascript
import React from 'react';
import { View, Line, Text } from 'magic-script-components';

const red = [1, 0, 0, 1];
const green = [0, 1, 0, 1];
const blue = [0, 0, 1, 1];
const vecStart = [0, 0, 0];
const length = 0.25;

// props:
// - id
// - uuid

export default function (props) {
  const uuid = props.uuid;
  const vecX = [vecStart, [length, 0, 0]];
  const vecY = [vecStart, [0, length, 0]];
  const vecZ = [vecStart, [0, 0, length]];

  return (
    <View anchorUuid={uuid}>
      <Line points={vecX} color={red} />
      <Line points={vecY} color={green} />
      <Line points={vecZ} color={blue} />
      <Text textSize={0.02} text={props.id} textColor={red}/>
    </View>
  );
}
```

7. Run `yarn` from the terminal (from main project folder)
```bash
yarn
```

8. Run `yarn` from the terminal again (from reactnative subfolder)
```bash
yarn
```

## iOS Instructions:

1. Save `MLXR.framework` from the XR SDK to a folder named `MLXR` under the project root

2. Run `pod install` from the terminal (ios folder)
```bash
pod install
```

3. Open XCode and open `ios/<ProjectName>.xcworkspace` file
    1. Add `MLXR.framework` to the project from `General / Libraries`
    2. Select team for signing form `Signing / Team`
    3. Add `path` to the `MLXR.Framework` to `Build Settings / Framework Search Paths` and `Header Search Paths`:
    ```
    "$(SRCROOT)/../../MLXR"
    ```
    4. Add the following to the end of the `Podfile` to add the `MLXR.Framework` path to RXNrClient:
    ```
    def append_header_search_path(target, path)
      target.build_configurations.each do |config|
          # Note that there's a space character after `$(inherited)`.
          config.build_settings["HEADER_SEARCH_PATHS"] ||= "$(inherited) "
          config.build_settings["HEADER_SEARCH_PATHS"] << path
      end
    end
    def append_framework_search_path(target, path)
      target.build_configurations.each do |config|
          # Note that there's a space character after `$(inherited)`.
          config.build_settings["FRAMEWORK_SEARCH_PATHS"] ||= "$(inherited) "
          config.build_settings["FRAMEWORK_SEARCH_PATHS"] << path
      end
    end
    post_install do |installer|
      installer.pods_project.targets.each do |target|
        if target.name == "RNXrClient"
          append_header_search_path(target, "$(PODS_ROOT)/../../../MLXR")
          append_framework_search_path(target, "$(PODS_ROOT)/../../../MLXR")
        end
      end
    end
    ```

4. Update `AppDelegate.h` file:
```objective-c
#import <React/RCTBridgeDelegate.h>
#import <UIKit/UIKit.h>
#import "RNAppAuthAuthorizationFlowManager.h"

@interface AppDelegate : UIResponder <UIApplicationDelegate, RCTBridgeDelegate, RNAppAuthAuthorizationFlowManager>

@property (nonatomic, strong) UIWindow *window;
@property (nonatomic, weak)id<RNAppAuthAuthorizationFlowManagerDelegate>authorizationFlowManagerDelegate;

@end
```

5. Add to `AppDelegate.m` file:
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

6. Build and run the project:
- from the terminal:
```bash
react-native run-ios --device
```

- or from XCode `build` & `run`

## Android Instructions:

1. Save `XRKit.aar` from the XR SDK to a folder named `MLXR` under the project root (it should be right next to `MLXR.framework` if also targetting iOS)

2. Update `MainActivity.java` to request required permissions:
```java
package com.magicscript.xrsample;

import android.Manifest;
import android.content.pm.PackageManager;
import android.os.Bundle;
import android.util.Log;
import android.widget.Toast;

import androidx.core.app.ActivityCompat;
import androidx.core.content.ContextCompat;

import com.facebook.react.ReactActivity;

import java.util.ArrayList;
import java.util.List;

public class MainActivity extends ReactActivity {

    private final int permissionRequestCode = 1;

    /**
     * Returns the name of the main component registered from JavaScript.
     * This is used to schedule rendering of the component.
     */
    @Override
    protected String getMainComponentName() {
        return "MagicScriptXRSample";
    }

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        permissionRequest();
    }

    private boolean permissionRequest() {
        List<String> permissions = new ArrayList<>();
        if (ContextCompat.checkSelfPermission(this, Manifest.permission.CAMERA) != PackageManager.PERMISSION_GRANTED) {
            if (!ActivityCompat.shouldShowRequestPermissionRationale(this, Manifest.permission.CAMERA)) {
                permissions.add(Manifest.permission.CAMERA);
            }
        }
        if (ContextCompat.checkSelfPermission(this, Manifest.permission.ACCESS_FINE_LOCATION) != PackageManager.PERMISSION_GRANTED) {
            if (!ActivityCompat.shouldShowRequestPermissionRationale(this, Manifest.permission.ACCESS_FINE_LOCATION)) {
                permissions.add(Manifest.permission.ACCESS_FINE_LOCATION);
            }
        }

        if (permissions.size() > 0) {
            ActivityCompat.requestPermissions(this,
                    permissions.toArray(new String[permissions.size()]),
                    permissionRequestCode);
        }
        return permissions.size() == 0;
    }

    @Override
    public void onRequestPermissionsResult(int requestCode, String[] permissions, int[] grantResults) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults);

        if (requestCode == permissionRequestCode) {
            if (grantResults.length == 0 || grantResults[0] != PackageManager.PERMISSION_GRANTED) {
                Log.e("RNXRClient", "fine location permission request denied");
                Toast.makeText(this, "Requires all permissions to use the app.", Toast.LENGTH_LONG).show();
            }
        }
    }
}
```

3. Add fine location permission to `AndroidManifest.xml`:
```xml
    <uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />
```

4. Increase max JVM memory by adding to `reactnative/android/gradle.properties`:
```
org.gradle.jvmargs=-Xmx1536m
```

5. Update top-level android/build.gradle:
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

6. Update android/app/build.gradle:
    1. Add auth config (under `android / defaultConfig`):
    ```groovy
    manifestPlaceholders = [
        appAuthRedirectScheme: 'magicscript'
    ]
    ```

    2. Update ABI types under `splits / abi` (ARKit.aar is only built for arb64-v8a at the moment):
    ```groovy
    include "arm64-v8a"
    ```

    3. Add dependencies:
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

    4. Add kotlin plugins:
    ```groovy
    apply plugin: 'kotlin-android'
    apply plugin: 'kotlin-android-extensions'
    ```

7. Build and run the project:
- from the terminal:
```bash
react-native run-android
```

- or from Android Studio `Run`
