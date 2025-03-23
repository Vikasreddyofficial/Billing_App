import 'package:flutter/material.dart';
import 'inventory_screen.dart';
import 'NewBillScreen.dart'; // Updated to correct file name
import 'current_bill_screen.dart'; // Ensure you have this file
import 'settings_screen.dart'; // Make sure you have this file

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
          ],
        ),
      ),
    );
  }
}
