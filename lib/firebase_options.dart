import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

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
        return windows;
      case TargetPlatform.linux:
        return linux;
      default:
        return web;
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyCiRo28W-YDc4D-2QeaBSppzcDbp2EM2T0',
    appId: '1:581188305633:web:4949458e6e4c123c3bada0',
    messagingSenderId: '581188305633',
    projectId: 'cinegestor-manutencao',
    authDomain: 'cinegestor-manutencao.firebaseapp.com',
    storageBucket: 'cinegestor-manutencao.firebasestorage.app',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyCiRo28W-YDc4D-2QeaBSppzcDbp2EM2T0',
    appId: '1:581188305633:web:4949458e6e4c123c3bada0',
    messagingSenderId: '581188305633',
    projectId: 'cinegestor-manutencao',
    storageBucket: 'cinegestor-manutencao.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyCiRo28W-YDc4D-2QeaBSppzcDbp2EM2T0',
    appId: '1:581188305633:web:4949458e6e4c123c3bada0',
    messagingSenderId: '581188305633',
    projectId: 'cinegestor-manutencao',
    storageBucket: 'cinegestor-manutencao.firebasestorage.app',
    iosBundleId: 'com.example.cinegestor',
  );

  static const FirebaseOptions macos = FirebaseOptions(
    apiKey: 'AIzaSyCiRo28W-YDc4D-2QeaBSppzcDbp2EM2T0',
    appId: '1:581188305633:web:4949458e6e4c123c3bada0',
    messagingSenderId: '581188305633',
    projectId: 'cinegestor-manutencao',
    storageBucket: 'cinegestor-manutencao.firebasestorage.app',
    iosBundleId: 'com.example.cinegestor',
  );

  static const FirebaseOptions windows = FirebaseOptions(
    apiKey: 'AIzaSyCiRo28W-YDc4D-2QeaBSppzcDbp2EM2T0',
    appId: '1:581188305633:web:4949458e6e4c123c3bada0',
    messagingSenderId: '581188305633',
    projectId: 'cinegestor-manutencao',
    authDomain: 'cinegestor-manutencao.firebaseapp.com',
    storageBucket: 'cinegestor-manutencao.firebasestorage.app',
  );

  static const FirebaseOptions linux = FirebaseOptions(
    apiKey: 'AIzaSyCiRo28W-YDc4D-2QeaBSppzcDbp2EM2T0',
    appId: '1:581188305633:web:4949458e6e4c123c3bada0',
    messagingSenderId: '581188305633',
    projectId: 'cinegestor-manutencao',
    authDomain: 'cinegestor-manutencao.firebaseapp.com',
    storageBucket: 'cinegestor-manutencao.firebasestorage.app',
  );
}
