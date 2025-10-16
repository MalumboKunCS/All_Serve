const admin = require('firebase-admin');
const readline = require('readline');

// Create readline interface for user input
const rl = readline.createInterface({
  input: process.stdin,
  output: process.stdout
});

// Function to ask questions
function askQuestion(question) {
  return new Promise((resolve) => {
    rl.question(question, (answer) => {
      resolve(answer);
    });
  });
}

// Function to ask for service account key path
async function getServiceAccountPath() {
  const path = await askQuestion('Enter the path to your Firebase service account key JSON file: ');
  return path.trim();
}

// Function to get admin details
async function getAdminDetails() {
  console.log('\n📝 Enter Super Admin Details:');
  console.log('================================');
  
  const uid = await askQuestion('Firebase Auth UID: ');
  const email = await askQuestion('Email address: ');
  const name = await askQuestion('Full name: ');
  const phone = await askQuestion('Phone number (optional): ') || '+1234567890';
  
  return { uid: uid.trim(), email: email.trim(), name: name.trim(), phone: phone.trim() };
}

// Function to initialize Firebase Admin
async function initializeFirebase() {
  try {
    const serviceAccountPath = await getServiceAccountPath();
    const serviceAccount = require(serviceAccountPath);
    
    admin.initializeApp({
      credential: admin.credential.cert(serviceAccount),
      databaseURL: `https://${serviceAccount.project_id}-default-rtdb.firebaseio.com`
    });
    
    console.log('✅ Firebase Admin initialized successfully!');
    return true;
  } catch (error) {
    console.error('❌ Error initializing Firebase Admin:', error.message);
    console.log('\n💡 Make sure you have:');
    console.log('   1. Downloaded your service account key from Firebase Console');
    console.log('   2. Installed firebase-admin: npm install firebase-admin');
    console.log('   3. The JSON file path is correct');
    return false;
  }
}

// Function to create super admin
async function createSuperAdmin(adminDetails) {
  const db = admin.firestore();
  
  try {
    console.log('\n🔄 Creating Super Admin...');
    
    // Create admin document
    const adminData = {
      uid: adminDetails.uid,
      email: adminDetails.email,
      name: adminDetails.name,
      isSuperAdmin: true,
      createdBy: 'system',
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      isActive: true,
      permissions: [
        'manage_admins',
        'manage_users',
        'manage_providers',
        'manage_reviews',
        'manage_announcements',
        'view_analytics',
        'manage_settings'
      ]
    };

    // Create user document
    const userData = {
      uid: adminDetails.uid,
      name: adminDetails.name,
      email: adminDetails.email,
      phone: adminDetails.phone,
      role: 'admin',
      deviceTokens: [],
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      is2FAEnabled: false,
      backupCodes: []
    };

    // Write to Firestore
    await db.collection('admins').doc(adminDetails.uid).set(adminData);
    await db.collection('users').doc(adminDetails.uid).set(userData);
    
    // Create audit log
    await db.collection('adminAuditLogs').add({
      actorUid: 'system',
      action: 'create_super_admin',
      targetUid: adminDetails.uid,
      targetEmail: adminDetails.email,
      isSuperAdmin: true,
      timestamp: admin.firestore.FieldValue.serverTimestamp(),
      details: `Super admin created via CLI: ${adminDetails.name} (${adminDetails.email})`,
    });

    console.log('✅ Super Admin created successfully!');
    console.log('\n📋 Admin Details:');
    console.log(`   UID: ${adminDetails.uid}`);
    console.log(`   Name: ${adminDetails.name}`);
    console.log(`   Email: ${adminDetails.email}`);
    console.log(`   Phone: ${adminDetails.phone}`);
    console.log(`   Role: Super Admin`);
    console.log(`   Status: Active`);
    
    return true;
  } catch (error) {
    console.error('❌ Error creating Super Admin:', error.message);
    return false;
  }
}

// Function to verify admin creation
async function verifyAdminCreation(uid) {
  const db = admin.firestore();
  
  try {
    console.log('\n🔍 Verifying admin creation...');
    
    const adminDoc = await db.collection('admins').doc(uid).get();
    const userDoc = await db.collection('users').doc(uid).get();
    
    if (adminDoc.exists && userDoc.exists) {
      console.log('✅ Verification successful!');
      console.log('   Admin document: ✅');
      console.log('   User document: ✅');
      return true;
    } else {
      console.log('❌ Verification failed!');
      console.log(`   Admin document: ${adminDoc.exists ? '✅' : '❌'}`);
      console.log(`   User document: ${userDoc.exists ? '✅' : '❌'}`);
      return false;
    }
  } catch (error) {
    console.error('❌ Error verifying admin creation:', error.message);
    return false;
  }
}

// Function to create Firestore security rules
async function createSecurityRules() {
  const rules = `rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // Users can read/write their own data
    match /users/{userId} {
      allow read, write: if request.auth != null && request.auth.uid == userId;
    }
    
    // Only admins can access admin collection
    match /admins/{adminId} {
      allow read, write: if request.auth != null && 
        exists(/databases/$(database)/documents/admins/$(request.auth.uid));
    }
    
    // Only super admins can manage other admins
    match /admins/{adminId} {
      allow write: if request.auth != null && 
        exists(/databases/$(database)/documents/admins/$(request.auth.uid)) &&
        get(/databases/$(database)/documents/admins/$(request.auth.uid)).data.isSuperAdmin == true;
    }
    
    // Admin audit logs - only admins can read
    match /adminAuditLogs/{logId} {
      allow read: if request.auth != null && 
        exists(/databases/$(database)/documents/admins/$(request.auth.uid));
    }
    
    // Providers - admins can manage all, owners can manage their own
    match /providers/{providerId} {
      allow read: if request.auth != null;
      allow write: if request.auth != null && 
        (request.auth.uid == resource.data.ownerUid || 
         exists(/databases/$(database)/documents/admins/$(request.auth.uid)));
    }
    
    // Bookings - users can read their own, admins can read all
    match /bookings/{bookingId} {
      allow read: if request.auth != null && 
        (request.auth.uid == resource.data.customerId || 
         request.auth.uid == resource.data.providerId ||
         exists(/databases/$(database)/documents/admins/$(request.auth.uid)));
      allow write: if request.auth != null && 
        (request.auth.uid == resource.data.customerId || 
         request.auth.uid == resource.data.providerId ||
         exists(/databases/$(database)/documents/admins/$(request.auth.uid)));
    }
    
    // Reviews - users can read all, write their own
    match /reviews/{reviewId} {
      allow read: if request.auth != null;
      allow write: if request.auth != null && 
        (request.auth.uid == resource.data.customerId ||
         exists(/databases/$(database)/documents/admins/$(request.auth.uid)));
    }
    
    // Announcements - admins can manage, users can read
    match /announcements/{announcementId} {
      allow read: if request.auth != null;
      allow write: if request.auth != null && 
        exists(/databases/$(database)/documents/admins/$(request.auth.uid));
    }
  }
}`;

  const fs = require('fs');
  const path = require('path');
  
  try {
    const rulesPath = path.join(process.cwd(), 'firestore.rules');
    fs.writeFileSync(rulesPath, rules);
    console.log('✅ Security rules created at: firestore.rules');
    console.log('   Deploy with: firebase deploy --only firestore:rules');
    return true;
  } catch (error) {
    console.error('❌ Error creating security rules:', error.message);
    return false;
  }
}

// Main function
async function main() {
  console.log('🚀 All-Serve Admin Setup Script');
  console.log('================================\n');
  
  // Check if firebase-admin is installed
  try {
    require('firebase-admin');
  } catch (error) {
    console.log('❌ firebase-admin package not found!');
    console.log('   Install it with: npm install firebase-admin');
    process.exit(1);
  }
  
  // Initialize Firebase
  const firebaseInitialized = await initializeFirebase();
  if (!firebaseInitialized) {
    process.exit(1);
  }
  
  // Get admin details
  const adminDetails = await getAdminDetails();
  
  // Confirm details
  console.log('\n📋 Confirm Details:');
  console.log(`   UID: ${adminDetails.uid}`);
  console.log(`   Name: ${adminDetails.name}`);
  console.log(`   Email: ${adminDetails.email}`);
  console.log(`   Phone: ${adminDetails.phone}`);
  
  const confirm = await askQuestion('\nProceed with creating super admin? (y/N): ');
  if (confirm.toLowerCase() !== 'y' && confirm.toLowerCase() !== 'yes') {
    console.log('❌ Setup cancelled.');
    process.exit(0);
  }
  
  // Create super admin
  const adminCreated = await createSuperAdmin(adminDetails);
  if (!adminCreated) {
    process.exit(1);
  }
  
  // Verify creation
  const verified = await verifyAdminCreation(adminDetails.uid);
  if (!verified) {
    console.log('⚠️  Admin created but verification failed. Check Firebase Console.');
  }
  
  // Create security rules
  await createSecurityRules();
  
  console.log('\n🎉 Setup Complete!');
  console.log('==================');
  console.log('✅ Super Admin created successfully');
  console.log('✅ Security rules generated');
  console.log('\n📝 Next Steps:');
  console.log('   1. Deploy security rules: firebase deploy --only firestore:rules');
  console.log('   2. Start your admin web app: cd admin_web && flutter run -d chrome');
  console.log('   3. Login with your admin credentials');
  console.log('   4. Navigate to Admin Management to create additional admins');
  
  rl.close();
}

// Handle errors
process.on('unhandledRejection', (error) => {
  console.error('❌ Unhandled error:', error);
  rl.close();
  process.exit(1);
});

// Run the script
main().catch((error) => {
  console.error('❌ Script failed:', error);
  rl.close();
  process.exit(1);
});













