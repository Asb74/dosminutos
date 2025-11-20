import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart' show defaultTargetPlatform, kIsWeb, TargetPlatform;

/// Placeholder Firebase configuration used to allow the application to compile
/// even when the real configuration files have not been generated yet.
///
/// Replace the values in this file with the configuration obtained from the
/// Firebase console or run `flutterfire configure` to generate the production
/// values automatically.
class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }

    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      case TargetPlatform.macOS:
        return macos;
      case TargetPlatform.windows:
      case TargetPlatform.linux:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for this platform.',
        );
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyCEUPBbbohnEXotG-Mkphi-_2QSKmdVt1U',
    appId: '1:786834128452:web:fa8476370cf1045e998611',
    messagingSenderId: '786834128452',
    projectId: 'minutos-5d44f',
    authDomain: 'minutos-5d44f.firebaseapp.com',
    storageBucket: 'minutos-5d44f.firebasestorage.app',
    measurementId: 'G-ZE3PFG1V99',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyCqY0Buwfbi7JbVjlLT2dfgd3TltELcd_g',
    appId: '1:786834128452:android:30d31808c68e0e47998611',
    messagingSenderId: '786834128452',
    projectId: 'minutos-5d44f',
    storageBucket: 'minutos-5d44f.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyBiBIShxcw0wCczafXkSYBq3sHxP8VZlPE',
    appId: '1:786834128452:ios:11e1a8542e5a9d0e998611',
    messagingSenderId: '786834128452',
    projectId: 'minutos-5d44f',
    storageBucket: 'minutos-5d44f.firebasestorage.app',
    iosBundleId: 'com.asb.dosminutos',
  );

  static const FirebaseOptions macos = FirebaseOptions(
    apiKey: 'AIzaSyBiBIShxcw0wCczafXkSYBq3sHxP8VZlPE',
    appId: '1:786834128452:ios:11e1a8542e5a9d0e998611',
    messagingSenderId: '786834128452',
    projectId: 'minutos-5d44f',
    storageBucket: 'minutos-5d44f.firebasestorage.app',
    iosBundleId: 'com.asb.dosminutos',
  );

}