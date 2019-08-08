
# React Native XR Client

React Native XR SDK Client Library

## Getting started

`$ npm install react-native-xr-client --save`

### Mostly automatic installation

`$ react-native link react-native-xr-client`

### Manual installation


#### iOS

1. In XCode, in the project navigator, right click `Libraries` ➜ `Add Files to [your project's name]`
2. Go to `node_modules` ➜ `react-native-xr-client` and add `RNXrClient.xcodeproj`
3. In XCode, in the project navigator, select your project. Add `libRNXrClient.a` to your project's `Build Phases` ➜ `Link Binary With Libraries`
4. Run your project (`Cmd+R`)<

## Usage
```javascript
import RNXrClient from 'react-native-xr-client';

// TODO: What to do with the module?
RNXrClient;
```

## Cleanup and rebuild the library
```sh
rm -rf node_modules && yarn cache clean && yarn
react-native start --reset-cache
```
Run in Xcode
