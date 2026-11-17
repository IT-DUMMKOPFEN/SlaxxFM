// Patches the platform folders created by `flutter create` so that SlaxxFM
// can reach the internet, plays http:// streams and shows its real name.
//
//   flutter create --org de.itdummkopfen --project-name slaxxfm \
//       --platforms=windows,linux,macos,android .
//   dart run tool/patch_platforms.dart
import 'dart:io';

void patch(String path, String Function(String) change) {
  final f = File(path);
  if (!f.existsSync()) return;
  final before = f.readAsStringSync();
  final after = change(before);
  if (after != before) {
    f.writeAsStringSync(after);
    stdout.writeln('patched $path');
  }
}

void main() {
  // ---------------------------------------------------------------- Android
  patch('android/app/src/main/AndroidManifest.xml', (s) {
    if (!s.contains('android.permission.INTERNET')) {
      s = s.replaceFirstMapped(
          RegExp(r'<manifest[^>]*>'),
          (m) => '${m[0]}\n'
              '    <uses-permission android:name="android.permission.INTERNET"/>\n'
              '    <uses-permission android:name="android.permission.WAKE_LOCK"/>');
    }
    if (!s.contains('usesCleartextTraffic')) {
      s = s.replaceFirst('<application',
          '<application\n        android:usesCleartextTraffic="true"');
    }
    s = s.replaceAll('android:label="slaxxfm"', 'android:label="SlaxxFM"');
    return s;
  });

  // ---------------------------------------------------------------- macOS
  for (final f in [
    'macos/Runner/DebugProfile.entitlements',
    'macos/Runner/Release.entitlements'
  ]) {
    patch(f, (s) {
      if (s.contains('com.apple.security.network.client')) return s;
      return s.replaceFirst(RegExp(r'</dict>\s*</plist>'),
          '\t<key>com.apple.security.network.client</key>\n\t<true/>\n</dict>\n</plist>');
    });
  }
  patch('macos/Runner/Configs/AppInfo.xcconfig',
      (s) => s.replaceAll('PRODUCT_NAME = slaxxfm', 'PRODUCT_NAME = SlaxxFM'));
  // allow http:// station logos and streams
  patch('macos/Runner/Info.plist', (s) {
    if (s.contains('NSAppTransportSecurity')) return s;
    return s.replaceFirst(RegExp(r'</dict>\s*</plist>'),
        '\t<key>NSAppTransportSecurity</key>\n\t<dict>\n\t\t<key>NSAllowsArbitraryLoads</key>\n\t\t<true/>\n\t</dict>\n</dict>\n</plist>');
  });

  // ---------------------------------------------------------------- Windows
  patch('windows/runner/main.cpp', (s) {
    s = s.replaceAll('L"slaxxfm"', 'L"SlaxxFM"');
    s = s.replaceAll('Win32Window::Size size(1280, 720);',
        'Win32Window::Size size(1360, 860);');
    return s;
  });
  patch('windows/runner/Runner.rc', (s) {
    return s
        .replaceAll('"FileDescription", "slaxxfm"', '"FileDescription", "SlaxxFM"')
        .replaceAll('"ProductName", "slaxxfm"', '"ProductName", "SlaxxFM"');
  });

  // ---------------------------------------------------------------- Linux
  patch('linux/runner/my_application.cc', (s) {
    s = s.replaceAll('"slaxxfm"', '"SlaxxFM"');
    s = s.replaceAll('gtk_window_set_default_size(window, 1280, 720);',
        'gtk_window_set_default_size(window, 1360, 860);');
    return s;
  });
  // older templates keep the runner in linux/my_application.cc
  patch('linux/my_application.cc', (s) {
    s = s.replaceAll('"slaxxfm"', '"SlaxxFM"');
    s = s.replaceAll('gtk_window_set_default_size(window, 1280, 720);',
        'gtk_window_set_default_size(window, 1360, 860);');
    return s;
  });
}
