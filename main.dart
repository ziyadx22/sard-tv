import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:qr_flutter/qr_flutter.dart';

void main() => runApp(const MySardTVApp());

class MySardTVApp extends StatelessWidget {
  const MySardTVApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(scaffoldBackgroundColor: const Color(0xFF0A1628)),
      home: const TVScreen(),
    );
  }
}

class TVScreen extends StatefulWidget {
  const TVScreen({super.key});
  @override
  State<TVScreen> createState() => _TVScreenState();
}

class _TVScreenState extends State<TVScreen> {
  static const platform = MethodChannel('com.ziyad.mysard/overlay');
  String localIp = "جاري جلب العنوان...";
  late String pinCode;
  bool isConnected = false;
  bool overlayActive = false;
  String subtitleText = "تم الاتصال عبر WebSocket! ابدأ الترجمة من الآيفون...";
  double fontSize = 38.0;
  double bottomPadding = 60.0;
  double bgOpacity = 0.80;
  Color textColor = Colors.white;
  String hexStr = "#FFFFFF";
  HttpServer? _server;
  WebSocket? _activeClient;

  @override
  void initState() {
    super.initState();
    pinCode = (10000000 + Random().nextInt(90000000)).toString();
    _startWebSocketServer();
  }

  Future<void> _startWebSocketServer() async {
    try {
      for (var interface in await NetworkInterface.list()) {
        for (var addr in interface.addresses) {
          if (addr.type == InternetAddressType.IPv4 && !addr.isLoopback) {
            setState(() => localIp = addr.address);
            break;
          }
        }
      }
      _server = await HttpServer.bind(InternetAddress.anyIPv4, 8080);
      await for (HttpRequest request in _server!) {
        if (WebSocketTransformer.isUpgradeRequest(request)) {
          _handleClient(await WebSocketTransformer.upgrade(request));
        } else {
          request.response.statusCode = HttpStatus.ok;
          request.response.write("MySard Ready");
          await request.response.close();
        }
      }
    } catch (_) {
      setState(() => localIp = "تحقق من الواي فاي");
    }
  }

  void _handleClient(WebSocket socket) {
    _activeClient?.close();
    _activeClient = socket;
    socket.listen(
      (message) async {
        try {
          final data = jsonDecode(message.toString());
          if (data["pin"] != pinCode) return;
          if (data["type"] == "ping") {
            socket.add(jsonEncode({"type": "pong"}));
            return;
          }
          setState(() {
            isConnected = true;
            if (data["text"] != null && data["text"].toString().isNotEmpty) {
              subtitleText = data["text"];
            }
            fontSize = (data["fontSize"] ?? fontSize).toDouble();
            bottomPadding = (data["bottomPadding"] ?? bottomPadding).toDouble();
            bgOpacity = (data["bgOpacity"] ?? bgOpacity).toDouble();
            hexStr = data["textColor"] ?? hexStr;
            String hex = hexStr.replaceAll("#", "");
            if (hex.length == 6) textColor = Color(int.parse("FF$hex", radix: 16));
          });
          await platform.invokeMethod('updateText', {
            "text": subtitleText,
            "fontSize": fontSize,
            "bottomPadding": bottomPadding.toInt(),
            "bgOpacity": bgOpacity,
            "textColor": hexStr,
          });
        } catch (_) {}
      },
      onDone: () => setState(() => isConnected = false),
      onError: (_) => setState(() => isConnected = false),
    );
  }

  Future<void> _toggleOverlay() async {
    try {
      if (overlayActive) {
        await platform.invokeMethod('stopOverlay');
        setState(() => overlayActive = false);
      } else {
        final ok = await platform.invokeMethod('startOverlay');
        if (ok == true) setState(() => overlayActive = true);
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _activeClient?.close();
    _server?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final qrData = jsonEncode({"ip": localIp, "pin": pinCode});
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF0C1D36), Color(0xFF060D1A)],
          ),
        ),
        child: isConnected ? _buildConnectedView() : _buildPairingView(qrData),
      ),
    );
  }

  Widget _buildConnectedView() {
    return Stack(
      children: [
        Positioned(
          top: 28,
          right: 32,
          left: 32,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(14)),
                child: Text("⚡ WebSocket متصل ($localIp)", style: GoogleFonts.cairo(fontSize: 18, color: Colors.greenAccent)),
              ),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: overlayActive ? Colors.redAccent : Colors.blueAccent,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                ),
                onPressed: _toggleOverlay,
                icon: const Icon(Icons.sports_esports, color: Colors.white),
                label: Text(
                  overlayActive ? "إيقاف طبقة البلايستيشن" : "تشغيل فوق البلايستيشن (PS5)",
                  style: GoogleFonts.cairo(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                ),
              ),
            ],
          ),
        ),
        Positioned(
          bottom: bottomPadding,
          left: 50,
          right: 50,
          child: Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
              decoration: BoxDecoration(color: Colors.black.withOpacity(bgOpacity), borderRadius: BorderRadius.circular(16)),
              child: Text(
                subtitleText,
                textAlign: TextAlign.center,
                textDirection: TextDirection.rtl,
                style: GoogleFonts.cairo(fontSize: fontSize, fontWeight: FontWeight.bold, color: textColor),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPairingView(String qrData) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 60, vertical: 40),
        child: Row(
          children: [
            Expanded(
              flex: 5,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("MySard TV", style: GoogleFonts.cairo(fontSize: 30, fontWeight: FontWeight.bold, color: Colors.blueAccent)),
                  const SizedBox(height: 12),
                  Text("اربط جوالك", style: GoogleFonts.cairo(fontSize: 48, fontWeight: FontWeight.w900, color: Colors.white)),
                  const SizedBox(height: 8),
                  Text("امسح الباركود بكاميرا تطبيق الآيفون أو أدخل البيانات:", style: GoogleFonts.cairo(fontSize: 20, color: Colors.white70)),
                  const SizedBox(height: 24),
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(18)),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text("العنوان (IP)", style: GoogleFonts.cairo(fontSize: 20, color: Colors.white70)),
                            Text(localIp, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white)),
                          ],
                        ),
                        const Divider(color: Colors.white24, height: 24),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text("الرمز (PIN)", style: GoogleFonts.cairo(fontSize: 20, color: Colors.white70)),
                            Text(pinCode, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: Colors.amber)),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 60),
            Expanded(
              flex: 4,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(28)),
                  child: QrImageView(data: qrData, version: QrVersions.auto, size: 280.0, backgroundColor: Colors.white),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
