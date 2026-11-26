import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:translator/translator.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

void main() => runApp(const MaterialApp(debugShowCheckedModeBanner: false, home: RemoteHomeScreen()));

class RemoteHomeScreen extends StatefulWidget {
  const RemoteHomeScreen({super.key});
  @override
  State<RemoteHomeScreen> createState() => _RemoteHomeScreenState();
}

class _RemoteHomeScreenState extends State<RemoteHomeScreen> {
  final _ipCtrl = TextEditingController(), _pinCtrl = TextEditingController(), _textCtrl = TextEditingController();
  final _speech = SpeechToText();
  final _translator = GoogleTranslator();
  WebSocketChannel? _channel;
  Timer? _reTimer;
  String? ip, pin;
  bool connected = false, isListening = false, isScanning = false;
  String status = "Ready to pair", preview = "Arabic subtitle preview...", lastTxt = "", colorHex = "#FFFFFF";
  double fontSize = 38.0, bottomPad = 60.0, bgOpacity = 0.80;

  void _connect(String newIp, String newPin) {
    _reTimer?.cancel();
    _channel?.sink.close();
    setState(() { ip = newIp; pin = newPin; status = "Connecting..."; });
    try {
      _channel = WebSocketChannel.connect(Uri.parse("ws://$newIp:8080"));
      setState(() { connected = true; status = "Connected ($newIp)"; });
      _send("Connected to TV!");
      _channel!.stream.listen((_) {}, onDone: _reconnect, onError: (_) => _reconnect());
    } catch (_) { _reconnect(); }
  }

  void _reconnect() {
    if (ip == null || pin == null) return;
    setState(() { connected = false; status = "Reconnecting..."; });
    _reTimer = Timer(const Duration(seconds: 2), () => _connect(ip!, pin!));
  }

  void _send([String? custom]) {
    if (_channel == null || pin == null) return;
    final msg = custom ?? _textCtrl.text;
    if (msg.isNotEmpty) setState(() => preview = msg);
    try {
      _channel!.sink.add(jsonEncode({"type": "subtitle", "pin": pin, "text": msg, "fontSize": fontSize, "bottomPadding": bottomPad, "bgOpacity": bgOpacity, "textColor": colorHex}));
    } catch (_) { _reconnect(); }
  }

  Future<void> _toggleMic() async {
    if (isListening) { await _speech.stop(); setState(() => isListening = false); return; }
    if (await _speech.initialize(onStatus: (s) { if (s == "done" && isListening) _listen(); })) {
      setState(() => isListening = true); _listen();
    }
  }

  void _listen() {
    if (!isListening) return;
    _speech.listen(localeId: "en_US", listenFor: const Duration(seconds: 30), pauseFor: const Duration(seconds: 2), onResult: (r) async {
      final eng = r.recognizedWords.trim();
      if (eng.isNotEmpty && eng != lastTxt) {
        lastTxt = eng; setState(() => status = "Mic: $eng");
        try { _send((await _translator.translate(eng, from: 'en', to: 'ar')).text); } catch (_) { _send(eng); }
      }
    });
  }

  @override
  void dispose() { _reTimer?.cancel(); _channel?.sink.close(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    if (isScanning) {
      return Scaffold(appBar: AppBar(title: const Text("Scan TV QR"), backgroundColor: const Color(0xFF0C1D36)), body: MobileScanner(onDetect: (c) {
        for (final b in c.barcodes) {
          if (b.rawValue != null) {
            try { final d = jsonDecode(b.rawValue!); if (d["ip"] != null) { setState(() => isScanning = false); _connect(d["ip"], d["pin"]); break; } } catch (_) {}
          }
        }
      }));
    }
    return Scaffold(
      backgroundColor: const Color(0xFF0A1628),
      appBar: AppBar(title: const Text("MySard PS5 & TV"), backgroundColor: const Color(0xFF0C1D36), actions: [
        if (ip != null) IconButton(icon: const Icon(Icons.logout, color: Colors.redAccent), onPressed: () { _reTimer?.cancel(); _channel?.sink.close(); setState(() { ip = null; pin = null; connected = false; }); }),
      ]),
      body: SingleChildScrollView(padding: const EdgeInsets.all(16), child: ip == null ? Column(children: [
        SizedBox(width: double.infinity, height: 55, child: ElevatedButton.icon(style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent), onPressed: () => setState(() => isScanning = true), icon: const Icon(Icons.qr_code_scanner, color: Colors.white), label: const Text("Scan TV QR Code", style: TextStyle(fontSize: 18, color: Colors.white)))),
        const SizedBox(height: 16),
        TextField(controller: _ipCtrl, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(hintText: "TV IP Address", hintStyle: TextStyle(color: Colors.white54), filled: true, fillColor: Color(0xFF10233F))),
        const SizedBox(height: 10),
        TextField(controller: _pinCtrl, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(hintText: "8-Digit PIN", hintStyle: TextStyle(color: Colors.white54), filled: true, fillColor: Color(0xFF10233F))),
        const SizedBox(height: 14),
        ElevatedButton(onPressed: () { if (_ipCtrl.text.isNotEmpty) _connect(_ipCtrl.text.trim(), _pinCtrl.text.trim()); }, child: const Text("Connect Manually")),
      ]) : Column(children: [
        Container(width: double.infinity, padding: const EdgeInsets.all(14), decoration: BoxDecoration(color: Colors.black.withOpacity(bgOpacity), borderRadius: BorderRadius.circular(14)), child: Column(children: [
          Text(status, style: TextStyle(color: connected ? Colors.greenAccent : Colors.orangeAccent, fontSize: 12)),
          const SizedBox(height: 6),
          Text(preview, textAlign: TextAlign.center, textDirection: TextDirection.rtl, style: TextStyle(fontSize: fontSize * 0.55, fontWeight: FontWeight.bold, color: Color(int.parse("FF${colorHex.replaceAll('#', '')}", radix: 16)))),
        ])),
        const SizedBox(height: 12),
        SizedBox(width: double.infinity, height: 52, child: ElevatedButton.icon(style: ElevatedButton.styleFrom(backgroundColor: isListening ? Colors.redAccent : Colors.deepPurpleAccent), onPressed: _toggleMic, icon: const Icon(Icons.mic, color: Colors.white), label: Text(isListening ? "Stop AI Mic" : "Live AI Voice Translation", style: const TextStyle(fontSize: 17, color: Colors.white)))),
        const SizedBox(height: 10),
        TextField(controller: _textCtrl, onChanged: (_) => _send(), textAlign: TextAlign.center, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(hintText: "Type instant subtitle...", hintStyle: TextStyle(color: Colors.white54), filled: true, fillColor: Color(0xFF10233F))),
        const SizedBox(height: 12),
        Text("Font Size: ${fontSize.toInt()}", style: const TextStyle(color: Colors.white)),
        Slider(value: fontSize, min: 20, max: 65, onChanged: (v) { setState(() => fontSize = v); _send(); }),
        Text("Position: ${bottomPad.toInt()}", style: const TextStyle(color: Colors.white)),
        Slider(value: bottomPad, min: 20, max: 350, onChanged: (v) { setState(() => bottomPad = v); _send(); }),
        Text("Opacity: ${(bgOpacity * 100).toInt()}%", style: const TextStyle(color: Colors.white)),
        Slider(value: bgOpacity, min: 0, max: 1, onChanged: (v) { setState(() => bgOpacity = v); _send(); }),
        Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: ["#FFFFFF", "#FACC15", "#38BDF8", "#4ADE80"].map((h) => GestureDetector(onTap: () { setState(() => colorHex = h); _send(); }, child: CircleAvatar(backgroundColor: Color(int.parse("FF${h.replaceAll('#', '')}", radix: 16)), radius: 18))).toList()),
      ])),
    );
  }
}
