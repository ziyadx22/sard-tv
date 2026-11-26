import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import 'gaming_glossary.dart';

const _navy = Color(0xFF070B14);
const _panel = Color(0xFF10182A);

class MysardIosApp extends StatefulWidget {
  const MysardIosApp({super.key});

  @override
  State<MysardIosApp> createState() => _MysardIosAppState();
}

class _MysardIosAppState extends State<MysardIosApp> with SingleTickerProviderStateMixin {
  final _speech = SpeechToText();
  final _text = TextEditingController();
  final _host = TextEditingController();
  final _port = TextEditingController(text: '8765');
  final _pin = TextEditingController();
  late final AnimationController _pulse;

  WebSocketChannel? _socket;
  StreamSubscription<dynamic>? _socketSub;
  Timer? _retry;
  Timer? _typing;
  int _delaySeconds = 1;
  bool _userClosed = false;
  bool _connected = false;
  bool _listening = false;
  String _preview = '';
  String? _banner;
  double _fontSize = 32;
  double _vertical = 0.78;
  double _opacity = 0.62;
  double _hue = 185;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(vsync: this, duration: const Duration(milliseconds: 1100))
      ..repeat(reverse: true);
  }

  Color get _neon => HSVColor.fromAHSV(1, _hue, 0.85, 1).toColor();

  String get _neonHex {
    final argb = _neon.toARGB32() & 0xFFFFFF;
    return '#${argb.toRadixString(16).padLeft(6, '0').toUpperCase()}';
  }

  Map<String, dynamic> get _style => {
        'fontSize': _fontSize,
        'opacity': _opacity,
        'color': _neonHex,
        'y': _vertical,
      };

  Future<void> _scan() async {
    final raw = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => const _ScannerPage()),
    );
    if (raw == null) return;
    final target = _parseTarget(raw);
    if (target == null) {
      setState(() => _banner = 'الرمز لا يحتوي بيانات اقتران MySard');
      return;
    }
    _host.text = target.host;
    _port.text = '${target.port}';
    _pin.text = target.pin;
    await _connect(manual: true);
  }

  _Target? _parseTarget(String raw) {
    final uri = Uri.tryParse(raw.trim());
    if (uri == null || uri.host.isEmpty) return null;
    final pin = uri.queryParameters['pin'];
    if (pin == null || pin.isEmpty) return null;
    return _Target(uri.host, uri.hasPort ? uri.port : 8765, pin);
  }

  Future<void> _connect({bool manual = false}) async {
    final host = _host.text.trim();
    final port = int.tryParse(_port.text.trim());
    final pin = _pin.text.trim();
    if (host.isEmpty || port == null || pin.length < 4) {
      setState(() => _banner = 'أدخل العنوان والمنفذ ورمز الاقتران');
      return;
    }
    _userClosed = false;
    _delaySeconds = 1;
    _retry?.cancel();
    await _open(host, port, pin);
    if (manual) setState(() => _banner = null);
  }

  Future<void> _open(String host, int port, String pin) async {
    await _socketSub?.cancel();
    _socket?.sink.close();
    try {
      final socket = WebSocketChannel.connect(Uri.parse('ws://$host:$port'));
      _socket = socket;
      _socketSub = socket.stream.listen((event) {
        final message = jsonDecode('$event');
        if (message is! Map) return;
        if (message['type'] == 'auth_ok') {
          _delaySeconds = 1;
          if (mounted) setState(() {
            _connected = true;
            _banner = null;
          });
          _sendStyle();
        } else if (message['type'] == 'auth_fail') {
          _userClosed = true;
          if (mounted) setState(() {
            _connected = false;
            _banner = 'رمز الاقتران غير صحيح';
          });
        }
      }, onError: (_) => _scheduleRetry(host, port, pin), onDone: () => _scheduleRetry(host, port, pin));
      socket.sink.add(jsonEncode({'type': 'auth', 'pin': pin}));
    } catch (_) {
      _scheduleRetry(host, port, pin);
    }
  }

  void _scheduleRetry(String host, int port, String pin) {
    if (_userClosed) return;
    if (mounted) setState(() => _connected = false);
    _retry?.cancel();
    final wait = _delaySeconds;
    _delaySeconds = min(_delaySeconds * 2, 12);
    _retry = Timer(Duration(seconds: wait), () {
      if (!_userClosed) _open(host, port, pin);
    });
  }

  void _disconnect() {
    _userClosed = true;
    _retry?.cancel();
    _socketSub?.cancel();
    _socket?.sink.close();
    _socket = null;
    setState(() => _connected = false);
  }

  void _send(Map<String, dynamic> payload) {
    if (!_connected || _socket == null) return;
    _socket!.sink.add(jsonEncode(payload));
  }

  void _sendSubtitle(String arabic) {
    if (arabic.trim().isEmpty) return;
    _send({'type': 'subtitle', 'text': arabic, ..._style});
  }

  void _sendStyle() => _send({'type': 'style', ..._style});

  void _onDraft(String value) {
    final arabic = GamingGlossary.translate(value);
    setState(() => _preview = arabic);
    _typing?.cancel();
    _typing = Timer(const Duration(milliseconds: 280), () => _sendSubtitle(arabic));
  }

  Future<void> _toggleMic() async {
    if (_listening) {
      await _speech.stop();
      if (mounted) setState(() => _listening = false);
      return;
    }
    final ready = await _speech.initialize(
      onError: (_) {
        if (mounted) setState(() {
          _listening = false;
          _banner = 'تعذر التعرف على الصوت. اكتب الجملة وسيتم إرسالها فوراً.';
        });
      },
      onStatus: (status) {
        if ((status == 'done' || status == 'notListening') && mounted) {
          setState(() => _listening = false);
        }
      },
    );
    if (!ready) {
      setState(() => _banner = 'الميكروفون غير متاح. استخدم حقل الكتابة.');
      return;
    }
    var localeId = 'en_US';
    final locales = await _speech.locales();
    if (!locales.any((locale) => locale.localeId.toLowerCase().startsWith('en'))) {
      if (locales.isNotEmpty) localeId = locales.first.localeId;
    }
    if (!mounted) return;
    setState(() => _listening = true);
    await _speech.listen(
      onResult: (result) {
        final arabic = GamingGlossary.translate(result.recognizedWords);
        if (!mounted) return;
        setState(() => _preview = arabic);
        if (result.finalResult) _sendSubtitle(arabic);
      },
      listenOptions: SpeechListenOptions(
        localeId: localeId,
        partialResults: true,
        listenMode: ListenMode.dictation,
        pauseFor: const Duration(seconds: 3),
        listenFor: const Duration(seconds: 30),
      ),
    );
  }

  @override
  void dispose() {
    _userClosed = true;
    _retry?.cancel();
    _typing?.cancel();
    _socketSub?.cancel();
    _socket?.sink.close();
    _text.dispose();
    _host.dispose();
    _port.dispose();
    _pin.dispose();
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'MySard',
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: _navy,
        colorScheme: ColorScheme.dark(primary: _neon, surface: _panel),
        sliderTheme: SliderThemeData(
          activeTrackColor: _neon,
          thumbColor: _neon,
          inactiveTrackColor: Colors.white24,
        ),
      ),
      builder: (context, child) => Directionality(
        textDirection: TextDirection.rtl,
        child: child ?? const SizedBox.shrink(),
      ),
      home: Scaffold(
        body: DecoratedBox(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: const Alignment(0.8, -0.9),
              radius: 1.2,
              colors: [_neon.withValues(alpha: 0.18), _navy],
            ),
          ),
          child: SafeArea(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 32),
              children: [
                const Text('MY SARD', style: TextStyle(letterSpacing: 6, fontSize: 12, color: Colors.white60)),
                const SizedBox(height: 6),
                const Text('تحكم الترجمة', style: TextStyle(fontSize: 32, fontWeight: FontWeight.w700)),
                const SizedBox(height: 14),
                _status(),
                const SizedBox(height: 16),
                _pairCard(),
                const SizedBox(height: 16),
                _mic(),
                const SizedBox(height: 16),
                _composer(),
                const SizedBox(height: 16),
                _previewCard(),
                const SizedBox(height: 16),
                _sliders(),
                if (_banner != null) ...[
                  const SizedBox(height: 14),
                  Text(_banner!, style: const TextStyle(color: Color(0xFFFFC857))),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _status() {
    final color = _connected ? const Color(0xFF39FFB6) : Colors.white60;
    return Align(
      alignment: Alignment.centerRight,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: color.withValues(alpha: 0.7)),
        ),
        child: Text(_connected ? 'متصل بالتلفاز' : 'غير متصل', style: TextStyle(color: color)),
      ),
    );
  }

  Widget _pairCard() {
    return _glass(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          FilledButton.icon(
            onPressed: _scan,
            icon: const Icon(Icons.qr_code_scanner),
            label: const Text('مسح رمز الاقتران'),
            style: FilledButton.styleFrom(
              backgroundColor: _neon,
              foregroundColor: _navy,
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
          ),
          const SizedBox(height: 14),
          Directionality(
            textDirection: TextDirection.ltr,
            child: Column(
              children: [
                TextField(
                  controller: _host,
                  decoration: const InputDecoration(labelText: 'IP'),
                  keyboardType: TextInputType.number,
                ),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _port,
                        decoration: const InputDecoration(labelText: 'Port'),
                        keyboardType: TextInputType.number,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: _pin,
                        decoration: const InputDecoration(labelText: 'PIN'),
                        keyboardType: TextInputType.number,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => _connect(manual: true),
                  child: const Text('اتصال'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextButton(onPressed: _disconnect, child: const Text('قطع')),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _mic() {
    return Center(
      child: AnimatedBuilder(
        animation: _pulse,
        builder: (context, _) {
          final scale = _listening ? 1 + (_pulse.value * 0.08) : 1.0;
          return Transform.scale(
            scale: scale,
            child: GestureDetector(
              onTap: _toggleMic,
              child: Container(
                width: 148,
                height: 148,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _neon.withValues(alpha: _listening ? 0.22 : 0.1),
                  border: Border.all(color: _neon, width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: _neon.withValues(alpha: _listening ? 0.55 : 0.2),
                      blurRadius: _listening ? 28 + (18 * _pulse.value) : 12,
                      spreadRadius: _listening ? 2 : 0,
                    ),
                  ],
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(_listening ? Icons.graphic_eq : Icons.mic, color: _neon, size: 42),
                    const SizedBox(height: 6),
                    const Text('ترجمة صوتية', style: TextStyle(fontWeight: FontWeight.w700)),
                    Text(
                      _listening ? 'مباشر' : 'اضغط للتحدث',
                      style: const TextStyle(color: Colors.white60, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _composer() {
    return _glass(
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: TextField(
          controller: _text,
          minLines: 1,
          maxLines: 3,
          onChanged: _onDraft,
          onSubmitted: (value) => _sendSubtitle(GamingGlossary.translate(value)),
          decoration: const InputDecoration(
            hintText: 'Quest, checkpoint, boss, inventory…',
            border: InputBorder.none,
          ),
        ),
      ),
    );
  }

  Widget _previewCard() {
    return _glass(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('معاينة عربية', style: TextStyle(color: Colors.white60)),
          const SizedBox(height: 8),
          Text(
            _preview.isEmpty ? 'ستظهر الترجمة هنا قبل إرسالها إلى الشاشة' : _preview,
            textDirection: TextDirection.rtl,
            style: TextStyle(fontSize: _fontSize.clamp(16, 40), height: 1.45),
          ),
        ],
      ),
    );
  }

  Widget _sliders() {
    return _glass(
      child: Column(
        children: [
          _slider('حجم الخط', _fontSize, 18, 64, (value) {
            setState(() => _fontSize = value);
            _sendStyle();
          }),
          _slider('الموضع العمودي', _vertical, 0.08, 0.9, (value) {
            setState(() => _vertical = value);
            _sendStyle();
          }),
          _slider('شفافية الزجاج', _opacity, 0.25, 0.9, (value) {
            setState(() => _opacity = value);
            _sendStyle();
          }),
          _slider('لون النيون', _hue, 0, 320, (value) {
            setState(() => _hue = value);
            _sendStyle();
          }),
        ],
      ),
    );
  }

  Widget _slider(String label, double value, double min, double max, ValueChanged<double> onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label),
        Slider(value: value, min: min, max: max, onChanged: onChanged),
      ],
    );
  }

  Widget _glass({required Widget child}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: _neon.withValues(alpha: 0.4)),
          ),
          child: child,
        ),
      ),
    );
  }
}

class _Target {
  const _Target(this.host, this.port, this.pin);
  final String host;
  final int port;
  final String pin;
}

class _ScannerPage extends StatefulWidget {
  const _ScannerPage();

  @override
  State<_ScannerPage> createState() => _ScannerPageState();
}

class _ScannerPageState extends State<_ScannerPage> {
  var _handled = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _navy,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: const Text('مسح الرمز'),
      ),
      body: MobileScanner(
        onDetect: (capture) {
          if (_handled) return;
          final raw = capture.barcodes.cast<Barcode?>().firstWhere(
                (code) => code?.rawValue?.isNotEmpty == true,
                orElse: () => null,
              )?.rawValue;
          if (raw == null) return;
          _handled = true;
          Navigator.of(context).pop(raw);
        },
      ),
    );
  }
}
