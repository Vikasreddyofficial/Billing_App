import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'providers/bill_provider.dart';
import 'firebase_service.dart';
import 'current_bill_screen.dart';

class NewBillScreen extends StatefulWidget {
  @override
  _NewBillScreenState createState() => _NewBillScreenState();
}

class _NewBillScreenState extends State<NewBillScreen> {
  final FirebaseService _firebaseService = FirebaseService();
  final Map<String, TextEditingController> priceControllers = {};
  final Map<String, int> tempQuantities = {}; // Temporary quantity map

  @override
  Widget build(BuildContext context) {
    final billProvider = Provider.of<BillProvider>(context);

    return Scaffold(
      appBar: AppBar(title: Text("కొత్త బిల్లు")),
      body: StreamBuilder<QuerySnapshot>(
        stream: _firebaseService.getCategories(),
        builder: (context, categorySnapshot) {
          if (!categorySnapshot.hasData) {
            return Center(child: CircularProgressIndicator());
          }
          var categories = categorySnapshot.data!.docs;

          return ListView.builder(
            itemCount: categories.length,
            itemBuilder: (context, categoryIndex) {
              var categoryDoc = categories[categoryIndex];
              String categoryName = categoryDoc.id;

              return ExpansionTile(
                title: Text(
                  categoryName,
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.blue),
                ),
                children: [
                  StreamBuilder<QuerySnapshot>(
                    stream: _firebaseService.getItems(categoryName),
                    builder: (context, itemSnapshot) {
                      if (!itemSnapshot.hasData) {
                        return Center(child: CircularProgressIndicator());
                      }
                      var items = itemSnapshot.data!.docs;

                      return Column(
                        children: items.map((item) {
                          String itemId = item.id;
                          String itemName = item['name'];

                          int quantity = tempQuantities[itemId] ?? 0;
                          double? itemPrice = double.tryParse(priceControllers[itemId]?.text ?? '');

                          priceControllers.putIfAbsent(
                            itemId,
                                () => TextEditingController(
                              text: itemPrice != null ? itemPrice.toStringAsFixed(2) : "",
                            ),
                          );

                          return Card(
                            margin: EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            child: Column(
                              children: [
                                ListTile(
                                  title: Text(
                                    itemName,
                                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                                  ),
                                  subtitle: TextField(
                                    controller: priceControllers[itemId],
                                    keyboardType: TextInputType.number,
                                    decoration: InputDecoration(
                                      labelText: "Enter Price",
                                      border: OutlineInputBorder(),
                                    ),
                                  ),
                                  trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        icon: Icon(Icons.remove, color: Colors.red),
                                        onPressed: () {
                                          setState(() {
                                            if (tempQuantities[itemId] != null && tempQuantities[itemId]! > 0) {
                                              tempQuantities[itemId] = tempQuantities[itemId]! - 1;
                                            }
                                          });
                                        },
                                      ),
                                      Text(
                                        "${tempQuantities[itemId] ?? 0}",
                                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                                      ),
                                      IconButton(
                                        icon: Icon(Icons.add, color: Colors.green),
                                        onPressed: () {
                                          setState(() {
                                            tempQuantities[itemId] = (tempQuantities[itemId] ?? 0) + 1;
                                          });
                                        },
                                      ),
                                    ],
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.all(8.0),
                                  child: ElevatedButton(
                                    onPressed: () {
                                      double price = double.tryParse(priceControllers[itemId]!.text) ?? 0.0;
                                      int quantity = tempQuantities[itemId] ?? 0;

                                      if (price <= 0 || quantity <= 0) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(content: Text("Enter valid price & quantity")),
                                        );
                                        return;
                                      }

                                      // ✅ Add item as a separate entry
                                      billProvider.addItem(itemId, itemName, price, quantity);

                                      // ✅ Reset inputs (ONLY in NewBillScreen)
                                      setState(() {
                                        tempQuantities[itemId] = 0;
                                        priceControllers[itemId]!.clear();
                                      });
                                    },
                                    child: Text("Add"),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      );
                    },
                  ),
                ],
              );
            },
          );
        },
      ),
      bottomNavigationBar: Padding(
        padding: EdgeInsets.all(10),
        child: ElevatedButton(
          onPressed: () {
            Navigator.push(context, MaterialPageRoute(builder: (context) => CurrentBillScreen()));
          },
          child: Text("ప్రస్తుత బిల్ చూడండి", style: TextStyle(fontSize: 18)),
        ),
      ),
    );
  }
}
