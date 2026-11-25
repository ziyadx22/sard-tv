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
