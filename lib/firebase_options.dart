import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

/// Configuración de Firebase para cada plataforma.
/// Generado con `flutterfire configure` y adaptado para que
/// Windows (y Linux) puedan usar la misma config que Android en desarrollo.
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

      /// 👇 Aquí es donde antes lanzaba UnsupportedError.
      /// Para desarrollo usamos la config de Android también en Windows y Linux.
      case TargetPlatform.windows:
        return android;
      case TargetPlatform.linux:
        return android;

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
