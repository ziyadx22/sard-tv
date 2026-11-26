import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:translator/translator.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

void main() => runApp(const MySardIOSApp());

class MySardIOSApp extends StatelessWidget {
  const MySardIOSApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(scaffoldBackgroundColor: const Color(0xFF0A1628)),
      home: const RemoteHomeScreen(),
    );
  }
}

class RemoteHomeScreen extends StatefulWidget {
  const RemoteHomeScreen({super.key});
  @override
  State<RemoteHomeScreen> createState() => _RemoteHomeScreenState();
}

class _RemoteHomeScreenState extends State<RemoteHomeScreen> {
  final TextEditingController _ipCtrl = TextEditingController();
  final TextEditingController _pinCtrl = TextEditingController();
  final TextEditingController _textCtrl = TextEditingController();
  final SpeechToText _speech = SpeechToText();
  final GoogleTranslator _translator = GoogleTranslator();
  final TextRecognizer _textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);

  WebSocketChannel? _channel;
  Timer? _reconnectTimer;
  Timer? _heartbeatTimer;

  String? connectedIp;
  String? connectedPin;
  bool wsConnected = false;
  String status = "بانتظار الربط بالتلفزيون";
  String currentArabicPreview = "معاينة الترجمة العربية ستظهر هنا...";
  String lastProcessedText = "";

  bool isListening = false;
  bool isScanningQR = false;
  bool isCameraOCR = false;
  bool _isProcessingFrame = false;
  CameraController? _cameraController;

  double fontSize = 38.0;
  double bottomPadding = 60.0;
  double bgOpacity = 0.80;
  String textColor = "#FFFFFF";

  void _connectWebSocket(String ip, String pin) {
    _reconnectTimer?.cancel();
    _heartbeatTimer?.cancel();
    _channel?.sink.close();

    setState(() {
      connectedIp = ip;
      connectedPin = pin;
      status = "جاري الاتصال عبر WebSocket...";
    });

    try {
      final uri = Uri.parse("ws://$ip:8080");
      final channel = WebSocketChannel.connect(uri);
      _channel = channel;

      setState(() {
        wsConnected = true;
        status = "⚡ متصل بالتلفزيون ($ip)";
      });

      _sendPayload("تم الربط عبر WebSocket بنجاح! 🎮");

      _heartbeatTimer = Timer.periodic(const Duration(seconds: 5), (_) {
        if (wsConnected && _channel != null) {
          _channel!.sink.add(jsonEncode({"type": "ping", "pin": connectedPin}));
        }
      });

      channel.stream.listen(
        (_) {},
        onDone: () => _scheduleReconnect(),
        onError: (_) => _scheduleReconnect(),
      );
    } catch (_) {
      _scheduleReconnect();
    }
  }

  void _scheduleReconnect() {
    if (connectedIp == null || connectedPin == null) return;
    setState(() {
      wsConnected = false;
      status = "🔄 انقطع الاتصال — جاري إعادة الربط تلقائياً...";
    });
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(const Duration(seconds: 2), () {
      if (connectedIp != null && connectedPin != null) {
        _connectWebSocket(connectedIp!, connectedPin!);
      }
    });
  }

  void _sendPayload([String? customText]) {
    if (_channel == null || connectedPin == null) return;
    final msg = customText ?? _textCtrl.text;
    if (msg.isNotEmpty) {
      setState(() => currentArabicPreview = msg);
    }
    try {
      _channel!.sink.add(jsonEncode({
        "type": "subtitle",
        "pin": connectedPin,
        "text": msg,
        "fontSize": fontSize,
        "bottomPadding": bottomPadding,
        "bgOpacity": bgOpacity,
        "textColor": textColor,
      }));
    } catch (_) {
      _scheduleReconnect();
    }
  }

  Future<void> _toggleCameraOCR() async {
    if (isCameraOCR) {
      await _cameraController?.stopImageStream();
      await _cameraController?.dispose();
      _cameraController = null;
      setState(() => isCameraOCR = false);
      return;
    }

    if (isListening) {
      await _speech.stop();
      setState(() => isListening = false);
    }

    final cameras = await availableCameras();
    if (cameras.isEmpty) {
      setState(() => status = "❌ لم يتم العثور على كاميرا");
      return;
    }

    final controller = CameraController(
      cameras.first,
      ResolutionPreset.medium,
      enableAudio: false,
      imageFormatGroup: Platform.isIOS ? ImageFormatGroup.bgra8888 : ImageFormatGroup.nv21,
    );

    await controller.initialize();
    _cameraController = controller;
    setState(() => isCameraOCR = true);

    DateTime lastScan = DateTime.now();
    await controller.startImageStream((CameraImage image) async {
      if (_isProcessingFrame || DateTime.now().difference(lastScan).inMilliseconds < 650) return;
      _isProcessingFrame = true;
      lastScan = DateTime.now();

      try {
        final inputImage = _convertCameraImage(image, controller.description);
        if (inputImage != null) {
          final recognized = await _textRecognizer.processImage(inputImage);
          final eng = recognized.text.replaceAll('\n', ' ').trim();
          if (eng.length >= 3 && eng != lastProcessedText) {
            lastProcessedText = eng;
            setState(() => status = "📷 OCR: $eng");
            final tr = await _translator.translate(eng, from: 'en', to: 'ar');
            _sendPayload(tr.text);
          }
        }
      } catch (_) {}
      _isProcessingFrame = false;
    });
  }

  InputImage? _convertCameraImage(CameraImage image, CameraDescription camera) {
    final WriteBuffer allBytes = WriteBuffer();
    for (final Plane plane in image.planes) {
      allBytes.putUint8List(plane.bytes);
    }
    final bytes = allBytes.done().buffer.asUint8List();
    final imageSize = Size(image.width.toDouble(), image.height.toDouble());
    final rotation = InputImageRotationValue.fromRawValue(camera.sensorOrientation) ?? InputImageRotation.rotation0deg;
    final format = InputImageFormatValue.fromRawValue(image.format.raw) ?? InputImageFormat.bgra8888;

    return InputImage.fromBytes(
      bytes: bytes,
      metadata: InputImageMetadata(
        size: imageSize,
        rotation: rotation,
        format: format,
        bytesPerRow: image.planes.first.bytesPerRow,
      ),
    );
  }
Future<void> _toggleSpeechAI() async {
    if (isListening) {
      await _speech.stop();
      setState(() => isListening = false);
      return;
    }

    if (isCameraOCR) {
      await _toggleCameraOCR();
    }

    bool available = await _speech.initialize(
      onStatus: (s) {
        if (s == "done" && isListening) _listenLoop();
      },
      onError: (_) {},
    );
    if (available) {
      setState(() => isListening = true);
      _listenLoop();
    } else {
      setState(() => status = "❌ فعّل إذن المايكروفون من الإعدادات");
    }
  }

  void _listenLoop() {
    if (!isListening) return;
    _speech.listen(
      localeId: "en_US",
      listenFor: const Duration(seconds: 30),
      pauseFor: const Duration(seconds: 2),
      onResult: (res) async {
        String eng = res.recognizedWords.trim();
        if (eng.isNotEmpty && eng != lastProcessedText) {
          lastProcessedText = eng;
          setState(() => status = "🎙️ يسمع: $eng");
          try {
            var tr = await _translator.translate(eng, from: 'en', to: 'ar');
            _sendPayload(tr.text);
          } catch (_) {
            _sendPayload(eng);
          }
        }
      },
    );
  }

  void _showPS5WorkflowSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF10233F),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => Directionality(
        textDirection: TextDirection.rtl,
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("🎮 إعداد البلايستيشن (حساب ثانوي + أساسي)", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.lightBlueAccent)),
              const SizedBox(height: 12),
              const Text("1. على PS5: أنشئ حساب PSN ثانوي مجاني وفعّل «مشاركة الجهاز واللعب بدون اتصال» في حسابك الأساسي."),
              const SizedBox(height: 8),
              const Text("2. في تطبيق PS Remote Play الرسمي: سجّل الدخول بالحساب الثانوي فقط (تطبيقنا لا يطلب أو يحفظ كلمة مرور PSN)."),
              const SizedBox(height: 8),
              const Text("3. بعد اتصال Remote Play، اضغط زر PS في يد التحكم واختر حسابك الأساسي للعب على مدخل HDMI بشكل طبيعي."),
              const SizedBox(height: 8),
              const Text("4. تنبيه تقني لنظام iOS: أبل تمنع التقاط شاشة تطبيقات DRM خارجية في الخلفية؛ لذلك استخدم زر «📷 كاميرا OCR» أو «🎙️ الترجمة الصوتية AI» للترجمة الفورية فوق البلايستيشن."),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent),
                  onPressed: () async {
                    final uri = Uri.parse("psremoteplay://");
                    if (await canLaunchUrl(uri)) {
                      await launchUrl(uri);
                    }
                  },
                  icon: const Icon(Icons.open_in_new, color: Colors.white),
                  label: const Text("فتح تطبيق PS Remote Play الرسمي", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _reconnectTimer?.cancel();
    _heartbeatTimer?.cancel();
    _channel?.sink.close();
    _cameraController?.dispose();
    _textRecognizer.close();
    super.dispose();
  }
  @override
  Widget build(BuildContext context) {
    if (isScanningQR) {
      return Scaffold(
        appBar: AppBar(title: const Text("امسح باركود التلفزيون"), backgroundColor: const Color(0xFF0C1D36)),
        body: MobileScanner(
          onDetect: (capture) {
            for (final barcode in capture.barcodes) {
              if (barcode.rawValue != null) {
                try {
                  final d = jsonDecode(barcode.rawValue!);
                  if (d["ip"] != null && d["pin"] != null) {
                    setState(() => isScanningQR = false);
                    _connectWebSocket(d["ip"], d["pin"]);
                    break;
                  }
                } catch (_) {}
              }
            }
          },
        ),
      );
    }

    Color previewColor = Colors.white;
    try {
      previewColor = Color(int.parse("FF${textColor.replaceAll('#', '')}", radix: 16));
    } catch (_) {}

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text("MySard PS5 & TV", style: TextStyle(fontWeight: FontWeight.bold)),
          backgroundColor: const Color(0xFF0C1D36),
          centerTitle: true,
          actions: [
            IconButton(
              icon: const Icon(Icons.sports_esports, color: Colors.amber),
              tooltip: "إعداد حساب PSN الثانوي",
              onPressed: _showPS5WorkflowSheet,
            ),
            if (connectedIp != null)
              IconButton(
                icon: const Icon(Icons.logout, color: Colors.redAccent),
                onPressed: () {
                  _reconnectTimer?.cancel();
                  _heartbeatTimer?.cancel();
                  _channel?.sink.close();
                  setState(() {
                    connectedIp = null;
                    connectedPin = null;
                    wsConnected = false;
                  });
                },
              ),
          ],
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(18),
          child: connectedIp == null
              ? Container(
                  padding: const EdgeInsets.all(22),
                  decoration: BoxDecoration(color: const Color(0xFF10233F), borderRadius: BorderRadius.circular(22)),
                  child: Column(
                    children: [
                      SizedBox(
                        width: double.infinity,
                        height: 58,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                          onPressed: () => setState(() => isScanningQR = true),
                          icon: const Icon(Icons.qr_code_scanner, color: Colors.white, size: 28),
                          label: const Text("امسح باركود التلفزيون (WebSocket)", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
                        ),
                      ),
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 16),
                        child: Text("أو أدخل البيانات يدوياً", style: TextStyle(color: Colors.white60)),
                      ),
                      TextField(
                        controller: _ipCtrl,
                        keyboardType: TextInputType.url,
                        textAlign: TextAlign.center,
                        decoration: InputDecoration(hintText: "العنوان (مثال: 192.168.0.139)", filled: true, fillColor: const Color(0xFF0A1628), border: OutlineInputBorder(borderRadius: BorderRadius.circular(14))),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _pinCtrl,
                        keyboardType: TextInputType.number,
                        textAlign: TextAlign.center,
                        decoration: InputDecoration(hintText: "الرمز المكون من 8 أرقام", filled: true, fillColor: const Color(0xFF0A1628), border: OutlineInputBorder(borderRadius: BorderRadius.circular(14))),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.white12, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                          onPressed: () {
                            if (_ipCtrl.text.trim().isNotEmpty && _pinCtrl.text.trim().isNotEmpty) {
                              _connectWebSocket(_ipCtrl.text.trim(), _pinCtrl.text.trim());
                            }
                          },
                          child: const Text("اتصال يدوي", style: TextStyle(fontSize: 18, color: Colors.white)),
                        ),
                      ),
                      const SizedBox(height: 14),
                      TextButton.icon(
                        onPressed: _showPS5WorkflowSheet,
                        icon: const Icon(Icons.info_outline, color: Colors.amber),
                        label: const Text("خطوات ربط حساب PSN الثانوي والأساسي", style: TextStyle(color: Colors.amber)),
                      ),
                    ],
                  ),
                )
          : Column(
                  children: [
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(bgOpacity),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: Colors.white24),
                      ),
                      child: Column(
                        children: [
                          Text(status, style: TextStyle(color: wsConnected ? Colors.greenAccent : Colors.orangeAccent, fontSize: 13)),
                          const SizedBox(height: 8),
                          Text(
                            currentArabicPreview,
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: fontSize * 0.55, fontWeight: FontWeight.bold, color: previewColor),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    if (isCameraOCR && _cameraController != null && _cameraController!.value.isInitialized)
                      Container(
                        height: 160,
                        margin: const EdgeInsets.only(bottom: 14),
                        clipBehavior: Clip.hardEdge,
                        decoration: BoxDecoration(borderRadius: BorderRadius.circular(18), border: Border.all(color: Colors.amber, width: 2)),
                        child: CameraPreview(_cameraController!),
                      ),
                    Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(color: const Color(0xFF10233F), borderRadius: BorderRadius.circular(22)),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: SizedBox(
                                  height: 54,
                                  child: ElevatedButton.icon(
                                    style: ElevatedButton.styleFrom(backgroundColor: isCameraOCR ? Colors.redAccent : Colors.teal),
                                    onPressed: _toggleCameraOCR,
                                    icon: Icon(isCameraOCR ? Icons.stop : Icons.camera_alt, color: Colors.white),
                                    label: Text(isCameraOCR ? "إيقاف OCR" : "📷 كاميرا OCR", style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: SizedBox(
                                  height: 54,
                                  child: ElevatedButton.icon(
                                    style: ElevatedButton.styleFrom(backgroundColor: isListening ? Colors.redAccent : Colors.deepPurpleAccent),
                                    onPressed: _toggleSpeechAI,
                                    icon: Icon(isListening ? Icons.stop : Icons.mic, color: Colors.white),
                                    label: Text(isListening ? "إيقاف الصوت" : "🎙️ صوتي AI", style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: _textCtrl,
                            onChanged: (_) => _sendPayload(),
                            textAlign: TextAlign.center,
                            decoration: InputDecoration(hintText: "أو اكتب نصاً عربياً فورياً للشاشة...", filled: true, fillColor: const Color(0xFF0A1628), border: OutlineInputBorder(borderRadius: BorderRadius.circular(14))),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(color: const Color(0xFF10233F), borderRadius: BorderRadius.circular(22)),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Center(child: Text("🎨 تخصيص الترجمة على الشاشة", style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Colors.lightBlueAccent))),
                          const SizedBox(height: 10),
                          Text("حجم الخط: ${fontSize.toInt()}"),
                          Slider(value: fontSize, min: 20, max: 65, onChanged: (v) { setState(() => fontSize = v); _sendPayload(); }),
                          Text("ارتفاع الترجمة: ${bottomPadding.toInt()}"),
                          Slider(value: bottomPadding, min: 20, max: 350, onChanged: (v) { setState(() => bottomPadding = v); _sendPayload(); }),
                          Text("شفافية الخلفية: ${(bgOpacity * 100).toInt()}%"),
                          Slider(value: bgOpacity, min: 0, max: 1, onChanged: (v) { setState(() => bgOpacity = v); _sendPayload(); }),
                          const SizedBox(height: 6),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              _colorCircle("#FFFFFF", Colors.white),
                              _colorCircle("#FACC15", Colors.amber),
                              _colorCircle("#38BDF8", Colors.lightBlueAccent),
                              _colorCircle("#4ADE80", Colors.greenAccent),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _colorCircle(String hex, Color c) {
    return GestureDetector(
      onTap: () { setState(() => textColor = hex); _sendPayload(); },
      child: Container(width: 40, height: 40, decoration: BoxDecoration(color: c, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 2))),
    );
  }
}
