import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'firebase_service.dart';

class InventoryScreen extends StatefulWidget {
  @override
  _InventoryScreenState createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen> {
  final FirebaseService _firebaseService = FirebaseService();
  final TextEditingController _categoryController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _priceController = TextEditingController();

  String? _selectedCategory;

  void _addCategory() {
    if (_categoryController.text.isNotEmpty) {
      _firebaseService.addCategory(_categoryController.text);
      _categoryController.clear();
    }
  }

  void _deleteCategory(String categoryId) {
    _firebaseService.deleteCategory(categoryId);
    if (_selectedCategory == categoryId) {
      setState(() => _selectedCategory = null);
    }
  }

  void _addItem() {
    if (_selectedCategory != null &&
        _nameController.text.isNotEmpty &&
        _priceController.text.isNotEmpty) {
      double price = double.tryParse(_priceController.text) ?? 0;
      _firebaseService.addItem(_selectedCategory!, _nameController.text, price);
      _nameController.clear();
      _priceController.clear();
    }
  }

  void _deleteItem(String itemId) {
    if (_selectedCategory != null) {
      _firebaseService.deleteItem(_selectedCategory!, itemId);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("స్టాక్")), // "Inventory" in Telugu
      body: Padding(
        padding: EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Add Category Section
            TextField(
              controller: _categoryController,
              decoration: InputDecoration(labelText: 'కొత్త విభాగం'), // "New Category"
            ),
            SizedBox(height: 5),
            ElevatedButton(
              onPressed: _addCategory,
              child: Text("విభాగం జోడించు"), // "Add Category"
            ),
            SizedBox(height: 20),

            // Select & Delete Category Dropdown
            StreamBuilder<QuerySnapshot>(
              stream: _firebaseService.getCategories(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return CircularProgressIndicator();
                }
                var categories = snapshot.data!.docs;

                return Column(
                  children: [
                    DropdownButton<String>(
                      value: _selectedCategory,
                      hint: Text("విభాగం"), // "Category"
                      isExpanded: true,
                      items: categories
                          .map((doc) => DropdownMenuItem(
                        value: doc.id,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(doc.id),
                            IconButton(
                              icon: Icon(Icons.delete, color: Colors.red),
                              onPressed: () => _deleteCategory(doc.id),
                            ),
                          ],
                        ),
                      ))
                          .toList(),
                      onChanged: (value) {
                        setState(() => _selectedCategory = value);
                      },
                    ),
                  ],
                );
              },
            ),
            SizedBox(height: 20),

            // Add Item Form
            if (_selectedCategory != null) ...[
              TextField(
                controller: _nameController,
                decoration: InputDecoration(labelText: 'పేరు'), // "Name"
              ),
              TextField(
                controller: _priceController,
                decoration: InputDecoration(labelText: 'రేటు'), // "Price"
                keyboardType: TextInputType.number,
              ),
              SizedBox(height: 10),
              ElevatedButton(
                onPressed: _addItem,
                child: Text("Item జోడించు"), // "Add Item"
              ),
            ],
            SizedBox(height: 20),

            // Display Items in Selected Category
            if (_selectedCategory != null)
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: _firebaseService.getItems(_selectedCategory!),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) {
                      return Center(child: CircularProgressIndicator());
                    }
                    var items = snapshot.data!.docs;

                    return ListView.builder(
                      itemCount: items.length,
                      itemBuilder: (context, index) {
                        var item = items[index];
                        return Card(
                          child: ListTile(
                            title: Text(item['name']),
                            subtitle: Text("Price: ₹${item['price']}"),
                            trailing: IconButton(
                              icon: Icon(Icons.delete, color: Colors.red),
                              onPressed: () => _deleteItem(item.id),
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}
