import 'package:cloud_firestore/cloud_firestore.dart';

class FirebaseService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Add a new category
  Future<void> addCategory(String categoryName) async {
    try {
      await _firestore.collection('categories').doc(categoryName).set({});
    } catch (e) {
      print("Error adding category: $e");
    }
  }

  // Get all categories
  Stream<QuerySnapshot> getCategories() {
    return _firestore.collection('categories').snapshots();
  }

  // Add an item inside a category
  Future<void> addItem(String category, String itemName, double price) async {
    try {
      await _firestore
          .collection('categories')
          .doc(category)
          .collection('items')
          .add({'name': itemName, 'price': price});
    } catch (e) {
      print("Error adding item: $e");
    }
  }

  // Get items for a category
  Stream<QuerySnapshot> getItems(String category) {
    return _firestore
        .collection('categories')
        .doc(category)
        .collection('items')
        .snapshots();
  }

  // Delete an item
  Future<void> deleteItem(String category, String itemId) async {
    try {
      await _firestore
          .collection('categories')
          .doc(category)
          .collection('items')
          .doc(itemId)
          .delete();
    } catch (e) {
      print("Error deleting item: $e");
    }
  }

  // Delete a category along with all items inside it
  Future<void> deleteCategory(String category) async {
    try {
      var itemsCollection =
      _firestore.collection('categories').doc(category).collection('items');

      var items = await itemsCollection.get();
      for (var item in items.docs) {
        await item.reference.delete();
      }

      // Now delete the category itself
      await _firestore.collection('categories').doc(category).delete();
    } catch (e) {
      print("Error deleting category: $e");
    }
  }
}
