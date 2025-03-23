import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:provider/provider.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:esc_pos_bluetooth/esc_pos_bluetooth.dart';
import 'package:esc_pos_utils/esc_pos_utils.dart';
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
  PrinterBluetoothManager? _printerManager;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _captureBillAsImage());
    _loadPrinterDetails();
    _initPrinterManager();
  }

  Future<void> _loadPrinterDetails() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _printerName = prefs.getString('printerName');
      _printerAddress = prefs.getString('printerAddress');
    });
  }

  void _initPrinterManager() {
    _printerManager = PrinterBluetoothManager();
  }

  Future<void> _captureBillAsImage() async {
    RenderRepaintBoundary boundary =
    _billKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
    ui.Image image = await boundary.toImage(pixelRatio: 3.0);
    ByteData? byteData =
    await image.toByteData(format: ui.ImageByteFormat.png);
    Uint8List pngBytes = byteData!.buffer.asUint8List();

    // Save to file
    final directory = await getApplicationDocumentsDirectory();
    File file = File('${directory.path}/bill_preview.png');
    await file.writeAsBytes(pngBytes);

    setState(() {
      _billImage = file;
    });
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
      final BluetoothDevice device = BluetoothDevice(
        name: _printerName,
        address: _printerAddress!,
      );

      _printerManager!.selectPrinter(device as PrinterBluetooth);

      // Get profile for printer
      final profile = await CapabilityProfile.load();

      // Generate ESC/POS command
      final generator = Generator(PaperSize.mm58, profile);
      List<int> bytes = [];

      // Get bill data
      final billProvider = Provider.of<BillProvider>(context, listen: false);
      List<Map<String, dynamic>> selectedItems = billProvider.selectedItems;
      double totalAmount = selectedItems.fold(0.0, (sum, item) {
        return sum + (item['price'] * item['quantity']);
      });

      // Add bill header
      bytes += generator.text('కొంకుదురు రెడ్డి క్లాత్ షాప్',
          styles: PosStyles(align: PosAlign.center, bold: true));
      bytes += generator.text('గోల్లల మామిడాడ',
          styles: PosStyles(align: PosAlign.center));
      bytes += generator.text('పిన్ కోడ్: 533344',
          styles: PosStyles(align: PosAlign.center));
      bytes += generator.text('PHONE: 9849819619',
          styles: PosStyles(align: PosAlign.center, bold: true));
      bytes += generator.hr();

      // Bill number and date
      bytes += generator.row([
        PosColumn(
          text: 'Bill No: IN-15',
          width: 6,
          styles: PosStyles(bold: true),
        ),
        PosColumn(
          text: 'Date: ${_getFormattedDate()}',
          width: 6,
          styles: PosStyles(align: PosAlign.right),
        ),
      ]);
      bytes += generator.hr();

      // Column headers
      bytes += generator.row([
        PosColumn(text: 'Item', width: 6, styles: PosStyles(bold: true)),
        PosColumn(text: 'Qty', width: 2, styles: PosStyles(bold: true, align: PosAlign.right)),
        PosColumn(text: 'Price', width: 4, styles: PosStyles(bold: true, align: PosAlign.right)),
      ]);
      bytes += generator.hr();

      // Items
      for (var item in selectedItems) {
        bytes += generator.row([
          PosColumn(text: item['itemName'], width: 6),
          PosColumn(
              text: item['quantity'].toString(),
              width: 2,
              styles: PosStyles(align: PosAlign.right)
          ),
          PosColumn(
            text: '₹${(item['price'] * item['quantity']).toStringAsFixed(2)}',
            width: 4,
            styles: PosStyles(align: PosAlign.right),
          ),
        ]);
      }

      bytes += generator.hr();

      // Total
      bytes += generator.row([
        PosColumn(
          text: 'TOTAL',
          width: 6,
          styles: PosStyles(bold: true),
        ),
        PosColumn(
          text: '₹${totalAmount.toStringAsFixed(2)}',
          width: 6,
          styles: PosStyles(bold: true, align: PosAlign.right),
        ),
      ]);

      // Thank you message
      bytes += generator.text('ధన్యవాదాలు! Thank You!',
          styles: PosStyles(align: PosAlign.center, bold: true));

      bytes += generator.cut();

      // Send to printer
      await _printerManager!.printTicket(bytes);

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
          // Bill Layout Inside RepaintBoundary
          RepaintBoundary(
            key: _billKey,
            child: Container(
              color: Colors.white,
              padding: EdgeInsets.all(8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Shop Name & Address
                  Text("కొంకుదురు రెడ్డి క్లాత్ షాప్",
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  Text("గోల్లల మామిడాడ", style: TextStyle(fontSize: 12)),
                  Text("పిన్ కోడ్: 533344", style: TextStyle(fontSize: 12)),
                  SizedBox(height: 5),
                  Text("PHONE: 9849819619",
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),

                  Divider(thickness: 0.5),

                  // Bill No & Date
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

                  // Table Headers
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(flex: 3, child: Text("Item", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold))),
                      Expanded(flex: 1, child: Text("Qty", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold))),
                      Expanded(flex: 2, child: Text("Rate", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold))),
                      Expanded(flex: 2, child: Text("Price", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold))),
                    ],
                  ),

                  Divider(thickness: 0.5),

                  // Item List
                  ...selectedItems.map((item) {
                    return Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(flex: 3, child: Text("${item['itemName']}", style: TextStyle(fontSize: 12))),
                        Expanded(flex: 1, child: Text("${item['quantity']}", style: TextStyle(fontSize: 12))),
                        Expanded(flex: 2, child: Text("₹${item['price'].toStringAsFixed(2)}", style: TextStyle(fontSize: 12))),
                        Expanded(flex: 2, child: Text("₹${(item['price'] * item['quantity']).toStringAsFixed(2)}", style: TextStyle(fontSize: 12))),
                      ],
                    );
                  }).toList(),

                  Divider(thickness: 0.5),

                  // Total Amount
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text("TOTAL", style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                      Text("₹${totalAmount.toStringAsFixed(2)}", style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                    ],
                  ),

                  SizedBox(height: 5),

                  // Thank You Message
                  Text("ధన్యవాదాలు! Thank You!", style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          ),

          SizedBox(height: 20),

          // Display Bill Preview
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
                          ? SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                          : Icon(Icons.print),
                      label: Text(_isPrinting ? "ప్రింటింగ్..." : "ప్రింట్ బిల్లు", style: TextStyle(fontSize: 18)),
                    ),
                  ],
                ),

                SizedBox(height: 10),

                // Printer status indicator
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
    return "${now.day}-${_getMonthName(now.month)}-${now.year} ${now.hour}:${now.minute}";
  }

  String _getMonthName(int month) {
    const monthNames = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return monthNames[month - 1];
  }

  @override
  void dispose() {
    _printerManager?.dispose();
    super.dispose();
  }
}

extension on PrinterBluetoothManager? {
  void dispose() {}
}