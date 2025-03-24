import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:permission_handler/permission_handler.dart';

class SettingsScreen extends StatefulWidget {
  @override
  _SettingsScreenState createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  List<ScanResult> _devices = [];
  BluetoothDevice? _selectedDevice;
  bool _isScanning = false;
  String? _connectedDeviceName;
  String? _connectedDeviceAddress;
  bool _isConnected = false;

  @override
  void initState() {
    super.initState();
    _requestPermissions();
    _loadSavedPrinter();
  }

  Future<void> _requestPermissions() async {
    await [
      Permission.bluetooth,
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.location,
    ].request();
  }

  Future<void> _loadSavedPrinter() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _connectedDeviceName = prefs.getString('printerName');
      _connectedDeviceAddress = prefs.getString('printerAddress');
    });
    if (_connectedDeviceAddress != null) {
      await _startScan(silent: true);
    }
  }

  Future<void> _savePrinter(BluetoothDevice device) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('printerName', device.name ?? 'Unknown');
    await prefs.setString('printerAddress', device.id.id);
    setState(() {
      _connectedDeviceName = device.name;
      _connectedDeviceAddress = device.id.id;
      _isConnected = true;
    });
  }

  Future<void> _forgetPrinter() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('printerName');
    await prefs.remove('printerAddress');
    if (_selectedDevice != null) {
      await _selectedDevice!.disconnect();
    }
    setState(() {
      _connectedDeviceName = null;
      _connectedDeviceAddress = null;
      _selectedDevice = null;
      _isConnected = false;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('ప్రింటర్ తొలగించబడింది')),
    );
  }

  Future<void> _startScan({bool silent = false}) async {
    setState(() {
      _devices.clear();
      _isScanning = true;
    });

    try {
      // Start scanning
      await FlutterBluePlus.startScan(timeout: Duration(seconds: 4));

      // Listen to scan results
      FlutterBluePlus.scanResults.listen((results) {
        setState(() {
          _devices = results;
          if (_connectedDeviceAddress != null) {
            try {
              _selectedDevice = _devices
                  .firstWhere((r) => r.device.id.id == _connectedDeviceAddress)
                  .device;
              _isConnected = true;
            } catch (e) {
              _selectedDevice = null;
              _isConnected = false;
              if (!silent) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('సేవ్ చేసిన ప్రింటర్ కనుగొనబడలేదు')),
                );
              }
            }
          }
        });

        if (_devices.isEmpty && !silent) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                  'కనెక్ట్ చేయబడిన పరికరాలు కనుగొనబడలేదు. ముందుగా బ్లూటూత్ సెట్టింగ్స్‌లో పేర్ చేయండి'),
            ),
          );
        }
      });

      // Wait for scan to complete
      await Future.delayed(Duration(seconds: 4));
      await FlutterBluePlus.stopScan();
      setState(() {
        _isScanning = false;
      });
    } catch (e) {
      setState(() {
        _isScanning = false;
      });
      if (!silent) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('స్కానింగ్ విఫలమైంది: $e')),
        );
      }
    }
  }

  Future<void> _connectToPrinter(BluetoothDevice device) async {
    try {
      await device.connect();
      List<int> testPrint = 'Test Connection\n\n\n'.codeUnits;
      await _sendPrintData(device, testPrint);
      await _savePrinter(device);
      setState(() {
        _selectedDevice = device;
        _isConnected = true;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('ప్రింటర్‌కు కనెక్ట్ చేయబడింది: ${device.name}')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('ప్రింటర్‌కు కనెక్ట్ చేయడంలో విఫలమైంది: $e')),
      );
    }
  }

  Future<void> _disconnectPrinter() async {
    try {
      if (_selectedDevice != null) {
        await _selectedDevice!.disconnect();
      }
      setState(() {
        _isConnected = false;
        _selectedDevice = null;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('ప్రింటర్ నుండి డిస్కనెక్ట్ చేయబడింది')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('డిస్కనెక్ట్ విఫలమైంది: $e')),
      );
    }
  }

  Future<void> _sendPrintData(BluetoothDevice device, List<int> data) async {
    List<BluetoothService> services = await device.discoverServices();
    BluetoothService? printService;
    for (var service in services) {
      if (service.uuid.toString().startsWith('000018f0') || // Common printer service UUID
          service.uuid.toString().startsWith('00001101')) { // Serial Port Profile
        printService = service;
        break;
      }
    }
    if (printService == null) {
      throw Exception('No suitable printing service found');
    }
    for (var char in printService.characteristics) {
      if (char.properties.write || char.properties.writeWithoutResponse) {
        await char.write(data);
        break;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("సెట్టింగ్స్")),
      body: Padding(
        padding: EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'ప్రింటర్ స్టేటస్',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: _isConnected ? Colors.green : Colors.red,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            _isConnected ? 'కనెక్టెడ్' : 'డిస్కనెక్టెడ్',
                            style: TextStyle(color: Colors.white),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 8),
                    if (_connectedDeviceName != null)
                      Padding(
                        padding: EdgeInsets.only(top: 8.0),
                        child: Text('కనెక్టెడ్ ప్రింటర్: $_connectedDeviceName'),
                      ),
                    SizedBox(height: 8),
                    Row(
                      children: [
                        ElevatedButton.icon(
                          onPressed: _isConnected ? _disconnectPrinter : () => _startScan(),
                          icon: Icon(_isConnected ? Icons.print_disabled : Icons.print),
                          label: Text(_isConnected ? 'డిస్కనెక్ట్ ప్రింటర్' : 'కనెక్ట్ ప్రింటర్'),
                        ),
                        SizedBox(width: 8),
                        if (_connectedDeviceName != null)
                          TextButton.icon(
                            onPressed: _forgetPrinter,
                            icon: Icon(Icons.delete_outline),
                            label: Text('ప్రింటర్ మర్చిపో'),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            if (_devices.isNotEmpty && !_isConnected)
              Expanded(
                child: Card(
                  child: Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'లభ్యమైన పరికరాలు',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        SizedBox(height: 8),
                        Expanded(
                          child: ListView.builder(
                            itemCount: _devices.length,
                            itemBuilder: (context, index) {
                              return ListTile(
                                title: Text(_devices[index].device.name ?? 'Unknown Device'),
                                subtitle: Text(_devices[index].device.id.id),
                                trailing: ElevatedButton(
                                  child: Text('కనెక్ట్'),
                                  onPressed: () => _connectToPrinter(_devices[index].device),
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            if (_isScanning)
              Center(
                child: Column(
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 8),
                    Text('పరికరాల కోసం స్కానింగ్...'),
                  ],
                ),
              ),
            if (_devices.isEmpty && !_isScanning && !_isConnected)
              Padding(
                padding: EdgeInsets.symmetric(vertical: 16.0),
                child: Center(
                  child: Column(
                    children: [
                      Text('పేర్ చేసిన పరికరాలు కనుగొనబడలేదు'),
                      SizedBox(height: 8),
                      Text('దయచేసి ముందుగా బ్లూటూత్ సెట్టింగ్‌లో మీ ప్రింటర్‌ను పేర్ చేయండి'),
                      SizedBox(height: 16),
                      ElevatedButton.icon(
                        onPressed: _startScan,
                        icon: Icon(Icons.refresh),
                        label: Text('మళ్ళీ స్కాన్ చేయండి'),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    FlutterBluePlus.stopScan();
    super.dispose();
  }
}