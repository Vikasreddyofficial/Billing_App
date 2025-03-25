import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class BillProvider extends ChangeNotifier {
  List<Map<String, dynamic>> selectedItems = []; // Stores multiple entries

  BillProvider() {
    _loadItems(); // Load items when the provider is initialized
  }

  void addItem(String itemId, String itemName, double price, int quantity) {
    if (quantity > 0 && price > 0) {
      selectedItems.add({
        'itemId': itemId,
        'itemName': itemName,
        'price': price,
        'quantity': quantity,
      });
      _saveItems(); // Save after adding
      notifyListeners();
    }
  }

  void removeEntireItem(int index) {
    if (index >= 0 && index < selectedItems.length) {
      selectedItems.removeAt(index);
      _saveItems(); // Save after removing
      notifyListeners();
    }
  }

  void updateUserPrice(int index, double price) {
    if (index >= 0 && index < selectedItems.length) {
      selectedItems[index]['price'] = price;
      _saveItems(); // Save after updating
      notifyListeners();
    }
  }

  double getItemPrice(int index) {
    if (index >= 0 && index < selectedItems.length) {
      return selectedItems[index]['price'];
    }
    return 0.0;
  }

  double getTotalAmount() {
    return selectedItems.fold(0.0, (sum, item) {
      return sum + (item['price'] * item['quantity']);
    });
  }

  void clearBill() {
    selectedItems.clear();
    _saveItems(); // Save after clearing (empties the persisted data)
    notifyListeners();
  }

  Future<void> _saveItems() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('billItems', jsonEncode(selectedItems));
  }

  Future<void> _loadItems() async {
    final prefs = await SharedPreferences.getInstance();
    final String? itemsString = prefs.getString('billItems');
    if (itemsString != null) {
      selectedItems = List<Map<String, dynamic>>.from(
        jsonDecode(itemsString).map((item) => Map<String, dynamic>.from(item)),
      );
      notifyListeners();
    }
  }
}