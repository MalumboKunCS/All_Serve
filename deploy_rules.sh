#!/bin/bash

echo "Deploying Firestore and Storage security rules..."

echo ""
echo "Checking Firebase project..."
firebase projects:list

echo ""
echo "Please select your Firebase project if prompted, or use:"
echo "firebase use [project-id]"
echo ""

echo "Deploying Firestore rules..."
firebase deploy --only firestore:rules

echo ""
echo "Deploying Storage rules..."
firebase deploy --only storage

echo ""
echo "Deploying Firestore indexes..."
firebase deploy --only firestore:indexes

echo ""
echo "Security rules and indexes deployed successfully!"
echo ""
echo "Next steps:"
echo "1. Run the app and navigate to Database Setup screen"
echo "2. Click 'Complete Database Setup' to initialize with sample data"
echo "3. Test all features with the sample data"
echo ""
