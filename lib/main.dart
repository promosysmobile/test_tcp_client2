import 'dart:io';
import 'dart:convert';
import 'dart:async';
import 'package:csv/csv.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'package:csv/csv.dart';
import 'package:permission_handler/permission_handler.dart';

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

  final TextEditingController _startIdxController = TextEditingController();
  final TextEditingController _endIdxController = TextEditingController();

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

  static const SDEB = 15;
  static const GACT = 16;

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
  int intLogCurrentIdx = 1;

  bool isSending = false;
  bool isDownloadLog = false;


  String strDebugMode = "1";

  // Example data
  List<List<dynamic>> logsList = [];

  double downloadLogProgress = 0.0;

  @override
  void initState() {
    requestStoragePermission();
    super.initState();
  }


  //When Connect button is pressed
  Future<void> _connectToServer() async {
    try {
      final host = _hostController.text;
      final port = int.parse(_portController.text);

      //connect to server
      _socket = await Socket.connect(host, port);

      setState(() {
        _isConnected = true;
        _startPeriodicSending();    //start the timer to send command
      });

      // Listen for incoming data
      _socket!.listen(
            (data) {
          final message = utf8.decode(data);
          processIncomingMessage(message);  //process the reply from server
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

  Future<bool> requestStoragePermission() async {
    var status = await Permission.manageExternalStorage.request().isGranted;
    return status;
  }

  Future<Directory?> getPublicDownloadsDirectory() async {
    if (Platform.isAndroid) {
      // For Android
      final dir = Directory('/storage/emulated/0/Download');
      if (await dir.exists()) return dir;
    } else if (Platform.isIOS) {
      // iOS doesn’t allow public folders, only app directories
      return await getApplicationDocumentsDirectory();
    }
    return null;
  }

  Future<void> saveCsvToPublicFolder() async {
    if (!await requestStoragePermission()) {
      print("Storage permission not granted");
      return;
    }

    final downloadsDir = await getPublicDownloadsDirectory();
    if (downloadsDir == null) {
      print("Unable to get download directory");
      return;
    }

    final filePath = "${downloadsDir.path}/${getSaveLogFileDateTime()}.csv";
    
    String csvData = const ListToCsvConverter().convert(logsList);
    final file = File(filePath);

    await file.writeAsString(csvData);
    print("CSV saved to: $filePath");
  }


  String getFormattedDateTime() {
    final now = DateTime.now();
    final formatter = DateFormat('dd/MM/yyyy HH:mm:ss');
    return formatter.format(now);
  }

  String getSaveLogFileDateTime() {
    final now = DateTime.now();
    final formatter = DateFormat('TTL_ddMMyyyy_HHmmss');
    return formatter.format(now);
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

        case "SDEB":
          var value = data.values.first;
          if(value == "OK"){
            if(isDownloadLog){
              logsList.clear();
              intCommand = GACT;
              intLogCurrentIdx = intLogStartIdx;
            }else{
              intCommand = GRTC;
              Fluttertoast.showToast(
                  msg: "Finish download log",
                  toastLength: Toast.LENGTH_SHORT,
                  fontSize: 16.0
              );
            }
          }
          break;

        case "GACT":
          var value = data.values.first;
          if(value.contains("|")){
            List<String> parts = value.split('|');
            logsList.add([getFormattedDateTime(), parts[1]]);

            if(parts[0] == intLogEndIdx.toString()){
              isDownloadLog = false;
              strDebugMode = "1";
              intCommand = SDEB;
              saveCsvToPublicFolder();
            }else{
              intLogCurrentIdx += 1;
              intCommand = GACT;
            }
          }
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

      case SDEB:
        sendCommand = {"SDEB":strDebugMode};
        break;

      case GACT:
        sendCommand = {"GACT":"$intLogCurrentIdx"};
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
    _periodicTimer = Timer.periodic(const Duration(milliseconds: 200), (timer) {
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
  void dispose() {
    _stopPeriodicSending();
    _disconnectFromServer();
    _hostController.dispose();
    _portController.dispose();
    super.dispose();
  }

  void startDownloadingLog() async {
    intLogStartIdx = int.parse(_startIdxController.text);
    intLogEndIdx = int.parse(_endIdxController.text);

    isSending = true; //temporarily stop the request command
    isDownloadLog = true;
    await Future.delayed(Duration(seconds: 1)); //delay
    strDebugMode = "2";
    intCommand = SDEB;
    isSending = false;
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


                  Text(
                    "Download Log",
                    style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold
                    ),
                  ),
                  //Download Log

                  isDownloadLog
                      ? LinearProgressIndicator(value: downloadLogProgress)
                      : Container(),

                  Padding(
                    padding: const EdgeInsets.all(10.0),
                    child: Row(
                      children: [
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: TextField(
                              controller: _startIdxController,
                              decoration: const InputDecoration(
                                labelText: 'Start Index',
                                border: OutlineInputBorder(),
                              ),
                              keyboardType: TextInputType.number,
                            ),
                          ),
                        ),
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: TextField(
                              controller: _endIdxController,
                              decoration: const InputDecoration(
                                labelText: 'End Index',
                                border: OutlineInputBorder(),
                              ),
                              keyboardType: TextInputType.number,
                            ),
                          ),
                        ),

                        ElevatedButton(
                          onPressed: (){
                            startDownloadingLog();
                          },
                          child: Text('Download'),
                        ),
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