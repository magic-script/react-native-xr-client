# Use `react-natrive-xr-client` in MagicScript Components project

1. Create project

```bash
react-native init <project name>
```

2. Update the `package.json`. Add the following dependencies:
```javascript
"react-native-xr-client": "0.0.5",
"react-native-app-auth": "^4.4.0",
"magic-script-components": "2.0.1",
"magic-script-components-react-native": "0.1.3"
```
3. add `.npmrc` file:
```bash
registry=https://nexus.magicleap.blue/repository/npm-group/
```

4. Remove `*.lock` files:
- yarn.lock
- ios/Podfile.lock

5. Edit the Podfile (from `ios` folder)
- Remove unnecessary targets
- Update the `platform :ios` to `12`
```python
platform :ios, '12.0'
```

6. Copy `proxy_mobile` folder to the project root folder 
7. Update `index.js` file: 
```javascript
import React from 'react';
import { MagicScript } from './proxy_mobile';
import MyApp from './App';

MagicScript.registerApp('<your project name>', <MyApp clientId='your.client.id.for.oauth'/>, false);
```

8. Update `App.js` file (demo code):
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

      this.setState({ scenes: scenes, anchorCount: pcfList.length });

      Object.values(scenes).forEach(scene => {
        XrClientBridge.createAnchor(scene.uuid, scene.pcfPose);
      });
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

9. Delete `app.json` file.

10. Save `MLXR.framework` to local folder

11. Run `yarn` from the terminal (main project folder)
```bash
yarn
```

12. Run `pod install` from the terminal (ios folder)
```bash
pod install
```

13. Open XCode and open `ios/<ProjectName>.xcworkspace` file
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

14. Add `XrApp.h` file to the project:
```objective-c
#import <React/RCTBridgeModule.h>

@interface XrApp : NSObject <RCTBridgeModule>

@end
```
15. Add `XrApp.m` file to the project:
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

16. Update `AppDelegate.h` file:
```objective-c
#import <React/RCTBridgeDelegate.h>
#import <UIKit/UIKit.h>
#import "RNAppAuthAuthorizationFlowManager.h"

@interface AppDelegate : UIResponder <UIApplicationDelegate, RCTBridgeDelegate, RNAppAuthAuthorizationFlowManager>

@property (nonatomic, strong) UIWindow *window;
@property (nonatomic, weak)id<RNAppAuthAuthorizationFlowManagerDelegate>authorizationFlowManagerDelegate;

@end
```

17. Add to `AppDelegate.m` file:
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

18. Build and run the project:
- from the terminal:
```bash
react-native run-ios --device
```

- or from XCode `build` & `run` 