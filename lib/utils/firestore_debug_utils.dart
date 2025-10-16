import 'package:cloud_firestore/cloud_firestore.dart';
import 'app_logger.dart';

class FirestoreDebugUtils {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Debug function to check provider document structure
  static Future<void> debugProviderDocument(String providerId) async {
    try {
      AppLogger.debug('=== FIRESTORE DEBUG: Provider Document ===');
      AppLogger.debug('Provider ID: $providerId');
      
      final doc = await _firestore.collection('providers').doc(providerId).get();
      
      if (doc.exists) {
        final data = doc.data();
        AppLogger.debug('Document exists: YES');
        AppLogger.debug('Document keys: ${data?.keys.toList()}');
        
        if (data != null) {
          // Check services field specifically
          if (data.containsKey('services')) {
            final services = data['services'];
            AppLogger.debug('Services field type: ${services.runtimeType}');
            if (services is List) {
              AppLogger.debug('Services count: ${services.length}');
              for (int i = 0; i < services.length; i++) {
                final service = services[i];
                if (service is Map<String, dynamic>) {
                  AppLogger.debug('Service $i: ${service.keys.toList()}');
                  AppLogger.debug('  - title: ${service['title']}');
                  AppLogger.debug('  - category: ${service['category']}');
                  AppLogger.debug('  - priceFrom: ${service['priceFrom']}');
                  AppLogger.debug('  - priceTo: ${service['priceTo']}');
                } else {
                  AppLogger.debug('Service $i: Invalid format - ${service.runtimeType}');
                }
              }
            } else {
              AppLogger.debug('Services field is not a List: ${services.runtimeType}');
            }
          } else {
            AppLogger.debug('Services field: NOT FOUND');
          }
          
          // Check other important fields
          AppLogger.debug('ownerUid: ${data['ownerUid']}');
          AppLogger.debug('businessName: ${data['businessName']}');
          AppLogger.debug('verificationStatus: ${data['verificationStatus']}');
        }
      } else {
        AppLogger.debug('Document exists: NO');
      }
      
      AppLogger.debug('=== END FIRESTORE DEBUG ===');
    } catch (e) {
      AppLogger.debug('Error debugging provider document: $e');
    }
  }

  /// Debug function to check all providers for a user
  static Future<void> debugUserProviders(String ownerUid) async {
    try {
      AppLogger.debug('=== FIRESTORE DEBUG: User Providers ===');
      AppLogger.debug('Owner UID: $ownerUid');
      
      final query = await _firestore
          .collection('providers')
          .where('ownerUid', isEqualTo: ownerUid)
          .get();
      
      AppLogger.debug('Found ${query.docs.length} provider documents');
      
      for (int i = 0; i < query.docs.length; i++) {
        final doc = query.docs[i];
        final data = doc.data();
        AppLogger.debug('Provider $i:');
        AppLogger.debug('  - ID: ${doc.id}');
        AppLogger.debug('  - businessName: ${data['businessName']}');
        AppLogger.debug('  - services count: ${data['services'] is List ? (data['services'] as List).length : 'N/A'}');
      }
      
      AppLogger.debug('=== END FIRESTORE DEBUG ===');
    } catch (e) {
      AppLogger.debug('Error debugging user providers: $e');
    }
  }
}
