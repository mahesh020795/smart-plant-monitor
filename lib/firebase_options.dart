// Auto-generated for project: smart-plant-monitor-fdddf
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart' show defaultTargetPlatform, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      default:
        throw UnsupportedError('Unsupported platform');
    }
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey:            'AIzaSyDAvG7zYVde6QPUiW2g4MUJwV4QnBVTF7s',
    appId:             '1:851386091751:android:f23275685f493fbe7b3a42',
    messagingSenderId: '851386091751',
    projectId:         'smart-plant-monitor-fdddf',
    databaseURL:       'https://smart-plant-monitor-fdddf-default-rtdb.firebaseio.com',
    storageBucket:     'smart-plant-monitor-fdddf.firebasestorage.app',
  );
}
