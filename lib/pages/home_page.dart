import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:all_server/auth.dart';
import 'package:all_server/services/firebase_service.dart';
import 'package:all_server/utils/icon_helper.dart';
import 'package:all_server/pages/categories_page.dart';
import 'package:all_server/pages/settings_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final User? user = Auth().currentUser;
  final FirebaseService _firebaseService = FirebaseService();
  
  List<Map<String, dynamic>> categories = [];
  List<Map<String, dynamic>> providers = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  // Load categories and providers data
  Future<void> _loadData() async {
    try {
      // Load random categories
      final randomCategories = await _firebaseService.getRandomCategories(6);
      
      // Load recommended providers
      final recommendedProviders = await _firebaseService.getRecommendedProviders(
        user?.uid ?? 'anonymous');
      
      setState(() {
        categories = randomCategories;
        providers = recommendedProviders;
        isLoading = false;
      });
    } catch (e) {
      print('Error loading data: $e');
      setState(() {
        isLoading = false;
      });
    }
  }

  // Sign out function
  Future<void> signOut() async {
    await Auth().signOut();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("ALL SERVE", style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const SettingsPage(),
                ),
              );
            },
            tooltip: 'Settings',
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
            tooltip: 'Refresh data',
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: signOut,
          )
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadData,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  const Text(
                    "What service do you need?",
                    style: TextStyle(fontSize: 18),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.search),
                      hintText: "Search services...",
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const CategoriesPage(),
                        ),
                      );
                    },
                    child: const Text("View categories", style: TextStyle(color: Colors.blue)),
                  ),
                  const SizedBox(height: 20),
                  const Text("Book an Appointment Instantly", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  if (categories.isNotEmpty)
                    Column(
                      children: [
                        SizedBox(
                          height: 120,
                          child: PageView.builder(
                            itemCount: (categories.length / 3).ceil(),
                            itemBuilder: (context, pageIndex) {
                              final startIndex = pageIndex * 3;
                              final endIndex = (startIndex + 3).clamp(0, categories.length);
                              final pageCategories = categories.sublist(startIndex, endIndex);
                              
                              return Row(
                                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                children: pageCategories.map((cat) {
                                  return Expanded(
                                    child: Column(
                                      children: [
                                        CircleAvatar(
                                          radius: 30,
                                          backgroundColor: Colors.blue.shade100,
                                          child: Icon(
                                            IconHelper.getIconFromString(cat['icon']), 
                                            size: 30, 
                                            color: Colors.blue
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          cat['label'],
                                          textAlign: TextAlign.center,
                                          style: const TextStyle(fontSize: 12),
                                        ),
                                      ],
                                    ),
                                  );
                                }).toList(),
                              );
                            },
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: List.generate(
                            (categories.length / 3).ceil(),
                            (index) => Container(
                              width: 8,
                              height: 8,
                              margin: const EdgeInsets.symmetric(horizontal: 4),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: index == 0 ? Colors.blue : Colors.grey.shade300,
                              ),
                            ),
                          ),
                        ),
                      ],
                    )
                  else
                    const Center(child: Text('No categories available')),
                  const SizedBox(height: 20),
                  const Text("Suggested Providers", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  if (providers.isNotEmpty)
                    Column(
                      children: providers.map((provider) {
                        return Card(
                          margin: const EdgeInsets.symmetric(vertical: 6),
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundImage: NetworkImage(provider['image']),
                              radius: 24,
                            ),
                            title: Row(
                              children: [
                                Text(provider['name']),
                                if (provider['isPrevious'] == true)
                                  Container(
                                    margin: const EdgeInsets.only(left: 8),
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: Colors.green.shade100,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: const Text(
                                      'Previous',
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: Colors.green,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(provider['rating'].toString(), style: const TextStyle(fontWeight: FontWeight.bold)),
                                    const Icon(Icons.star, color: Colors.amber, size: 16),
                                    Text(' (${provider['reviews']})'),
                                  ],
                                ),
                                if (provider['distance'] != null)
                                  Text(
                                    '${provider['distance'].toStringAsFixed(1)} km away',
                                    style: TextStyle(
                                      color: Colors.grey[600],
                                      fontSize: 12,
                                    ),
                                  ),
                              ],
                            ),
                            trailing: ElevatedButton(
                              onPressed: () {
                                // Navigate to provider details page
                              },
                              child: const Text('View'),
                            ),
                          ),
                        );
                      }).toList(),
                    )
                  else
                    const Center(child: Text('No providers available')),
                ],
              ),
            ),
    );
  }
}
