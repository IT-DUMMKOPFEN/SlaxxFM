// Patches the platform folders created by `flutter create` so that SlaxxFM
// can reach the internet, plays http:// streams, keeps playing in the
// background on Android, works with Android Auto and shows its real name.
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

void copy(String from, String to) {
  final t = File(to);
  t.parent.createSync(recursive: true);
  File(from).copySync(to);
  stdout.writeln('copied $to');
}

const _permissions = '''
    <uses-permission android:name="android.permission.INTERNET"/>
    <uses-permission android:name="android.permission.ACCESS_NETWORK_STATE"/>
    <uses-permission android:name="android.permission.WAKE_LOCK"/>
    <uses-permission android:name="android.permission.FOREGROUND_SERVICE"/>
    <uses-permission android:name="android.permission.FOREGROUND_SERVICE_MEDIA_PLAYBACK"/>
    <uses-permission android:name="android.permission.POST_NOTIFICATIONS"/>''';

const _services = '''
        <!-- background playback (audio_service) + Android Auto media browser -->
        <service
            android:name="com.ryanheise.audioservice.AudioService"
            android:foregroundServiceType="mediaPlayback"
            android:exported="true">
            <intent-filter>
                <action android:name="android.media.browse.MediaBrowserService" />
            </intent-filter>
        </service>
        <receiver
            android:name="com.ryanheise.audioservice.MediaButtonReceiver"
            android:exported="true">
            <intent-filter>
                <action android:name="android.intent.action.MEDIA_BUTTON" />
            </intent-filter>
        </receiver>
        <meta-data
            android:name="com.google.android.gms.car.application"
            android:resource="@xml/automotive_app_desc" />
''';

String mainActivity(String pkg) => '''
package $pkg

import android.content.Context
import android.net.wifi.WifiManager
import android.os.PowerManager
import com.ryanheise.audioservice.AudioServiceActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : AudioServiceActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "slaxxfm/locks")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "acquire" -> { PlaybackLocks.acquire(applicationContext); result.success(null) }
                    "release" -> { PlaybackLocks.release(); result.success(null) }
                    else -> result.notImplemented()
                }
            }
    }
}

/** Keeps CPU and Wi-Fi awake while a stream is playing (screen off). */
object PlaybackLocks {
    private var wake: PowerManager.WakeLock? = null
    private var wifi: WifiManager.WifiLock? = null

    @Suppress("DEPRECATION")
    fun acquire(ctx: Context) {
        if (wake == null) {
            val pm = ctx.getSystemService(Context.POWER_SERVICE) as PowerManager
            wake = pm.newWakeLock(PowerManager.PARTIAL_WAKE_LOCK, "SlaxxFM::playback")
                .apply { setReferenceCounted(false) }
        }
        if (wifi == null) {
            val wm = ctx.getSystemService(Context.WIFI_SERVICE) as WifiManager
            wifi = wm.createWifiLock(WifiManager.WIFI_MODE_FULL_HIGH_PERF, "SlaxxFM::wifi")
                .apply { setReferenceCounted(false) }
        }
        if (wake?.isHeld != true) wake?.acquire(12 * 60 * 60 * 1000L)
        if (wifi?.isHeld != true) wifi?.acquire()
    }

    fun release() {
        if (wake?.isHeld == true) wake?.release()
        if (wifi?.isHeld == true) wifi?.release()
    }
}
''';

void main() {
  // ---------------------------------------------------------------- Android
  patch('android/app/src/main/AndroidManifest.xml', (s) {
    if (!s.contains('android.permission.INTERNET')) {
      s = s.replaceFirstMapped(
          RegExp(r'<manifest[^>]*>'), (m) => '${m[0]}\n$_permissions');
    }
    if (!s.contains('usesCleartextTraffic')) {
      s = s.replaceFirst('<application',
          '<application\n        android:usesCleartextTraffic="true"');
    }
    s = s.replaceAll('android:label="slaxxfm"', 'android:label="SlaxxFM"');
    if (!s.contains('com.ryanheise.audioservice.AudioService')) {
      final i = s.lastIndexOf('</application>');
      s = '${s.substring(0, i)}$_services    ${s.substring(i)}';
    }
    return s;
  });

  if (Directory('android/app/src/main/res').existsSync()) {
    copy('assets/android/automotive_app_desc.xml',
        'android/app/src/main/res/xml/automotive_app_desc.xml');
    copy('assets/android/ic_stat_radio.png',
        'android/app/src/main/res/drawable-xxxhdpi/ic_stat_radio.png');
  }

  final kotlinDir = Directory('android/app/src/main/kotlin');
  if (kotlinDir.existsSync()) {
    for (final f in kotlinDir.listSync(recursive: true)) {
      if (f is! File || !f.path.endsWith('MainActivity.kt')) continue;
      final pkg = RegExp(r'^package\s+([\w.]+)', multiLine: true)
              .firstMatch(f.readAsStringSync())
              ?.group(1) ??
          'de.itdummkopfen.slaxxfm';
      f.writeAsStringSync(mainActivity(pkg));
      stdout.writeln('patched ${f.path}');
    }
  }

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
  for (final path in [
    'linux/runner/my_application.cc',
    'linux/my_application.cc', // older templates
  ]) {
    patch(path, (s) {
      s = s.replaceAll('"slaxxfm"', '"SlaxxFM"');
      s = s.replaceAll('gtk_window_set_default_size(window, 1280, 720);',
          'gtk_window_set_default_size(window, 1360, 860);');
      return s;
    });
  }
}
