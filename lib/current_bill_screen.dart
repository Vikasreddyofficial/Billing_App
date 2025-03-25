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
  int _billNumber = 1;
  String? _lastBillMonth;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _captureBillAsImage());
    _loadPrinterDetails();
    _loadBillNumber();
  }

  Future<void> _loadPrinterDetails() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _printerName = prefs.getString('printerName');
      _printerAddress = prefs.getString('printerAddress');
    });
  }

  Future<void> _loadBillNumber() async {
    final prefs = await SharedPreferences.getInstance();
    final currentMonth = DateTime.now().month.toString();
    _lastBillMonth = prefs.getString('lastBillMonth');
    if (_lastBillMonth != currentMonth) {
      _billNumber = 1;
      await prefs.setInt('billNumber', _billNumber);
      await prefs.setString('lastBillMonth', currentMonth);
    } else {
      _billNumber = prefs.getInt('billNumber') ?? 1;
    }
    setState(() {});
  }

  Future<void> _incrementBillNumber() async {
    final prefs = await SharedPreferences.getInstance();
    _billNumber++;
    await prefs.setInt('billNumber', _billNumber);
    await prefs.setString('lastBillMonth', DateTime.now().month.toString());
    setState(() {});
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
      _selectedDevice = BluetoothDevice(remoteId: DeviceIdentifier(_printerAddress!));
      await _selectedDevice!.connect();

      final billProvider = Provider.of<BillProvider>(context, listen: false);
      List<Map<String, dynamic>> selectedItems = billProvider.selectedItems;
      double totalAmount = selectedItems.fold(0.0, (sum, item) {
        return sum + (item['price'] * item['quantity']);
      });

      StringBuffer receipt = StringBuffer();
      // Targeting 24 characters per line for 50mm paper
      receipt.writeln('కొంకుదురు రెడ్డి క్లాత్'); // 17 chars
      receipt.writeln('గోల్లల మామిడాడ'); // 12 chars
      receipt.writeln('పిన్: 533344'); // 11 chars
      receipt.writeln('PH: 9849819619'); // 13 chars
      receipt.writeln('-' * 24); // 24-char line
      receipt.writeln('Bill No: $_billNumber  ${_getFormattedDate()}'.substring(0, 24));
      receipt.writeln('-' * 24);
      receipt.writeln('Item      Qty Rate Total'); // 23 chars
      receipt.writeln('-' * 24);

      for (var item in selectedItems) {
        String itemLine = '${item['itemName'].toString().padRight(10).substring(0, 10)} '
            '${item['quantity'].toString().padRight(3)} '
            '₹${item['price'].toStringAsFixed(0).padRight(5)} '
            '₹${(item['price'] * item['quantity']).toStringAsFixed(0)}';
        receipt.writeln(itemLine.substring(0, 24)); // Truncate to 24 chars
      }

      receipt.writeln('-' * 24);
      receipt.writeln('TOTAL     ₹${totalAmount.toStringAsFixed(0)}'.padRight(24));
      receipt.writeln('ధన్యవాదాలు! Thank You!'); // 22 chars
      receipt.writeln('\n\n\n');

      List<int> bytes = receipt.toString().codeUnits;
      await _sendPrintData(_selectedDevice!, bytes);

      await _incrementBillNumber();
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
        // ESC/POS initialization for consistency
        List<int> initPrinter = [0x1B, 0x40]; // ESC @ - Initialize printer
        await char.write(initPrinter);
        await char.write(data);
        break;
      }
    }
  }

  Future<void> _clearBill(BuildContext context) async {
    bool? confirm = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('బిల్లు క్లియర్ చేయాలా?'),
        content: Text('ఇది ప్రస్తుత బిల్లులోని అన్ని ఐటెమ్‌లను తొలగిస్తుంది.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('రద్దు'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('అవును'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final billProvider = Provider.of<BillProvider>(context, listen: false);
      billProvider.clearBill();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('బిల్లు క్లియర్ చేయబడింది')),
      );
      await _captureBillAsImage();
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
      appBar: AppBar(
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text("ప్రస్తుత బిల్లు"),
            Text("Bill No: $_billNumber", style: TextStyle(fontSize: 16)),
          ],
        ),
      ),
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
                  Text("కొంకుదురు రెడ్డి క్లాత్",
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  Text("గోల్లల మామిడాడ", style: TextStyle(fontSize: 12)),
                  Text("పిన్: 533344", style: TextStyle(fontSize: 12)),
                  SizedBox(height: 5),
                  Text("PH: 9849819619",
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  Divider(thickness: 0.5),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text("Bill No: $_billNumber",
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
                          child: Text("Total",
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
                            child: Text("${item['itemName']}".substring(0, item['itemName'].length > 10 ? 10 : item['itemName'].length),
                                style: TextStyle(fontSize: 12))),
                        Expanded(
                            flex: 1,
                            child: Text("${item['quantity']}",
                                style: TextStyle(fontSize: 12))),
                        Expanded(
                            flex: 2,
                            child: Text("₹${item['price'].toStringAsFixed(0)}",
                                style: TextStyle(fontSize: 12))),
                        Expanded(
                            flex: 2,
                            child: Text(
                                "₹${(item['price'] * item['quantity']).toStringAsFixed(0)}",
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
                      Text("₹${totalAmount.toStringAsFixed(0)}",
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
                    ElevatedButton.icon(
                      onPressed: selectedItems.isEmpty ? null : () => _clearBill(context),
                      icon: Icon(Icons.delete),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                      ),
                      label: Text("బిల్లు క్లియర్", style: TextStyle(fontSize: 18, color: Colors.white)),
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
    return "${now.day}-${now.month}-${now.year} ${now.hour}:${now.minute.toString().padLeft(2, '0')}";
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