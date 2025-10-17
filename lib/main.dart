import 'dart:io';
import 'dart:convert';
import 'dart:async';
import 'package:flutter/material.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'TCP Client',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: const TcpClientPage(),
    );
  }
}

class TcpClientPage extends StatefulWidget {
  const TcpClientPage({Key? key}) : super(key: key);

  @override
  State<TcpClientPage> createState() => _TcpClientPageState();
}

class _TcpClientPageState extends State<TcpClientPage> {
  Socket? _socket;
  final TextEditingController _hostController = TextEditingController(text: '22.40.0.69');
  final TextEditingController _portController = TextEditingController(text: '1884');
  bool _isConnected = false;
  Timer? _periodicTimer;
  int intCommand = 1;
  static const GUID = 1;
  static const GDRT = 2;
  static const GBAS = 3;
  static const GOUS = 4;
  static const GRTC = 5;
  static const GAID = 6;
  static const GSMP = 7;
  static const GBAP = 8;
  static const GVER = 9;
  static const GGSS = 10;

  static const GLOG = 15;

  String strUid = "";
  String strCsq = "";
  String strBattVal = "";
  String strBattThreshold = "";
  String strRunTime = "";
  String strRelay = "";
  String strSetDI = "";
  String strRTC = "";
  String strAssetId = "";
  String strSamplingTime = "";
  String strFirmwareVersion = "";

  int intLogStartIdx = 0;
  int intLogEndIdx = 0;

  bool isSending = false;

  @override
  void dispose() {
    _stopPeriodicSending();
    _disconnectFromServer();
    _hostController.dispose();
    _portController.dispose();
    super.dispose();
  }

  Future<void> _connectToServer() async {
    try {
      final host = _hostController.text;
      final port = int.parse(_portController.text);

      _socket = await Socket.connect(host, port);

      setState(() {
        _isConnected = true;
        _startPeriodicSending();
      });

      // Listen for incoming data
      _socket!.listen(
            (data) {
          final message = utf8.decode(data);
          processIncomingMessage(message);
        },
        onError: (error) {
          setState(() {
            _isConnected = false;
          });
        },
        onDone: () {
          setState(() {
            _isConnected = false;
          });
        },
      );

    } catch (e) {}
  }

  processIncomingMessage(String message){
    Map<String, dynamic> data = jsonDecode(message);
    String key = data.keys.first;

    setState(() {
      isSending = false;
      switch(key){
        case "GUID":
          var value = data.values.first;
          if(value.contains("|")){
            List<String> parts = value.split('|');
            strUid = parts[1];
          }
          intCommand = GDRT;
          break;

        case "GDRT":
          var value = data.values.first;
          strRunTime = value;

          intCommand = GBAS;
          break;

        case "GBAS":
          var value = data.values.first;
          strBattVal = value;

          intCommand = GOUS;
          break;

        case "GOUS":

          intCommand = GRTC;
          break;

        case "GRTC":
          var value = data.values.first;
          if(value.contains("|")){
            List<String> parts = value.split('|');
            strRTC = parts[1];
          }

          intCommand = GAID;
          break;

        case "GAID":
          var value = data.values.first;
          strAssetId = value;

          intCommand = GSMP;
          break;

        case "GSMP":
          var value = data.values.first;
          strSamplingTime = value;

          intCommand = GBAP;
          break;

        case "GBAP":
          var value = data.values.first;
          if(value.contains("|")){
            List<String> parts = value.split('|');
            strBattThreshold = parts[1];
          }

          intCommand = GVER;
          break;

        case "GVER":
          var value = data.values.first;
          strFirmwareVersion = value;

          intCommand = GGSS;
          break;

        case "GGSS":
          var value = data.values.first;
          if(value.contains("|")){
            List<String> parts = value.split('|');
            strCsq = parts[2];
          }

          intCommand = GUID;
          break;

        case "GLOG":
          break;
      }
    });
  }

  void sendCommand() {
    var sendCommand = {"GUID":"1"}; //Default value

    switch(intCommand){
      case GUID:
        sendCommand = {"GUID":"1"};
        break;

      case GDRT:
        sendCommand = {"GDRT":"-"};
        break;

      case GBAS:
        sendCommand = {"GBAS":"-"};
        break;

      case GOUS:
        sendCommand = {"GOUS":"1"};
        break;

      case GRTC:
        sendCommand = {"GRTC":"1"};
        break;

      case GAID:
        sendCommand = {"GAID":"-"};
        break;

      case GSMP:
        sendCommand = {"GSMP":"-"};
        break;

      case GBAP:
        sendCommand = {"GBAP":"-"};
        break;

      case GVER:
        sendCommand = {"GVER":"-"};
        break;

      case GGSS:
        sendCommand = {"GGSS":"-"};
        break;
    }
    isSending = true;
    _socket!.write('${jsonEncode(sendCommand)}\n');
    //_socket!.write('$sendCommand\n');
  }

  Future<void> _disconnectFromServer() async {
    if (_socket != null) {
      _stopPeriodicSending();
      await _socket!.close();
      setState(() {
        _isConnected = false;
      });
      _socket = null;
    }
  }

  void _startPeriodicSending() {
    _periodicTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_socket != null && _isConnected) {
        if(!isSending){
          sendCommand();
        }
        //_socket!.write('$message\n');
      }
    });

  }

  void _stopPeriodicSending() {
    _periodicTimer?.cancel();
    _periodicTimer = null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('TCP Client'),
        actions: [
          if (_isConnected)
            IconButton(
              icon: const Icon(Icons.close),
              onPressed: _disconnectFromServer,
              tooltip: 'Disconnect',
            ),
        ],
      ),
      body: Column(
        children: [
          Card(
            margin: const EdgeInsets.all(8),
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        flex: 3,
                        child: TextField(
                          controller: _hostController,
                          decoration: const InputDecoration(
                            labelText: 'Host',
                            border: OutlineInputBorder(),
                          ),
                          enabled: !_isConnected,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        flex: 1,
                        child: TextField(
                          controller: _portController,
                          decoration: const InputDecoration(
                            labelText: 'Port',
                            border: OutlineInputBorder(),
                          ),
                          keyboardType: TextInputType.number,
                          enabled: !_isConnected,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ElevatedButton(
                    onPressed: _isConnected ? null : _connectToServer,
                    child: Text(_isConnected ? 'Connected' : 'Connect'),
                  ),
                ],
              ),
            ),
          ),

          // Message input
          if (_isConnected)
            Container(
              padding: const EdgeInsets.all(10),
              child: Column(
                children: [
                  //UID
                  Padding(
                    padding: const EdgeInsets.all(10.0),
                    child: Row(
                      children: [
                        Text(
                          "UID: ",
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold
                          ),
                        ),
                        Text(
                          strUid,
                          style: TextStyle(
                              fontSize: 16,
                          ),
                        ),
                        const SizedBox(width: 8),
                      ],
                    ),
                  ),

                  //CSQ
                  Padding(
                    padding: const EdgeInsets.all(10.0),
                    child: Row(
                      children: [
                        Text(
                          "CSQ: ",
                          style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold
                          ),
                        ),
                        Text(
                          strCsq,
                          style: TextStyle(
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(width: 8),
                      ],
                    ),
                  ),

                  //Battery Value
                  Padding(
                    padding: const EdgeInsets.all(10.0),
                    child: Row(
                      children: [
                        Text(
                          "Battery Value: ",
                          style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold
                          ),
                        ),
                        Text(
                          strBattVal,
                          style: TextStyle(
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(width: 8),
                      ],
                    ),
                  ),

                  //Run Time
                  Padding(
                    padding: const EdgeInsets.all(10.0),
                    child: Row(
                      children: [
                        Text(
                          "Run Time: ",
                          style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold
                          ),
                        ),
                        Text(
                          strRunTime,
                          style: TextStyle(
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(width: 8),
                      ],
                    ),
                  ),

                  //Relay
                  Padding(
                    padding: const EdgeInsets.all(10.0),
                    child: Row(
                      children: [
                        Text(
                          "Relay: ",
                          style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold
                          ),
                        ),
                        Text(
                          strRelay,
                          style: TextStyle(
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(width: 8),
                      ],
                    ),
                  ),

                  //Set DI
                  Padding(
                    padding: const EdgeInsets.all(10.0),
                    child: Row(
                      children: [
                        Text(
                          "Set DI: ",
                          style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold
                          ),
                        ),
                        Text(
                          strSetDI,
                          style: TextStyle(
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(width: 8),
                      ],
                    ),
                  ),

                  //RTC
                  Padding(
                    padding: const EdgeInsets.all(10.0),
                    child: Row(
                      children: [
                        Text(
                          "RTC: ",
                          style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold
                          ),
                        ),
                        Text(
                          strRTC,
                          style: TextStyle(
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(width: 8),
                      ],
                    ),
                  ),

                  //Asset ID
                  Padding(
                    padding: const EdgeInsets.all(10.0),
                    child: Row(
                      children: [
                        Text(
                          "Asset ID: ",
                          style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold
                          ),
                        ),
                        Text(
                          strAssetId,
                          style: TextStyle(
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(width: 8),
                      ],
                    ),
                  ),

                  //Sampling Time
                  Padding(
                    padding: const EdgeInsets.all(10.0),
                    child: Row(
                      children: [
                        Text(
                          "Sampling Time: ",
                          style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold
                          ),
                        ),
                        Text(
                          strSamplingTime,
                          style: TextStyle(
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(width: 8),
                      ],
                    ),
                  ),

                  //Firmware Version
                  Padding(
                    padding: const EdgeInsets.all(10.0),
                    child: Row(
                      children: [
                        Text(
                          "Firmware Version: ",
                          style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold
                          ),
                        ),
                        Text(
                          strFirmwareVersion,
                          style: TextStyle(
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(width: 8),
                      ],
                    ),
                  ),

                ],
              ),
            ),
        ],
      ),
    );
  }
}