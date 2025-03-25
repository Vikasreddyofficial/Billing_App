import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'inventory_screen.dart';
import 'NewBillScreen.dart';
import 'current_bill_screen.dart';
import 'settings_screen.dart';
import 'providers/bill_provider.dart'; // Adjust path as needed

class BillingScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('బిల్లింగ్ యాప్')), // "Billing App" in Telugu
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => NewBillScreen()),
                );
              },
              child: Text("కొత్త బిల్లు"), // "New Bill" in Telugu
            ),
            SizedBox(height: 10),
            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => CurrentBillScreen()),
                );
              },
              child: Text("ప్రస్తుత బిల్లు"), // "Current Bill" in Telugu
            ),
            SizedBox(height: 10),
            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => InventoryScreen()),
                );
              },
              child: Text("స్టాక్"), // "Inventory" in Telugu
            ),
            SizedBox(height: 10),
            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => SettingsScreen()),
                );
              },
              child: Text("సెట్టింగ్స్"), // "Settings" in Telugu
            ),
            SizedBox(height: 10),
            ElevatedButton(
              onPressed: () {
                final billProvider = Provider.of<BillProvider>(context, listen: false);
                billProvider.clearBill();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('బిల్లు క్లియర్ చేయబడింది')), // "Bill cleared" in Telugu
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red, // Red to indicate clearing action
              ),
              child: Text("బిల్లు క్లియర్", style: TextStyle(color: Colors.white)), // "Clear Bill" in Telugu
            ),
          ],
        ),
      ),
    );
  }
}