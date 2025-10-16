import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'app_logger.dart';

class DatabaseSetup {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Initialize database with sample data
  Future<void> initializeDatabase() async {
    try {
      AppLogger.info('DatabaseSetup: Starting database initialization...');
      
      // Create categories
      await _createCategories();
      
      // Create admin user
      await _createAdminUser();
      
      // Create sample providers
      await _createSampleProviders();
      
      // Create sample customers
      await _createSampleCustomers();
      
      AppLogger.info('DatabaseSetup: Database initialization completed successfully!');
    } catch (e) {
      AppLogger.info('DatabaseSetup: Error initializing database: $e');
      rethrow;
    }
  }

  // Create categories
  Future<void> _createCategories() async {
    AppLogger.info('DatabaseSetup: Creating categories...');
    
    final categories = [
      {
        'categoryId': 'plumbing',
        'name': 'Plumbing',
        'description': 'Professional plumbing services for homes and businesses',
        'iconKey': 'plumber',
        'isFeatured': true,
        'createdAt': Timestamp.now(),
      },
      {
        'categoryId': 'electrical',
        'name': 'Electrical',
        'description': 'Electrical installation, repair, and maintenance services',
        'iconKey': 'electrician',
        'isFeatured': true,
        'createdAt': Timestamp.now(),
      },
      {
        'categoryId': 'cleaning',
        'name': 'Cleaning',
        'description': 'House cleaning, office cleaning, and specialized cleaning services',
        'iconKey': 'cleaning',
        'isFeatured': true,
        'createdAt': Timestamp.now(),
      },
      {
        'categoryId': 'gardening',
        'name': 'Gardening',
        'description': 'Landscaping, lawn care, and garden maintenance services',
        'iconKey': 'gardening',
        'isFeatured': false,
        'createdAt': Timestamp.now(),
      },
      {
        'categoryId': 'painting',
        'name': 'Painting',
        'description': 'Interior and exterior painting services for homes and businesses',
        'iconKey': 'painting',
        'isFeatured': false,
        'createdAt': Timestamp.now(),
      },
      {
        'categoryId': 'carpentry',
        'name': 'Carpentry',
        'description': 'Woodworking, furniture repair, and custom carpentry services',
        'iconKey': 'carpentry',
        'isFeatured': false,
        'createdAt': Timestamp.now(),
      },
    ];

    for (final category in categories) {
      await _firestore
          .collection('categories')
          .doc(category['categoryId'] as String)
          .set(category);
    }
    
    AppLogger.info('DatabaseSetup: Created ${categories.length} categories');
  }

  // Create admin user
  Future<void> _createAdminUser() async {
    AppLogger.info('DatabaseSetup: Creating admin user...');
    
    try {
      // Create admin user in Firebase Auth
      final adminCredential = await _auth.createUserWithEmailAndPassword(
        email: 'admin@allserve.com',
        password: 'admin123456',
      );

      // Create admin user document
      await _firestore.collection('users').doc(adminCredential.user!.uid).set({
        'uid': adminCredential.user!.uid,
        'name': 'System Administrator',
        'email': 'admin@allserve.com',
        'phone': '+260977123456',
        'role': 'admin',
        'profileImageUrl': '',
        'defaultAddress': {
          'address': 'Lusaka, Zambia',
          'lat': -15.3875,
          'lng': 28.3228,
        },
        'deviceTokens': [],
        'is2FAEnabled': false,
        'createdAt': Timestamp.now(),
      });

      AppLogger.info('DatabaseSetup: Admin user created - Email: admin@allserve.com, Password: admin123456');
    } catch (e) {
      AppLogger.info('DatabaseSetup: Admin user may already exist: $e');
    }
  }

  // Create sample providers
  Future<void> _createSampleProviders() async {
    AppLogger.info('DatabaseSetup: Creating sample providers...');
    
    final providers = [
      {
        'providerId': 'provider_001',
        'ownerUid': 'sample_provider_1',
        'businessName': 'Lusaka Plumbing Solutions',
        'description': 'Professional plumbing services with 10+ years experience. We handle everything from leak repairs to complete bathroom renovations.',
        'categoryId': 'plumbing',
        'services': [
          {
            'serviceId': 'service_001',
            'title': 'Leak Repair',
            'description': 'Fix all types of water leaks',
            'priceFrom': 50.0,
            'priceTo': 150.0,
            'durationMin': 60,
          },
          {
            'serviceId': 'service_002',
            'title': 'Bathroom Installation',
            'description': 'Complete bathroom installation and renovation',
            'priceFrom': 500.0,
            'priceTo': 2000.0,
            'durationMin': 480,
          },
        ],
        'logoUrl': '',
        'images': [],
        'websiteUrl': 'https://lusakaplumbing.com',
        'lat': -15.3875,
        'lng': 28.3228,
        'geohash': 'kf8j2x',
        'serviceAreaKm': 25.0,
        'ratingAvg': 4.8,
        'ratingCount': 24,
        'verified': true,
        'verificationStatus': 'approved',
        'documents': {
          'businessLicense': 'https://example.com/license1.pdf',
          'insurance': 'https://example.com/insurance1.pdf',
        },
        'status': 'active',
        'keywords': ['plumbing', 'leak', 'bathroom', 'repair', 'installation'],
        'galleryImages': [],
        'adminNotes': 'Verified and approved provider',
        'createdAt': Timestamp.now(),
        'updatedAt': Timestamp.now(),
      },
      {
        'providerId': 'provider_002',
        'ownerUid': 'sample_provider_2',
        'businessName': 'Electric Pro Services',
        'description': 'Licensed electricians providing safe and reliable electrical services for residential and commercial properties.',
        'categoryId': 'electrical',
        'services': [
          {
            'serviceId': 'service_003',
            'title': 'Electrical Installation',
            'description': 'Install electrical outlets, switches, and fixtures',
            'priceFrom': 100.0,
            'priceTo': 300.0,
            'durationMin': 120,
          },
          {
            'serviceId': 'service_004',
            'title': 'Electrical Repair',
            'description': 'Fix electrical problems and safety issues',
            'priceFrom': 75.0,
            'priceTo': 200.0,
            'durationMin': 90,
          },
        ],
        'logoUrl': '',
        'images': [],
        'websiteUrl': 'https://electricpro.co.zm',
        'lat': -15.4000,
        'lng': 28.3000,
        'geohash': 'kf8j2y',
        'serviceAreaKm': 30.0,
        'ratingAvg': 4.6,
        'ratingCount': 18,
        'verified': true,
        'verificationStatus': 'approved',
        'documents': {
          'businessLicense': 'https://example.com/license2.pdf',
          'insurance': 'https://example.com/insurance2.pdf',
        },
        'status': 'active',
        'keywords': ['electrical', 'electrician', 'installation', 'repair', 'safety'],
        'galleryImages': [],
        'adminNotes': 'Verified and approved provider',
        'createdAt': Timestamp.now(),
        'updatedAt': Timestamp.now(),
      },
      {
        'providerId': 'provider_003',
        'ownerUid': 'sample_provider_3',
        'businessName': 'Clean & Shine Services',
        'description': 'Professional cleaning services for homes and offices. We use eco-friendly products and provide reliable, thorough cleaning.',
        'categoryId': 'cleaning',
        'services': [
          {
            'serviceId': 'service_005',
            'title': 'House Cleaning',
            'description': 'Complete house cleaning service',
            'priceFrom': 80.0,
            'priceTo': 150.0,
            'durationMin': 180,
          },
          {
            'serviceId': 'service_006',
            'title': 'Office Cleaning',
            'description': 'Regular office cleaning and maintenance',
            'priceFrom': 120.0,
            'priceTo': 250.0,
            'durationMin': 240,
          },
        ],
        'logoUrl': '',
        'images': [],
        'websiteUrl': '',
        'lat': -15.3800,
        'lng': 28.3400,
        'geohash': 'kf8j2z',
        'serviceAreaKm': 20.0,
        'ratingAvg': 4.4,
        'ratingCount': 12,
        'verified': false,
        'verificationStatus': 'pending',
        'documents': {
          'businessLicense': 'https://example.com/license3.pdf',
        },
        'status': 'active',
        'keywords': ['cleaning', 'house', 'office', 'maintenance', 'eco-friendly'],
        'galleryImages': [],
        'adminNotes': 'Pending verification',
        'createdAt': Timestamp.now(),
        'updatedAt': Timestamp.now(),
      },
    ];

    for (final provider in providers) {
      await _firestore
          .collection('providers')
          .doc(provider['providerId'] as String)
          .set(provider);
    }
    
    AppLogger.info('DatabaseSetup: Created ${providers.length} sample providers');
  }

  // Create sample customers
  Future<void> _createSampleCustomers() async {
    AppLogger.info('DatabaseSetup: Creating sample customers...');
    
    final customers = [
      {
        'uid': 'customer_001',
        'name': 'John Mwila',
        'email': 'john.mwila@email.com',
        'phone': '+260977111111',
        'role': 'customer',
        'profileImageUrl': '',
        'defaultAddress': {
          'address': 'Kabulonga, Lusaka',
          'lat': -15.3900,
          'lng': 28.3200,
        },
        'deviceTokens': [],
        'is2FAEnabled': false,
        'createdAt': Timestamp.now(),
      },
      {
        'uid': 'customer_002',
        'name': 'Sarah Banda',
        'email': 'sarah.banda@email.com',
        'phone': '+260977222222',
        'role': 'customer',
        'profileImageUrl': '',
        'defaultAddress': {
          'address': 'Woodlands, Lusaka',
          'lat': -15.4000,
          'lng': 28.3100,
        },
        'deviceTokens': [],
        'is2FAEnabled': false,
        'createdAt': Timestamp.now(),
      },
    ];

    for (final customer in customers) {
      await _firestore
          .collection('users')
          .doc(customer['uid'] as String)
          .set(customer);
    }
    
    AppLogger.info('DatabaseSetup: Created ${customers.length} sample customers');
  }

  // Create sample bookings
  Future<void> createSampleBookings() async {
    AppLogger.info('DatabaseSetup: Creating sample bookings...');
    
    final bookings = [
      {
        'bookingId': 'booking_001',
        'customerId': 'customer_001',
        'providerId': 'provider_001',
        'serviceId': 'service_001',
        'address': {
          'address': 'Kabulonga, Lusaka',
          'lat': -15.3900,
          'lng': 28.3200,
        },
        'scheduledAt': Timestamp.fromDate(DateTime.now().add(const Duration(days: 1))),
        'requestedAt': Timestamp.now(),
        'status': 'requested',
        'notes': 'Kitchen sink is leaking',
        'createdAt': Timestamp.now(),
        'updatedAt': Timestamp.now(),
      },
      {
        'bookingId': 'booking_002',
        'customerId': 'customer_002',
        'providerId': 'provider_002',
        'serviceId': 'service_003',
        'address': {
          'address': 'Woodlands, Lusaka',
          'lat': -15.4000,
          'lng': 28.3100,
        },
        'scheduledAt': Timestamp.fromDate(DateTime.now().add(const Duration(days: 2))),
        'requestedAt': Timestamp.now(),
        'status': 'accepted',
        'notes': 'Need new electrical outlets installed',
        'createdAt': Timestamp.now(),
        'updatedAt': Timestamp.now(),
      },
    ];

    for (final booking in bookings) {
      await _firestore
          .collection('bookings')
          .doc(booking['bookingId'] as String)
          .set(booking);
    }
    
    AppLogger.info('DatabaseSetup: Created ${bookings.length} sample bookings');
  }

  // Create sample reviews
  Future<void> createSampleReviews() async {
    AppLogger.info('DatabaseSetup: Creating sample reviews...');
    
    final reviews = [
      {
        'reviewId': 'review_001',
        'bookingId': 'booking_001',
        'customerId': 'customer_001',
        'providerId': 'provider_001',
        'rating': 5.0,
        'comment': 'Excellent service! Fixed the leak quickly and professionally.',
        'createdAt': Timestamp.now(),
        'flagged': false,
        'helpfulVotes': [],
      },
      {
        'reviewId': 'review_002',
        'bookingId': 'booking_002',
        'customerId': 'customer_002',
        'providerId': 'provider_002',
        'rating': 4.5,
        'comment': 'Good work, but took longer than expected.',
        'createdAt': Timestamp.now(),
        'flagged': false,
        'helpfulVotes': [],
      },
    ];

    for (final review in reviews) {
      await _firestore
          .collection('reviews')
          .doc(review['reviewId'] as String)
          .set(review);
    }
    
    AppLogger.info('DatabaseSetup: Created ${reviews.length} sample reviews');
  }

  // Create verification queue entries
  Future<void> createVerificationQueue() async {
    AppLogger.info('DatabaseSetup: Creating verification queue entries...');
    
    final queueEntries = [
      {
        'queueId': 'queue_001',
        'providerId': 'provider_003',
        'ownerUid': 'sample_provider_3',
        'submittedAt': Timestamp.now(),
        'status': 'pending',
        'adminNotes': '',
        'docs': {
          'businessLicense': 'https://example.com/license3.pdf',
          'insurance': 'https://example.com/insurance3.pdf',
        },
        'reviewedBy': '',
        'reviewedAt': null,
      },
    ];

    for (final entry in queueEntries) {
      await _firestore
          .collection('verificationQueue')
          .doc(entry['queueId'] as String)
          .set(entry);
    }
    
    AppLogger.info('DatabaseSetup: Created ${queueEntries.length} verification queue entries');
  }

  // Create sample announcements
  Future<void> createSampleAnnouncements() async {
    AppLogger.info('DatabaseSetup: Creating sample announcements...');
    
    final announcements = [
      {
        'announcementId': 'announcement_001',
        'title': 'Welcome to All-Serve!',
        'message': 'Welcome to All-Serve, your trusted platform for finding local service providers in Zambia.',
        'createdBy': 'admin',
        'audience': 'all',
        'priority': 'medium',
        'type': 'info',
        'isActive': true,
        'expiresAt': null,
        'sentCount': 0,
        'createdAt': Timestamp.now(),
      },
      {
        'announcementId': 'announcement_002',
        'title': 'New Features Available',
        'message': 'Check out our new advanced search and filtering options to find the perfect service provider.',
        'createdBy': 'admin',
        'audience': 'customers',
        'priority': 'low',
        'type': 'update',
        'isActive': true,
        'expiresAt': Timestamp.fromDate(DateTime.now().add(const Duration(days: 30))),
        'sentCount': 0,
        'createdAt': Timestamp.now(),
      },
    ];

    for (final announcement in announcements) {
      await _firestore
          .collection('announcements')
          .doc(announcement['announcementId'] as String)
          .set(announcement);
    }
    
    AppLogger.info('DatabaseSetup: Created ${announcements.length} sample announcements');
  }

  // Complete database setup with all sample data
  Future<void> setupCompleteDatabase() async {
    try {
      AppLogger.info('DatabaseSetup: Starting complete database setup...');
      
      await initializeDatabase();
      await createSampleBookings();
      await createSampleReviews();
      await createVerificationQueue();
      await createSampleAnnouncements();
      
      AppLogger.info('DatabaseSetup: Complete database setup finished successfully!');
      AppLogger.info('DatabaseSetup: You can now test the app with sample data.');
    } catch (e) {
      AppLogger.info('DatabaseSetup: Error in complete database setup: $e');
      rethrow;
    }
  }

  // Clear all data (for testing)
  Future<void> clearAllData() async {
    try {
      AppLogger.info('DatabaseSetup: Clearing all data...');
      
      final collections = ['users', 'providers', 'categories', 'bookings', 'reviews', 'verificationQueue', 'announcements'];
      
      for (final collection in collections) {
        final snapshot = await _firestore.collection(collection).get();
        for (final doc in snapshot.docs) {
          await doc.reference.delete();
        }
      }
      
      AppLogger.info('DatabaseSetup: All data cleared successfully!');
    } catch (e) {
      AppLogger.info('DatabaseSetup: Error clearing data: $e');
      rethrow;
    }
  }
}
