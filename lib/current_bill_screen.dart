import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:provider/provider.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'dart:typed_data';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'providers/bill_provider.dart';

class CurrentBillScreen extends StatefulWidget {
  @override
  _CurrentBillScreenState createState() => _CurrentBillScreenState();
}

class _CurrentBillScreenState extends State<CurrentBillScreen> {
  GlobalKey _billKey = GlobalKey();
  File? _billImage;
  bool _isPrinting = false;
  String? _printerName;
  String? _printerAddress;
  BluetoothDevice? _selectedDevice;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _captureBillAsImage());
    _loadPrinterDetails();
  }

  Future<void> _loadPrinterDetails() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _printerName = prefs.getString('printerName');
      _printerAddress = prefs.getString('printerAddress');
    });
  }

  Future<void> _captureBillAsImage() async {
    try {
      RenderRepaintBoundary boundary =
      _billKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
      ui.Image image = await boundary.toImage(pixelRatio: 3.0);
      ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData != null) {
        Uint8List pngBytes = byteData.buffer.asUint8List();
        final directory = await getApplicationDocumentsDirectory();
        File file = File('${directory.path}/bill_preview.png');
        await file.writeAsBytes(pngBytes);
        setState(() {
          _billImage = file;
        });
      }
    } catch (e) {
      print('Error capturing bill as image: $e');
    }
  }

  Future<void> _printBill(BuildContext context) async {
    if (_printerAddress == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('ప్రింటర్ కనెక్ట్ చేయబడలేదు. సెట్టింగ్స్‌లో కనెక్ట్ చేయండి'),
          action: SnackBarAction(
            label: 'సెట్టింగ్స్',
            onPressed: () {
              Navigator.pushNamed(context, '/settings').then((_) {
                _loadPrinterDetails();
              });
            },
          ),
        ),
      );
      return;
    }

    setState(() {
      _isPrinting = true;
    });

    try {
      // Correctly instantiate BluetoothDevice with remoteId
      _selectedDevice = BluetoothDevice(remoteId: DeviceIdentifier(_printerAddress!));
      await _selectedDevice!.connect();

      final billProvider = Provider.of<BillProvider>(context, listen: false);
      List<Map<String, dynamic>> selectedItems = billProvider.selectedItems;
      double totalAmount = selectedItems.fold(0.0, (sum, item) {
        return sum + (item['price'] * item['quantity']);
      });

      StringBuffer receipt = StringBuffer();
      receipt.writeln('కొంకుదురు రెడ్డి క్లాత్ షాప్'.padLeft(16));
      receipt.writeln('గోల్లల మామిడాడ'.padLeft(16));
      receipt.writeln('పిన్ కోడ్: 533344'.padLeft(16));
      receipt.writeln('PHONE: 9849819619'.padLeft(16));
      receipt.writeln('--------------------------------');
      receipt.writeln('Bill No: IN-15  Date: ${_getFormattedDate()}');
      receipt.writeln('--------------------------------');
      receipt.writeln('Item                Qty  Rate  Price');
      receipt.writeln('--------------------------------');

      for (var item in selectedItems) {
        receipt.writeln(
            '${item['itemName'].toString().padRight(20)} ${item['quantity'].toString().padRight(4)} ₹${item['price'].toStringAsFixed(2)} ₹${(item['price'] * item['quantity']).toStringAsFixed(2)}');
      }

      receipt.writeln('--------------------------------');
      receipt.writeln('TOTAL                    ₹${totalAmount.toStringAsFixed(2)}');
      receipt.writeln('ధన్యవాదాలు! Thank You!'.padLeft(16));
      receipt.writeln('\n\n\n');

      List<int> bytes = receipt.toString().codeUnits;
      await _sendPrintData(_selectedDevice!, bytes);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('బిల్లు ప్రింట్ అయింది')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('ప్రింటింగ్ విఫలమైంది: $e')),
      );
    } finally {
      setState(() {
        _isPrinting = false;
      });
      if (_selectedDevice != null) {
        await _selectedDevice!.disconnect();
      }
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
    final billProvider = Provider.of<BillProvider>(context);
    List<Map<String, dynamic>> selectedItems = billProvider.selectedItems;

    double totalAmount = selectedItems.fold(0.0, (sum, item) {
      return sum + (item['price'] * item['quantity']);
    });

    return Scaffold(
      appBar: AppBar(title: Text("ప్రస్తుత బిల్లు")),
      body: Column(
        children: [
          RepaintBoundary(
            key: _billKey,
            child: Container(
              color: Colors.white,
              padding: EdgeInsets.all(8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text("కొంకుదురు రెడ్డి క్లాత్ షాప్",
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  Text("గోల్లల మామిడాడ", style: TextStyle(fontSize: 12)),
                  Text("పిన్ కోడ్: 533344", style: TextStyle(fontSize: 12)),
                  SizedBox(height: 5),
                  Text("PHONE: 9849819619",
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  Divider(thickness: 0.5),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text("Bill No: IN-15",
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      Text("Date: ${_getFormattedDate()}",
                          style: TextStyle(fontSize: 12)),
                    ],
                  ),
                  Divider(thickness: 0.5),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                          flex: 3,
                          child: Text("Item",
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold))),
                      Expanded(
                          flex: 1,
                          child: Text("Qty",
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold))),
                      Expanded(
                          flex: 2,
                          child: Text("Rate",
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold))),
                      Expanded(
                          flex: 2,
                          child: Text("Price",
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold))),
                    ],
                  ),
                  Divider(thickness: 0.5),
                  ...selectedItems.map((item) {
                    return Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                            flex: 3,
                            child: Text("${item['itemName']}",
                                style: TextStyle(fontSize: 12))),
                        Expanded(
                            flex: 1,
                            child: Text("${item['quantity']}",
                                style: TextStyle(fontSize: 12))),
                        Expanded(
                            flex: 2,
                            child: Text("₹${item['price'].toStringAsFixed(2)}",
                                style: TextStyle(fontSize: 12))),
                        Expanded(
                            flex: 2,
                            child: Text(
                                "₹${(item['price'] * item['quantity']).toStringAsFixed(2)}",
                                style: TextStyle(fontSize: 12))),
                      ],
                    );
                  }).toList(),
                  Divider(thickness: 0.5),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text("TOTAL",
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                      Text("₹${totalAmount.toStringAsFixed(2)}",
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  SizedBox(height: 5),
                  Text("ధన్యవాదాలు! Thank You!",
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          ),
          SizedBox(height: 20),
          _billImage != null
              ? Image.file(_billImage!, width: 250)
              : Text("Bill preview will appear here"),
          Padding(
            padding: EdgeInsets.all(10),
            child: Column(
              children: [
                SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    ElevatedButton.icon(
                      onPressed: _captureBillAsImage,
                      icon: Icon(Icons.visibility),
                      label: Text("బిల్ ప్రివ్యూ", style: TextStyle(fontSize: 18)),
                    ),
                    ElevatedButton.icon(
                      onPressed: _isPrinting ? null : () => _printBill(context),
                      icon: _isPrinting
                          ? SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2))
                          : Icon(Icons.print),
                      label: Text(_isPrinting ? "ప్రింటింగ్..." : "ప్రింట్ బిల్లు",
                          style: TextStyle(fontSize: 18)),
                    ),
                  ],
                ),
                SizedBox(height: 10),
                if (_printerName != null)
                  Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.check_circle, color: Colors.green, size: 16),
                        SizedBox(width: 8),
                        Text('ప్రింటర్: $_printerName',
                            style: TextStyle(color: Colors.green)),
                      ],
                    ),
                  )
                else
                  TextButton.icon(
                    onPressed: () {
                      Navigator.pushNamed(context, '/settings').then((_) {
                        _loadPrinterDetails();
                      });
                    },
                    icon: Icon(Icons.print, size: 16),
                    label: Text('ప్రింటర్ కనెక్ట్ చేయడానికి క్లిక్ చేయండి'),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _getFormattedDate() {
    final DateTime now = DateTime.now();
    return "${now.day}-${_getMonthName(now.month)}-${now.year} ${now.hour}:${now.minute.toString().padLeft(2, '0')}";
  }

  String _getMonthName(int month) {
    const monthNames = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec'
    ];
    return monthNames[month - 1];
  }

  @override
  void dispose() {
    if (_selectedDevice != null) {
      _selectedDevice!.disconnect();
    }
    FlutterBluePlus.stopScan();
    super.dispose();
  }
}