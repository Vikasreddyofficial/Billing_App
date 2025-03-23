import 'package:flutter/material.dart';

class BillProvider extends ChangeNotifier {
  List<Map<String, dynamic>> selectedItems = []; // Stores multiple entries

  void addItem(String itemId, String itemName, double price, int quantity) {
    if (quantity > 0 && price > 0) {
      selectedItems.add({
        'itemId': itemId,
        'itemName': itemName,
        'price': price,
        'quantity': quantity,
      });
      notifyListeners();
    }
  }

  void removeEntireItem(int index) {
    if (index >= 0 && index < selectedItems.length) {
      selectedItems.removeAt(index);
      notifyListeners();
    }
  }

  void updateUserPrice(int index, double price) {
    if (index >= 0 && index < selectedItems.length) {
      selectedItems[index]['price'] = price;
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
    notifyListeners();
  }
}
