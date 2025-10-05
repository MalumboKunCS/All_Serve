#!/bin/bash

echo ""
echo "========================================"
echo "   All-Serve Admin Setup Script"
echo "========================================"
echo ""

# Check if Node.js is installed
if ! command -v node &> /dev/null; then
    echo "❌ Node.js is not installed!"
    echo "   Please install Node.js from https://nodejs.org/"
    echo "   Then run this script again."
    exit 1
fi

# Check if firebase-admin is installed
if ! npm list firebase-admin &> /dev/null; then
    echo "📦 Installing firebase-admin..."
    npm install firebase-admin
    if [ $? -ne 0 ]; then
        echo "❌ Failed to install firebase-admin!"
        exit 1
    fi
fi

echo "✅ Dependencies are ready!"
echo ""

# Run the setup script
node setup-admin.js

echo ""
echo "Press any key to exit..."
read -n 1 -s





