import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';

void main() => runApp(const MySardTVApp());

@pragma("vm:entry-point")
void overlayMain() {
  runApp(const MaterialApp(
    debugShowCheckedModeBanner: false,
    home: OverlaySubtitleWidget(),
  ));
}

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
  String localIp = "جاري جلب العنوان...";
  late String pinCode;
  bool isConnected = false;
  String subtitleText = "تم الاتصال بنجاح! ابدأ الكلام أو الكتابة من الآيفون...";
  double fontSize = 38.0;
  double bottomPadding = 60.0;
  double bgOpacity = 0.80;
  Color textColor = Colors.white;
  HttpServer? _server;

  @override
  void initState() {
    super.initState();
    pinCode = (10000000 + Random().nextInt(90000000)).toString();
    _initLocalServer();
  }

  Future<void> _initLocalServer() async {
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
      _server!.listen((HttpRequest request) async {
        request.response.headers.add("Access-Control-Allow-Origin", "*");
        request.response.headers.add("Access-Control-Allow-Methods", "POST, GET, OPTIONS");
        request.response.headers.add("Access-Control-Allow-Headers", "*");
        if (request.method == 'OPTIONS') {
          request.response.statusCode = 200;
          await request.response.close();
          return;
        }
        try {
          String body = await utf8.decoder.bind(request).join();
          if (body.isNotEmpty) {
            final data = jsonDecode(body);
            if (data["pin"] == pinCode) {
              if (await FlutterOverlayWindow.isActive()) {
                await FlutterOverlayWindow.shareData(body);
              }
              setState(() {
                isConnected = true;
                if (data["text"] != null && data["text"].toString().isNotEmpty) {
                  subtitleText = data["text"];
                }
                fontSize = (data["fontSize"] ?? fontSize).toDouble();
                bottomPadding = (data["bottomPadding"] ?? bottomPadding).toDouble();
                bgOpacity = (data["bgOpacity"] ?? bgOpacity).toDouble();
                String hex = (data["textColor"] ?? "#FFFFFF").replaceAll("#", "");
                if (hex.length == 6) textColor = Color(int.parse("FF$hex", radix: 16));
              });
            }
          }
        } catch (_) {}
        request.response.statusCode = 200;
        request.response.write("OK");
        await request.response.close();
      });
    } catch (e) {
      setState(() => localIp = "تأكد من الواي فاي");
    }
  }

  Future<void> _startOverlayForPS5() async {
    bool granted = await FlutterOverlayWindow.isPermissionGranted();
    if (!granted) {
      granted = await FlutterOverlayWindow.requestPermission() ?? false;
    }
    if (granted) {
      await FlutterOverlayWindow.showOverlay(
        enableDrag: false,
        height: 260,
        width: WindowSize.matchParent,
        alignment: OverlayAlignment.bottomCenter,
      );
    }
  }

  @override
  void dispose() {
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
                              const Icon(Icons.check_circle, color: Colors.greenAccent, size: 22),
                              const SizedBox(width: 8),
                              Text("متصل بالآيفون محلياً ⚡", style: GoogleFonts.cairo(fontSize: 18, color: Colors.white)),
                            ],
                          ),
                        ),
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blueAccent,
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                          onPressed: _startOverlayForPS5,
                          icon: const Icon(Icons.sports_esports, color: Colors.white),
                          label: Text("تشغيل فوق البلايستيشن (PS5)", style: GoogleFonts.cairo(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
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
                              decoration: BoxDecoration(color: Colors.blueAccent.withOpacity(0.15), borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.blueAccent.withOpacity(0.4))),
                              child: Text("⏱️ بانتظار الجوال...", style: GoogleFonts.cairo(fontSize: 18, color: Colors.lightBlueAccent)),
                            ),
                            const SizedBox(height: 16),
                            Text("اربط جوالك", style: GoogleFonts.cairo(fontSize: 48, fontWeight: FontWeight.w900, color: Colors.white)),
                            const SizedBox(height: 8),
                            Text("امسح الباركود بكاميرا تطبيق الآيفون أو أدخل البيانات يدوياً:", style: GoogleFonts.cairo(fontSize: 20, color: Colors.white70)),
                            const SizedBox(height: 28),
                            Container(
