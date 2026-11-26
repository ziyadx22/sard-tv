import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';

const _navy = Color(0xFF070B14);
const _cyan = Color(0xFF00F0FF);

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MysardTvApp());
}

class MysardTvApp extends StatelessWidget {
  const MysardTvApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'MySard',
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: _navy,
        colorScheme: const ColorScheme.dark(
          primary: _cyan,
          surface: Color(0xFF10182A),
        ),
        fontFamily: 'Segoe UI',
      ),
      home: const Directionality(
        textDirection: TextDirection.rtl,
        child: PairingScreen(),
      ),
    );
  }
}

class PairingScreen extends StatefulWidget {
  const PairingScreen({super.key});

  @override
  State<PairingScreen> createState() => _PairingScreenState();
}

class _PairingScreenState extends State<PairingScreen> with SingleTickerProviderStateMixin {
  static const _method = MethodChannel('com.mysard.tv/control');
  static const _events = EventChannel('com.mysard.tv/events');

  late final AnimationController _pulse;
  StreamSubscription<dynamic>? _sub;
  String _ip = '...';
  int _port = 8765;
  String _pin = '----';
  int _clients = 0;
  bool _overlay = false;
  bool _running = false;
  String? _lastLine;
  String? _notice;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400))
      ..repeat(reverse: true);
    _boot();
  }

  Future<void> _boot() async {
    _sub = _events.receiveBroadcastStream().listen(_onEvent, onError: (_) {});
    try {
      final status = await _method.invokeMapMethod<String, dynamic>('start');
      if (status != null) _applyStatus(status);
      final allowed = await _method.invokeMethod<bool>('canDrawOverlays');
      if (mounted) setState(() => _overlay = allowed ?? false);
    } catch (error) {
      if (mounted) setState(() => _notice = 'تعذر تشغيل خدمة الاقتران');
    }
    unawaited(_offerUpdate());
  }

  void _onEvent(dynamic event) {
    if (event is! Map) return;
    final map = Map<String, dynamic>.from(event);
    switch (map['type']) {
      case 'status':
        _applyStatus(map);
      case 'subtitle':
        setState(() => _lastLine = map['text']?.toString());
      case 'overlay_denied':
        setState(() {
          _overlay = false;
          _notice = 'فعّل الظهور فوق التطبيقات ليطفو النص على منفذ البلايستيشن';
        });
    }
  }

  void _applyStatus(Map<dynamic, dynamic> map) {
    setState(() {
      _ip = map['ip']?.toString() ?? _ip;
      _port = (map['port'] as num?)?.toInt() ?? _port;
      _pin = map['pin']?.toString() ?? _pin;
      _clients = (map['clients'] as num?)?.toInt() ?? _clients;
      _running = map['running'] == true || _pin != '----';
      if (map.containsKey('overlay')) _overlay = map['overlay'] == true;
    });
  }

  String get _payload => 'mysard://$_ip:$_port?pin=$_pin';

  Future<void> _requestOverlay() async {
    await _method.invokeMethod('requestOverlayPermission');
  }

  Future<void> _offerUpdate() async {
    const repo = String.fromEnvironment('GITHUB_REPOSITORY');
    const build = int.fromEnvironment('APP_BUILD', defaultValue: 0);
    if (repo.isEmpty || build <= 0) return;
    final client = HttpClient();
    try {
      final request = await client.getUrl(Uri.parse('https://api.github.com/repos/$repo/releases/latest'));
      request.headers.set(HttpHeaders.userAgentHeader, 'MySardTV');
      request.headers.set(HttpHeaders.acceptHeader, 'application/vnd.github+json');
      final response = await request.close();
      if (response.statusCode != 200) return;
      final body = jsonDecode(await response.transform(utf8.decoder).join()) as Map<String, dynamic>;
      final remote = int.tryParse('${body['tag_name']}'.replaceFirst(RegExp(r'^v'), '')) ?? 0;
      if (remote <= build || !mounted) return;
      final assets = (body['assets'] as List?) ?? const [];
      String? url;
      for (final asset in assets) {
        if (asset is Map && '${asset['name']}'.endsWith('.apk')) {
          url = asset['browser_download_url']?.toString();
          break;
        }
      }
      if (url == null) return;
      final install = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: const Color(0xFF10182A),
          title: const Text('تحديث MySard'),
          content: Text('الإصدار v$remote جاهز على GitHub Releases. تثبيته يحدّث التطبيق مباشرة.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('لاحقاً')),
            FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('تحديث الآن')),
          ],
        ),
      );
      if (install != true) return;
      final download = await client.getUrl(Uri.parse(url));
      download.headers.set(HttpHeaders.userAgentHeader, 'MySardTV');
      final fileResponse = await download.close();
      final dir = await _method.invokeMethod<String>('cacheDir');
      if (dir == null) return;
      final file = File('$dir/mysard-update.apk');
      await fileResponse.pipe(file.openWrite());
      await _method.invokeMethod('installApk', {'path': file.path});
    } catch (_) {
    } finally {
      client.close(force: true);
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final connected = _clients > 0;
    return Scaffold(
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(-0.7, -0.8),
            radius: 1.3,
            colors: [Color(0xFF12324A), _navy],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(36),
            child: Row(
              children: [
                Expanded(child: _intro(connected)),
                const SizedBox(width: 28),
                _qrCard(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _intro(bool connected) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'MY SARD',
          style: TextStyle(
            color: _cyan,
            letterSpacing: 8,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'ترجمة عربية مباشرة',
          style: TextStyle(fontSize: 42, fontWeight: FontWeight.w700, height: 1.15),
        ),
        const SizedBox(height: 10),
        const Text(
          'طبقة زجاجية فوق صورة بلايستيشن ٥ عبر منفذ HDMI',
          style: TextStyle(color: Colors.white70, fontSize: 18),
        ),
        const Spacer(),
        _statusBadge(connected),
        if (_lastLine != null) ...[
          const SizedBox(height: 18),
          _glass(
            child: Text(
              _lastLine!,
              style: const TextStyle(fontSize: 22, height: 1.4),
            ),
          ),
        ],
        if (!_overlay) ...[
          const SizedBox(height: 18),
          Focus(
            autofocus: true,
            child: FilledButton(
              onPressed: _requestOverlay,
              style: FilledButton.styleFrom(
                backgroundColor: _cyan,
                foregroundColor: _navy,
                padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
              ),
              child: const Text('تفعيل الطبقة فوق HDMI'),
            ),
          ),
        ],
        if (_notice != null) ...[
          const SizedBox(height: 12),
          Text(_notice!, style: const TextStyle(color: Color(0xFFFFC857))),
        ],
        const Spacer(),
        Text(
          _running ? 'الخدمة تعمل على الشبكة المحلية' : 'يجري تجهيز الاقتران',
          style: const TextStyle(color: Colors.white38),
        ),
      ],
    );
  }

  Widget _statusBadge(bool connected) {
    final color = connected ? const Color(0xFF39FFB6) : _cyan;
    final label = connected ? 'متصل' : 'في انتظار الآيفون';
    return AnimatedBuilder(
      animation: _pulse,
      builder: (context, _) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: color.withValues(alpha: 0.7)),
            color: color.withValues(alpha: 0.08 + (_pulse.value * 0.08)),
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: 0.25 * _pulse.value),
                blurRadius: 18,
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
              const SizedBox(width: 10),
              Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w700)),
            ],
          ),
        );
      },
    );
  }

  Widget _qrCard() {
    final ready = _ip != '...' && _ip != '0.0.0.0' && _pin != '----';
    return _glass(
      width: 420,
      padding: const EdgeInsets.all(28),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text('امسح الرمز من تطبيق الآيفون', style: TextStyle(fontSize: 18)),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(color: _cyan.withValues(alpha: 0.55), blurRadius: 32, spreadRadius: 2),
              ],
            ),
            child: ready
                ? QrImageView(
                    data: _payload,
                    size: 230,
                    backgroundColor: Colors.white,
                    eyeStyle: const QrEyeStyle(eyeShape: QrEyeShape.square, color: Color(0xFF041018)),
                    dataModuleStyle: const QrDataModuleStyle(
                      dataModuleShape: QrDataModuleShape.square,
                      color: Color(0xFF041018),
                    ),
                  )
                : const SizedBox(
                    width: 230,
                    height: 230,
                    child: Center(child: CircularProgressIndicator(color: _navy)),
                  ),
          ),
          const SizedBox(height: 22),
          _fallback(label: 'عنوان الشبكة', value: ready ? '$_ip:$_port' : '—'),
          const SizedBox(height: 10),
          _fallback(label: 'رمز الاقتران', value: _pin),
        ],
      ),
    );
  }

  Widget _fallback({required String label, required String value}) {
    return Row(
      children: [
        Expanded(child: Text(label, style: const TextStyle(color: Colors.white60))),
        Directionality(
          textDirection: TextDirection.ltr,
          child: Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: _cyan)),
        ),
      ],
    );
  }

  Widget _glass({required Widget child, double? width, EdgeInsetsGeometry? padding}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          width: width,
          padding: padding ?? const EdgeInsets.all(20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(28),
            color: Colors.white.withValues(alpha: 0.06),
            border: Border.all(color: _cyan.withValues(alpha: 0.35)),
          ),
          child: child,
        ),
      ),
    );
  }
}
