
# React Native XR Client

React Native XR SDK Client Library

## Getting started
1. Add the package as dependency
```bash
$ npm install react-native-xr-client --save
```
2. Go to `ios` folder
```bash
$ cd ios
```
3. Install the `RNXrClient` pod
```
pod install
```

### iOS
1. Open the workspace from XCode
2. Find the `RNXrClient` under Pods/Development Pods
3. Add to `RNXrClient.xcconfig` file:
```
FRAMEWORK_SEARCH_PATHS = $(inherited) "the/path/to/MLXRSDK"
HEADER_SEARCH_PATHS = <existing paths> "the/path/to/MLXRSDK"
```

## Usage
```javascript
import { NativeModules } from 'react-native';
const { XrClientBridge } = NativeModules;

// XrClientBridge API
// - connect(token)
// - getAllPCFs()
// - getLocalizationSatus()
// - createAnchor(id, transform)
// - removeAnchor(id)
// - removeAllAnchors()
// - setUpdateInterval(interval)
```
