import 'package:flutter/material.dart';
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsScreen extends StatefulWidget {
  @override
  _SettingsScreenState createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  // Bluetooth state
  BluetoothState _bluetoothState = BluetoothState.UNKNOWN;
  List<BluetoothDevice> _devices = [];
  BluetoothDevice? _selectedDevice;
  bool _isScanning = false;
  String? _connectedDeviceName;
  String? _connectedDeviceAddress;

  @override
  void initState() {
    super.initState();
    // Initialize Bluetooth
    FlutterBluetoothSerial.instance.state.then((state) {
      setState(() {
        _bluetoothState = state;
      });
    });

    // Listen for Bluetooth state changes
    FlutterBluetoothSerial.instance.onStateChanged().listen((state) {
      setState(() {
        _bluetoothState = state;
      });
    });

    // Load saved printer if available
    _loadSavedPrinter();
  }

  // Load previously connected printer from SharedPreferences
  Future<void> _loadSavedPrinter() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _connectedDeviceName = prefs.getString('printerName');
      _connectedDeviceAddress = prefs.getString('printerAddress');
    });
  }

  // Save printer details to SharedPreferences
  Future<void> _savePrinter(BluetoothDevice device) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('printerName', device.name ?? 'Unknown');
    await prefs.setString('printerAddress', device.address);

    setState(() {
      _connectedDeviceName = device.name;
      _connectedDeviceAddress = device.address;
    });
  }

  // Forget saved printer
  Future<void> _forgetPrinter() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('printerName');
    await prefs.remove('printerAddress');

    setState(() {
      _connectedDeviceName = null;
      _connectedDeviceAddress = null;
      _selectedDevice = null;
    });

    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('ప్రింటర్ తొలగించబడింది'))
    );
  }

  // Start scanning for Bluetooth devices
  void _startScan() async {
    setState(() {
      _devices.clear();
      _isScanning = true;
    });

    // Check if Bluetooth is enabled
    if (_bluetoothState != BluetoothState.STATE_ON) {
      await FlutterBluetoothSerial.instance.requestEnable();
    }

    // Get paired devices
    List<BluetoothDevice> bondedDevices = await FlutterBluetoothSerial.instance.getBondedDevices();

    setState(() {
      _devices = bondedDevices;
      _isScanning = false;
    });

    // If no devices found
    if (_devices.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('కనెక్ట్ చేయబడిన పరికరాలు కనుగొనబడలేదు. ముందుగా బ్లూటూత్ సెట్టింగ్స్‌లో పేర్ చేయండి'))
      );
    }
  }

  // Connect to the selected printer
  Future<void> _connectToPrinter(BluetoothDevice device) async {
    try {
      // In a real app, you would establish a connection here
      // For demo purposes, we'll just save the device info
      await _savePrinter(device);

      setState(() {
        _selectedDevice = device;
      });

      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('ప్రింటర్‌కు కనెక్ట్ చేయబడింది: ${device.name}'))
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('ప్రింటర్‌కు కనెక్ట్ చేయడంలో విఫలమైంది: $e'))
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("సెట్టింగ్స్")), // "Settings" in Telugu
      body: Padding(
        padding: EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Bluetooth Status Section
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
                            'బ్లూటూత్ స్టేటస్',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)
                        ),
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: _bluetoothState == BluetoothState.STATE_ON
                                ? Colors.green
                                : Colors.red,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            _bluetoothState == BluetoothState.STATE_ON ? 'ఆన్' : 'ఆఫ్',
                            style: TextStyle(color: Colors.white),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: _bluetoothState == BluetoothState.STATE_ON
                          ? () async {
                        await FlutterBluetoothSerial.instance.requestDisable();
                      }
                          : () async {
                        await FlutterBluetoothSerial.instance.requestEnable();
                      },
                      icon: Icon(_bluetoothState == BluetoothState.STATE_ON
                          ? Icons.bluetooth_disabled
                          : Icons.bluetooth),
                      label: Text(_bluetoothState == BluetoothState.STATE_ON
                          ? 'బ్లూటూత్ ఆఫ్ చేయండి'
                          : 'బ్లూటూత్ ఆన్ చేయండి'),
                    ),
                  ],
                ),
              ),
            ),

            SizedBox(height: 16),

            // Thermal Printer Section
            Card(
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                        'థర్మల్ ప్రింటర్',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)
                    ),
                    SizedBox(height: 8),

                    // Connected printer info
                    if (_connectedDeviceName != null)
                      Padding(
                        padding: EdgeInsets.symmetric(vertical: 8),
                        child: Row(
                          children: [
                            Icon(Icons.check_circle, color: Colors.green),
                            SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('కనెక్ట్ చేయబడిన ప్రింటర్: $_connectedDeviceName'),
                                  Text('MAC: $_connectedDeviceAddress',
                                      style: TextStyle(fontSize: 12, color: Colors.grey)),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: Icon(Icons.delete_outline, color: Colors.red),
                              onPressed: _forgetPrinter,
                              tooltip: 'ప్రింటర్‌ను తొలగించండి',
                            ),
                          ],
                        ),
                      ),

                    SizedBox(height: 16),

                    // Scan button
                    ElevatedButton.icon(
                      onPressed: _isScanning ? null : _startScan,
                      icon: _isScanning
                          ? SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2)
                      )
                          : Icon(Icons.search),
                      label: Text(_isScanning
                          ? 'ప్రింటర్ల కోసం శోధిస్తోంది...'
                          : 'ప్రింటర్ల కోసం శోధించండి'),
                    ),
                  ],
                ),
              ),
            ),

            SizedBox(height: 16),

            // Discovered devices
            if (_devices.isNotEmpty)
              Expanded(
                child: Card(
                  child: Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                            'అందుబాటులో ఉన్న పరికరాలు',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)
                        ),
                        SizedBox(height: 8),
                        Expanded(
                          child: ListView.builder(
                            itemCount: _devices.length,
                            itemBuilder: (context, index) {
                              BluetoothDevice device = _devices[index];
                              bool isSelected = _selectedDevice?.address == device.address;
                              bool isSaved = _connectedDeviceAddress == device.address;

                              return ListTile(
                                leading: Icon(
                                  Icons.print,
                                  color: isSaved ? Colors.green : Colors.grey,
                                ),
                                title: Text(device.name ?? 'Unknown Device'),
                                subtitle: Text(device.address),
                                trailing: ElevatedButton(
                                  onPressed: isSaved
                                      ? null
                                      : () => _connectToPrinter(device),
                                  child: Text(isSaved ? 'కనెక్ట్ చేయబడింది' : 'కనెక్ట్'),
                                  style: isSaved
                                      ? ElevatedButton.styleFrom(
                                    backgroundColor: Colors.green,
                                    foregroundColor: Colors.white,
                                  )
                                      : null,
                                ),
                                selected: isSelected,
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}