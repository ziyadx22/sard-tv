import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:translator/translator.dart';

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

  String? connectedIp;
  String? connectedPin;
  String status = "متصل محلياً ⚡";
  String lastHeard = "";
  bool isListening = false;
  bool isScanning = false;
  double fontSize = 38.0;
  double bottomPadding = 60.0;
  double bgOpacity = 0.80;
  String textColor = "#FFFFFF";

  void _connectManual() {
    String ip = _ipCtrl.text.trim();
    String pin = _pinCtrl.text.trim();
    if (ip.isEmpty || pin.isEmpty) return;
    setState(() {
      connectedIp = ip;
      connectedPin = pin;
    });
    _sendUpdate("تم الربط بنجاح يا زياد! 🎮");
  }

  Future<void> _toggleAITranslation() async {
    if (isListening) {
      await _speech.stop();
      setState(() => isListening = false);
      return;
    }
    bool available = await _speech.initialize(
      onStatus: (s) {
        if (s == "done" && isListening) _startListeningLoop();
      },
      onError: (_) {},
    );
    if (available) {
      setState(() => isListening = true);
      _startListeningLoop();
    } else {
      setState(() => status = "❌ فعّل إذن المايكروفون من الإعدادات");
    }
  }

  void _startListeningLoop() {
    if (!isListening) return;
    _speech.listen(
      localeId: "en_US",
      listenFor: const Duration(seconds: 30),
      pauseFor: const Duration(seconds: 2),
      onResult: (res) async {
        String eng = res.recognizedWords.trim();
        if (eng.isNotEmpty && eng != lastHeard) {
          lastHeard = eng;
          setState(() => status = "🎙️ يسمع: $eng");
          try {
            var tr = await _translator.translate(eng, from: 'en', to: 'ar');
            _sendUpdate(tr.text);
          } catch (_) {
            _sendUpdate(eng);
          }
        }
      },
    );
  }

  Future<void> _sendUpdate([String? customText]) async {
    if (connectedIp == null || connectedPin == null) return;
    String msg = customText ?? _textCtrl.text;
    try {
      final res = await http.post(
        Uri.parse("http://$connectedIp:8080"),
        body: jsonEncode({
          "pin": connectedPin,
          "text": msg,
          "fontSize": fontSize,
          "bottomPadding": bottomPadding,
          "bgOpacity": bgOpacity,
          "textColor": textColor,
        }),
      ).timeout(const Duration(seconds: 2));
      if (res.statusCode == 200) {
        setState(() => status = msg.isEmpty ? "✅ تم تحديث المظهر" : "✅ على الشاشة: $msg");
      }
    } catch (_) {
      setState(() => status = "❌ تأكد أن الآيفون والتلفزيون على نفس الواي فاي");
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isScanning) {
      return Scaffold(
        appBar: AppBar(title: const Text("امسح باركود التلفزيون"), backgroundColor: const Color(0xFF0C1D36)),
        body: MobileScanner(
          onDetect: (capture) {
            for (final barcode in capture.barcodes) {
              if (barcode.rawValue != null) {
                try {
                  final d = jsonDecode(barcode.rawValue!);
                  if (d["ip"] != null && d["pin"] != null) {
                    setState(() {
                      isScanning = false;
                      connectedIp = d["ip"];
                      connectedPin = d["pin"];
                    });
                    _sendUpdate("تم الربط بالباركود بنجاح! ⚡");
                    break;
                  }
                } catch (_) {}
              }
            }
          },
        ),
      );
    }

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text("MySard AI Remote", style: TextStyle(fontWeight: FontWeight.bold)),
          backgroundColor: const Color(0xFF0C1D36),
          centerTitle: true,
          actions: [
            if (connectedIp != null)
              IconButton(
                icon: const Icon(Icons.logout, color: Colors.redAccent),
                onPressed: () => setState(() { isListening = false; _speech.stop(); connectedIp = null; connectedPin = null; }),
              )
          ],
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: connectedIp == null
              ? Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(color: const Color(0xFF10233F), borderRadius: BorderRadius.circular(22)),
                  child: Column(
                    children: [
                      SizedBox(
                        width: double.infinity,
                        height: 60,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                          onPressed: () => setState(() => isScanning = true),
                          icon: const Icon(Icons.qr_code_scanner, color: Colors.white, size: 28),
                          label: const Text("امسح باركود التلفزيون (سريع)", style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold, color: Colors.white)),
                        ),
                      ),
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 18),
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
                        height: 52,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.white12, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                          onPressed: _connectManual,
                          child: const Text("اتصال يدوي", style: TextStyle(fontSize: 18, color: Colors.white)),
                        ),
                      ),
                    ],
                  ),
                )
              : Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(color: const Color(0xFF10233F), borderRadius: BorderRadius.circular(22)),
                      child: Column(
                        children: [
                          Text("⚡ متصل بالتلفزيون ($connectedIp)", style: const TextStyle(fontSize: 16, color: Colors.lightBlueAccent, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 14),
                          SizedBox(
                            width: double.infinity,
                            height: 60,
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(backgroundColor: isListening ? Colors.redAccent : Colors.deepPurpleAccent, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                              onPressed: _toggleAITranslation,
                              icon: Icon(isListening ? Icons.stop : Icons.mic, color: Colors.white, size: 28),
                              label: Text(isListening ? "إيقاف الترجمة التلقائية" : "🎙️ ترجمة صوتية لايف (AI)", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
                            ),
                          ),
                          const SizedBox(height: 14),
                          TextField(
                            controller: _textCtrl,
                            onChanged: (_) => _sendUpdate(),
                            textAlign: TextAlign.center,
                            decoration: InputDecoration(hintText: "أو اكتب أي جملة تظهر فوراً...", filled: true, fillColor: const Color(0xFF0A1628), border: OutlineInputBorder(borderRadius: BorderRadius.circular(14))),
                          ),
