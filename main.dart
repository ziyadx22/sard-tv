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
          final socket = await WebSocketTransformer.upgrade(request);
          _handleClient(socket);
        } else {
          request.response.statusCode = HttpStatus.ok;
          request.response.write("MySard WebSocket Server Ready");
          await request.response.close();
        }
      }
    } catch (_) {
      setState(() => localIp = "تحقق من اتصال الواي فاي");
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

          socket.add(jsonEncode({"type": "ack", "ts": DateTime.now().millisecondsSinceEpoch}));

          try {
            await platform.invokeMethod('updateText', {
              "text": subtitleText,
              "fontSize": fontSize,
              "bottomPadding": bottomPadding.toInt(),
              "bgOpacity": bgOpacity,
              "textColor": hexStr,
            });
          } catch (_) {}
        } catch (_) {}
      },
      onDone: () {
        if (_activeClient == socket) {
          setState(() => isConnected = false);
        }
      },
      onError: (_) {
        if (_activeClient == socket) {
          setState(() => isConnected = false);
        }
      },
    );
  }

  Future<void> _toggleOverlayForPS5() async {
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
        child: isConnected
            ? Stack(
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
                          child: Row(
                            children: [
                              const Icon(Icons.bolt, color: Colors.greenAccent, size: 22),
                              const SizedBox(width: 8),
                              Text("WebSocket متصل ⚡ ($localIp)", style: GoogleFonts.cairo(fontSize: 18, color: Colors.white)),
                            ],
                          ),
                        ),
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: overlayActive ? Colors.redAccent : Colors.blueAccent,
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                          onPressed: _toggleOverlayForPS5,
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
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(bgOpacity),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.white12),
                        ),
                        child: Text(
                          subtitleText,
                          textAlign: TextAlign.center,
                          textDirection: TextDirection.rtl,
                          style: GoogleFonts.cairo(
                            fontSize: fontSize,
                            fontWeight: FontWeight.bold,
                            color: textColor,
                            shadows: [const Shadow(blurRadius: 8, color: Colors.black, offset: Offset(2, 2))],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              )
            : Directionality(
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
                            Row(
                              children: [
                                Container(
                                  width: 48,
                                  height: 48,
                                  decoration: BoxDecoration(color: Colors.blueAccent, borderRadius: BorderRadius.circular(12)),
                                  child: const Center(child: Text("S", style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: Colors.white))),
                                ),
                                const SizedBox(width: 14),
                                Text("MySard TV", style: GoogleFonts.cairo(fontSize: 26, fontWeight: FontWeight.bold, color: Colors.white)),
                              ],
                            ),
                            const SizedBox(height: 24),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                              decoration: BoxDecoration(
                                color: Colors.blueAccent.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: Colors.blueAccent.withOpacity(0.4)),
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
                            Row(
                              children: [
                                Container(
                                  width: 48,
                                  height: 48,
                                  decoration: BoxDecoration(color: Colors.blueAccent, borderRadius: BorderRadius.circular(12)),
                                  child: const Center(child: Text("S", style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: Colors.white))),
                                ),
                                const SizedBox(width: 14),
                                Text("MySard TV", style: GoogleFonts.cairo(fontSize: 26, fontWeight: FontWeight.bold, color: Colors.white)),
                              ],
                            ),
                            const SizedBox(height: 24),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                              decoration: BoxDecoration(
                                color: Colors.blueAccent.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: Colors.blueAccent.withOpacity(0.4)),
                              ),
                              child: Text("⏱️ بانتظار اتصال WebSocket من الجوال...", style: GoogleFonts.cairo(fontSize: 18, color: Colors.lightBlueAccent)),
                            ),
                            const SizedBox(height: 16),
                            Text("اربط جوالك", style: GoogleFonts.cairo(fontSize: 48, fontWeight: FontWeight.w900, color: Colors.white)),
                            const SizedBox(height: 8),
                            Text("امسح الباركود بكاميرا تطبيق الآيفون أو أدخل البيانات يدوياً:", style: GoogleFonts.cairo(fontSize: 20, color: Colors.white70)),
                            const SizedBox(height: 28),
                            Container(
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(color: Colors.white.withOpacity(0.06), borderRadius: BorderRadius.circular(18), border: Border.all(color: Colors.white12)),
                              child: Column(
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text("العنوان (IP)", style: GoogleFonts.cairo(fontSize: 20, color: Colors.white70)),
                                      Text(localIp, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 1)),
                                    ],
                                  ),
                                  const Divider(color: Colors.white12, height: 24),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text("الرمز (PIN)", style: GoogleFonts.cairo(fontSize: 20, color: Colors.white70)),
                                      Text(pinCode, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: Colors.amber, letterSpacing: 2)),
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
                            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(28), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.4), blurRadius: 30)]),
                            child: QrImageView(
                              data: qrData,
                              version: QrVersions.auto,
                              size: 300.0,
                              backgroundColor: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
      ),
    );
  }
}
