const functions = require('firebase-functions');
const admin = require('firebase-admin');
const speakeasy = require('speakeasy');

admin.initializeApp();

const db = admin.firestore();
const auth = admin.auth();

// Create booking function
exports.createBooking = functions.https.onCall(async (data, context) => {
  const uid = context.auth?.uid;
  if (!uid) {
    throw new functions.https.HttpsError('unauthenticated', 'User must be authenticated');
  }

  const { providerId, serviceId, scheduledAt, address } = data;

  try {
    // Validate provider exists and is active/verified
    const providerDoc = await db.collection('providers').doc(providerId).get();
    if (!providerDoc.exists) {
      throw new functions.https.HttpsError('not-found', 'Provider not found');
    }

    const providerData = providerDoc.data();
    if (providerData.status !== 'active' || !providerData.verified) {
      throw new functions.https.HttpsError('failed-precondition', 'Provider is not available');
    }

    // Validate service exists
    const serviceExists = providerData.services.some(service => service.serviceId === serviceId);
    if (!serviceExists) {
      throw new functions.https.HttpsError('not-found', 'Service not found');
    }

    // Check for conflicting bookings (transaction)
    const result = await db.runTransaction(async (transaction) => {
      const conflictingBookings = await transaction.get(
        db.collection('bookings')
          .where('providerId', '==', providerId)
          .where('scheduledAt', '==', admin.firestore.Timestamp.fromDate(new Date(scheduledAt)))
          .where('status', 'in', ['requested', 'accepted'])
      );

      if (!conflictingBookings.empty) {
        throw new functions.https.HttpsError('already-exists', 'Time slot is already booked');
      }

      // Create booking
      const bookingRef = db.collection('bookings').doc();
      const booking = {
        customerId: uid,
        providerId,
        serviceId,
        address,
        scheduledAt: admin.firestore.Timestamp.fromDate(new Date(scheduledAt)),
        requestedAt: admin.firestore.FieldValue.serverTimestamp(),
        status: 'requested',
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
      };

      transaction.set(bookingRef, booking);
      return { bookingId: bookingRef.id, status: 'requested' };
    });

    // Send notification to provider
    await sendNotificationToProvider(
      providerId, 
      'New Booking Request', 
      `You have a new booking request`,
      {
        type: 'booking_request',
        bookingId: newBookingId,
        customerId: customerId
      },
      'high'
    );

    return result;
  } catch (error) {
    if (error instanceof functions.https.HttpsError) {
      throw error;
    }
    throw new functions.https.HttpsError('internal', 'Failed to create booking');
  }
});

// Update booking status function
exports.updateBookingStatus = functions.https.onCall(async (data, context) => {
  const uid = context.auth?.uid;
  if (!uid) {
    throw new functions.https.HttpsError('unauthenticated', 'User must be authenticated');
  }

  const { bookingId, action } = data;

  try {
    const bookingDoc = await db.collection('bookings').doc(bookingId).get();
    if (!bookingDoc.exists) {
      throw new functions.https.HttpsError('not-found', 'Booking not found');
    }

    const bookingData = bookingDoc.data();
    let newStatus;
    let notificationMessage;

    switch (action) {
      case 'accept':
        if (bookingData.providerId !== uid) {
          throw new functions.https.HttpsError('permission-denied', 'Only provider can accept bookings');
        }
        newStatus = 'accepted';
        notificationMessage = 'Your booking has been accepted!';
        break;
      
      case 'reject':
        if (bookingData.providerId !== uid) {
          throw new functions.https.HttpsError('permission-denied', 'Only provider can reject bookings');
        }
        newStatus = 'rejected';
        notificationMessage = 'Your booking has been rejected';
        break;
      
      case 'complete':
        if (bookingData.providerId !== uid && bookingData.customerId !== uid) {
          throw new functions.https.HttpsError('permission-denied', 'Only provider or customer can complete bookings');
        }
        newStatus = 'completed';
        notificationMessage = 'Your service has been completed!';
        break;
      
      case 'cancel':
        if (bookingData.customerId !== uid) {
          throw new functions.https.HttpsError('permission-denied', 'Only customer can cancel bookings');
        }
        if (bookingData.status !== 'requested' && bookingData.status !== 'accepted') {
          throw new functions.https.HttpsError('failed-precondition', 'Booking cannot be cancelled');
        }
        newStatus = 'cancelled';
        notificationMessage = 'Your booking has been cancelled';
        break;
      
      default:
        throw new functions.https.HttpsError('invalid-argument', 'Invalid action');
    }

    // Update booking status
    await db.collection('bookings').doc(bookingId).update({
      status: newStatus,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    // Send notifications
    if (action === 'accept') {
      await sendNotificationToCustomer(
        bookingData.customerId, 
        'Booking Accepted', 
        notificationMessage,
        {
          type: 'booking_accepted',
          bookingId: bookingId,
          providerId: bookingData.providerId
        },
        'high'
      );
    } else if (action === 'reject') {
      await sendNotificationToCustomer(
        bookingData.customerId, 
        'Booking Declined', 
        notificationMessage,
        {
          type: 'booking_rejected',
          bookingId: bookingId,
          providerId: bookingData.providerId
        },
        'normal'
      );
    } else if (action === 'complete') {
      await sendNotificationToCustomer(
        bookingData.customerId, 
        'Service Completed', 
        notificationMessage,
        {
          type: 'booking_completed',
          bookingId: bookingId,
          providerId: bookingData.providerId
        },
        'normal'
      );
    } else if (action === 'cancel') {
      await sendNotificationToProvider(
        bookingData.providerId, 
        'Booking Cancelled', 
        notificationMessage,
        {
          type: 'booking_cancelled',
          bookingId: bookingId,
          customerId: bookingData.customerId
        },
        'normal'
      );
    }

    return { success: true, status: newStatus };
  } catch (error) {
    if (error instanceof functions.https.HttpsError) {
      throw error;
    }
    throw new functions.https.HttpsError('internal', 'Failed to update booking status');
  }
});

// Post review function
exports.postReview = functions.https.onCall(async (data, context) => {
  const uid = context.auth?.uid;
  if (!uid) {
    throw new functions.https.HttpsError('unauthenticated', 'User must be authenticated');
  }

  const { bookingId, rating, comment } = data;

  try {
    // Validate booking exists and is completed
    const bookingDoc = await db.collection('bookings').doc(bookingId).get();
    if (!bookingDoc.exists) {
      throw new functions.https.HttpsError('not-found', 'Booking not found');
    }

    const bookingData = bookingDoc.data();
    if (bookingData.customerId !== uid) {
      throw new functions.https.HttpsError('permission-denied', 'Only customer can review their own booking');
    }

    if (bookingData.status !== 'completed') {
      throw new functions.https.HttpsError('failed-precondition', 'Can only review completed bookings');
    }

    // Check if review already exists
    const existingReview = await db.collection('reviews')
      .where('bookingId', '==', bookingId)
      .where('customerId', '==', uid)
      .get();

    if (!existingReview.empty) {
      throw new functions.https.HttpsError('already-exists', 'Review already exists for this booking');
    }

    // Create review
    const reviewRef = db.collection('reviews').doc();
    const review = {
      bookingId,
      customerId: uid,
      providerId: bookingData.providerId,
      rating,
      comment,
      flagged: false,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    };

    await reviewRef.set(review);

    // Update provider rating (transaction)
    await db.runTransaction(async (transaction) => {
      const providerRef = db.collection('providers').doc(bookingData.providerId);
      const providerDoc = await transaction.get(providerRef);
      
      if (providerDoc.exists) {
        const providerData = providerDoc.data();
        const currentRating = providerData.ratingAvg || 0;
        const currentCount = providerData.ratingCount || 0;
        
        const newRating = ((currentRating * currentCount) + rating) / (currentCount + 1);
        const newCount = currentCount + 1;
        
        transaction.update(providerRef, {
          ratingAvg: Math.round(newRating * 100) / 100, // Round to 2 decimal places
          ratingCount: newCount,
        });
      }
    });

    return { success: true, reviewId: reviewRef.id };
  } catch (error) {
    if (error instanceof functions.https.HttpsError) {
      throw error;
    }
    throw new functions.https.HttpsError('internal', 'Failed to post review');
  }
});

// Flag review function
exports.flagReview = functions.https.onCall(async (data, context) => {
  const uid = context.auth?.uid;
  if (!uid) {
    throw new functions.https.HttpsError('unauthenticated', 'User must be authenticated');
  }

  const { reviewId, flagReason } = data;

  try {
    await db.collection('reviews').doc(reviewId).update({
      flagged: true,
      flagReason,
      flaggedAt: admin.firestore.FieldValue.serverTimestamp(),
      flaggedBy: uid,
    });

    return { success: true };
  } catch (error) {
    throw new functions.https.HttpsError('internal', 'Failed to flag review');
  }
});

// Fetch providers nearby function
exports.fetchProvidersNearby = functions.https.onRequest(async (req, res) => {
  // Enable CORS
  res.set('Access-Control-Allow-Origin', '*');
  res.set('Access-Control-Allow-Methods', 'GET, POST');
  res.set('Access-Control-Allow-Headers', 'Content-Type');

  if (req.method === 'OPTIONS') {
    res.status(204).send('');
    return;
  }

  try {
    const { lat, lng, radiusKm = 10, categoryId, keywords } = req.body;

    if (!lat || !lng) {
      res.status(400).json({ error: 'Latitude and longitude are required' });
      return;
    }

    // Simple bounding box calculation (for production, use proper geohash)
    const latDelta = radiusKm / 111.32; // 1 degree = 111.32 km
    const lngDelta = radiusKm / (111.32 * Math.cos(lat * Math.PI / 180));

    let query = db.collection('providers')
      .where('status', '==', 'active')
      .where('verified', '==', true)
      .where('lat', '>=', lat - latDelta)
      .where('lat', '<=', lat + latDelta)
      .where('lng', '>=', lng - lngDelta)
      .where('lng', '<=', lng + lngDelta);

    if (categoryId) {
      query = query.where('categoryId', '==', categoryId);
    }

    const snapshot = await query.get();
    let providers = [];

    snapshot.forEach(doc => {
      const data = doc.data();
      const distance = calculateDistance(lat, lng, data.lat, data.lng);
      
      if (distance <= radiusKm) {
        providers.add({
          id: doc.id,
          ...data,
          distance,
        });
      }
    });

    // Sort by distance, then by rating
    providers.sort((a, b) => {
      if (a.distance != b.distance) {
        return a.distance.compareTo(b.distance);
      }
      return (b.ratingAvg || 0).compareTo(a.ratingAvg || 0);
    });

    res.json({ providers: providers.slice(0, 20) }); // Limit to 20 results
  } catch (error) {
    res.status(500).json({ error: 'Failed to fetch providers' });
  }
});

// Admin approve provider function
exports.adminApproveProvider = functions.https.onCall(async (data, context) => {
  const uid = context.auth?.uid;
  if (!uid) {
    throw new functions.https.HttpsError('unauthenticated', 'User must be authenticated');
  }

  // Check if user is admin
  const userDoc = await db.collection('users').doc(uid).get();
  if (!userDoc.exists || userDoc.data().role !== 'admin') {
    throw new functions.https.HttpsError('permission-denied', 'Admin access required');
  }

  const { providerId, approve, notes } = data;

  try {
    const providerRef = db.collection('providers').doc(providerId);
    const providerDoc = await providerRef.get();

    if (!providerDoc.exists) {
      throw new functions.https.HttpsError('not-found', 'Provider not found');
    }

    const updateData = {
      verified: approve,
      verificationStatus: approve ? 'approved' : 'rejected',
      verifiedAt: admin.firestore.FieldValue.serverTimestamp(),
      verifiedBy: uid,
    };

    if (notes) {
      updateData.adminNotes = notes;
    }

    await providerRef.update(updateData);

    // Log admin action
    await db.collection('adminAuditLogs').add({
      actorUid: uid,
      action: approve ? 'approve_provider' : 'reject_provider',
      detail: {
        providerId,
        notes,
        timestamp: admin.firestore.FieldValue.serverTimestamp(),
      },
    });

    // Send notification to provider
    const providerData = providerDoc.data();
    await sendNotificationToProvider(
      providerData.ownerUid, 
      approve ? 'Account Approved!' : 'Verification Update',
      approve 
        ? 'Congratulations! Your provider account has been approved and is now active.'
        : `Your provider verification was not approved. ${notes ? 'Reason: ' + notes : 'Please review and resubmit your documents.'}`,
      {
        type: approve ? 'provider_approved' : 'provider_rejected',
        providerId: providerId,
        notes: notes || ''
      },
      approve ? 'high' : 'normal'
    );

    return { success: true };
  } catch (error) {
    if (error instanceof functions.https.HttpsError) {
      throw error;
    }
    throw new functions.https.HttpsError('internal', 'Failed to update provider status');
  }
});

// Send announcement function (admin only)
exports.sendAnnouncement = functions.https.onCall(async (data, context) => {
  const uid = context.auth?.uid;
  if (!uid) {
    throw new functions.https.HttpsError('unauthenticated', 'User must be authenticated');
  }

  // Check if user is admin
  const userDoc = await db.collection('users').doc(uid).get();
  if (!userDoc.exists || userDoc.data().role !== 'admin') {
    throw new functions.https.HttpsError('permission-denied', 'Admin access required');
  }

  const { title, message, audience } = data;

  try {
    // Store announcement
    await db.collection('announcements').add({
      title,
      message,
      audience, // 'all', 'customers', 'providers'
      createdBy: uid,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    // Send FCM notifications
    await sendAnnouncementNotifications(title, message, audience);

    return { success: true };
  } catch (error) {
    throw new functions.https.HttpsError('internal', 'Failed to send announcement');
  }
});

// Post Review Function
exports.postReview = functions.https.onCall(async (data, context) => {
  // Verify authentication
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'User must be authenticated');
  }

  const uid = context.auth.uid;
  const { bookingId, rating, comment, isUpdate, reviewId } = data;

  // Validate input
  if (!bookingId || !rating || rating < 1 || rating > 5) {
    throw new functions.https.HttpsError('invalid-argument', 'Invalid review data');
  }

  try {
    return await db.runTransaction(async (transaction) => {
      // Get booking to verify it's completed and belongs to user
      const bookingRef = db.collection('bookings').doc(bookingId);
      const bookingDoc = await transaction.get(bookingRef);
      
      if (!bookingDoc.exists) {
        throw new functions.https.HttpsError('not-found', 'Booking not found');
      }

      const booking = bookingDoc.data();
      
      if (booking.customerId !== uid) {
        throw new functions.https.HttpsError('permission-denied', 'Not authorized to review this booking');
      }

      if (booking.status !== 'completed') {
        throw new functions.https.HttpsError('failed-precondition', 'Can only review completed bookings');
      }

      // Check if review already exists (for new reviews)
      if (!isUpdate) {
        const existingReviewQuery = await db.collection('reviews')
          .where('bookingId', '==', bookingId)
          .where('customerId', '==', uid)
          .get();
        
        if (!existingReviewQuery.empty) {
          throw new functions.https.HttpsError('already-exists', 'Review already exists for this booking');
        }
      }

      let reviewRef;
      let oldRating = null;

      if (isUpdate && reviewId) {
        // Update existing review
        reviewRef = db.collection('reviews').doc(reviewId);
        const existingReview = await transaction.get(reviewRef);
        
        if (!existingReview.exists) {
          throw new functions.https.HttpsError('not-found', 'Review not found');
        }

        if (existingReview.data().customerId !== uid) {
          throw new functions.https.HttpsError('permission-denied', 'Not authorized to update this review');
        }

        oldRating = existingReview.data().rating;
        
        transaction.update(reviewRef, {
          rating: rating,
          comment: comment.trim(),
          createdAt: admin.firestore.FieldValue.serverTimestamp(),
        });
      } else {
        // Create new review
        reviewRef = db.collection('reviews').doc();
        
        transaction.set(reviewRef, {
          reviewId: reviewRef.id,
          bookingId: bookingId,
          customerId: uid,
          providerId: booking.providerId,
          rating: rating,
          comment: comment.trim(),
          flagged: false,
          flagReason: null,
          createdAt: admin.firestore.FieldValue.serverTimestamp(),
        });
      }

      // Update provider rating
      await updateProviderRating(transaction, booking.providerId, rating, oldRating);

      return { reviewId: reviewRef.id, success: true };
    });
  } catch (error) {
    console.error('Error posting review:', error);
    if (error instanceof functions.https.HttpsError) {
      throw error;
    }
    throw new functions.https.HttpsError('internal', 'Failed to post review');
  }
});

// Flag Review Function
exports.flagReview = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'User must be authenticated');
  }

  const { reviewId, reason } = data;

  if (!reviewId || !reason) {
    throw new functions.https.HttpsError('invalid-argument', 'Review ID and reason are required');
  }

  try {
    await db.collection('reviews').doc(reviewId).update({
      flagged: true,
      flagReason: reason.trim(),
    });

    return { success: true };
  } catch (error) {
    console.error('Error flagging review:', error);
    throw new functions.https.HttpsError('internal', 'Failed to flag review');
  }
});

// Helper function to update provider rating
async function updateProviderRating(transaction, providerId, newRating, oldRating = null) {
  const providerRef = db.collection('providers').doc(providerId);
  const providerDoc = await transaction.get(providerRef);
  
  if (!providerDoc.exists) {
    throw new Error('Provider not found');
  }

  const provider = providerDoc.data();
  let { ratingAvg = 0, ratingCount = 0 } = provider;

  if (oldRating !== null) {
    // Update existing review - adjust calculation
    if (ratingCount > 0) {
      const totalRating = (ratingAvg * ratingCount) - oldRating + newRating;
      ratingAvg = totalRating / ratingCount;
    } else {
      ratingAvg = newRating;
      ratingCount = 1;
    }
  } else {
    // New review - add to calculation
    const totalRating = (ratingAvg * ratingCount) + newRating;
    ratingCount += 1;
    ratingAvg = totalRating / ratingCount;
  }

  // Round to 2 decimal places
  ratingAvg = Math.round(ratingAvg * 100) / 100;

  transaction.update(providerRef, {
    ratingAvg: ratingAvg,
    ratingCount: ratingCount,
  });
}

// Helper functions
function calculateDistance(lat1, lon1, lat2, lon2) {
  const R = 6371; // Earth's radius in km
  const dLat = (lat2 - lat1) * Math.PI / 180;
  const dLon = (lon2 - lon1) * Math.PI / 180;
  const a = Math.sin(dLat/2) * Math.sin(dLat/2) +
            Math.cos(lat1 * Math.PI / 180) * Math.cos(lat2 * Math.PI / 180) *
            Math.sin(dLon/2) * Math.sin(dLon/2);
  const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1-a));
  return R * c;
}

async function sendNotificationToProvider(providerId, title, message, data = {}, priority = 'normal') {
  try {
    const providerDoc = await db.collection('users').doc(providerId).get();
    if (providerDoc.exists) {
      const deviceTokens = providerDoc.data().deviceTokens || [];
      if (deviceTokens.length > 0) {
        await sendFCMNotification(deviceTokens, title, message, data, priority);
      }
    }
  } catch (error) {
    console.error('Failed to send notification to provider:', error);
  }
}

async function sendNotificationToCustomer(customerId, title, message, data = {}, priority = 'normal') {
  try {
    const customerDoc = await db.collection('users').doc(customerId).get();
    if (customerDoc.exists) {
      const deviceTokens = customerDoc.data().deviceTokens || [];
      if (deviceTokens.length > 0) {
        await sendFCMNotification(deviceTokens, title, message, data, priority);
      }
    }
  } catch (error) {
    console.error('Failed to send notification to customer:', error);
  }
}

async function sendFCMNotification(tokens, title, body, data = {}, priority = 'normal') {
  try {
    if (!tokens || tokens.length === 0) {
      console.log('No tokens provided for FCM notification');
      return;
    }

    // Remove any null/undefined tokens
    const validTokens = tokens.filter(token => token && typeof token === 'string');
    
    if (validTokens.length === 0) {
      console.log('No valid tokens for FCM notification');
      return;
    }

    const message = {
      notification: {
        title,
        body,
      },
      data: {
        ...data,
        timestamp: new Date().toISOString(),
      },
      tokens: validTokens,
      android: {
        notification: {
          channelId: 'all_serve_channel',
          priority: priority === 'high' ? 'high' : 'default',
          sound: 'default',
          clickAction: 'FLUTTER_NOTIFICATION_CLICK',
        },
        priority: priority === 'high' ? 'high' : 'normal',
      },
      apns: {
        payload: {
          aps: {
            alert: {
              title: title,
              body: body,
            },
            badge: 1,
            sound: 'default',
          },
        },
      },
    };

    const response = await admin.messaging().sendMulticast(message);
    
    console.log(`FCM notification sent: ${response.successCount} successful, ${response.failureCount} failed`);
    
    // Handle failed tokens
    if (response.failureCount > 0) {
      const failedTokens = [];
      response.responses.forEach((resp, idx) => {
        if (!resp.success) {
          failedTokens.push(validTokens[idx]);
          console.error('Failed token:', validTokens[idx], resp.error);
        }
      });
      
      // Remove invalid tokens from user documents
      await removeInvalidTokens(failedTokens);
    }
    
    return response;
  } catch (error) {
    console.error('Failed to send FCM notification:', error);
    throw error;
  }
}

// Remove invalid FCM tokens from user documents
async function removeInvalidTokens(invalidTokens) {
  try {
    const batch = db.batch();
    
    for (const token of invalidTokens) {
      // Find users with this token and remove it
      const usersWithToken = await db.collection('users')
        .where('deviceTokens', 'array-contains', token)
        .get();
      
      usersWithToken.docs.forEach(doc => {
        const userRef = db.collection('users').doc(doc.id);
        batch.update(userRef, {
          deviceTokens: admin.firestore.FieldValue.arrayRemove(token)
        });
      });
    }
    
    await batch.commit();
    console.log(`Removed ${invalidTokens.length} invalid tokens`);
  } catch (error) {
    console.error('Error removing invalid tokens:', error);
  }
}

async function sendAnnouncementNotifications(title, message, audience, priority = 'normal', type = 'info') {
  try {
    let userQuery = db.collection('users');
    
    if (audience === 'customers') {
      userQuery = userQuery.where('role', '==', 'customer');
    } else if (audience === 'providers') {
      userQuery = userQuery.where('role', '==', 'provider');
    } else if (audience === 'admins') {
      userQuery = userQuery.where('role', '==', 'admin');
    }

    const usersSnapshot = await userQuery.get();
    const allTokens = [];

    usersSnapshot.forEach(doc => {
      const deviceTokens = doc.data().deviceTokens || [];
      allTokens.push(...deviceTokens);
    });

    if (allTokens.length > 0) {
      await sendFCMNotification(
        allTokens, 
        title, 
        message, 
        {
          type: 'announcement',
          audience: audience,
          announcementType: type,
          priority: priority
        },
        priority === 'urgent' ? 'high' : 'normal'
      );
    }
    
    return allTokens.length;
  } catch (error) {
    console.error('Failed to send announcement notifications:', error);
    throw error;
  }
}


