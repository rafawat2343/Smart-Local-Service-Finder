import 'package:cloud_firestore/cloud_firestore.dart';

class DatabaseService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Collection references
  static const String usersCollection = 'users';
  static const String clientsCollection = 'clients';
  static const String providersCollection = 'providers';
  static const String requestsCollection = 'service_requests';
  static const String bookingsCollection = 'bookings';
  static const String conversationsCollection = 'conversations';
  static const String messagesCollection = 'messages';
  static const String reviewsCollection = 'reviews';
  static const String notificationsCollection = 'notifications';
  static const String transactionsCollection = 'transactions';

  // ──────────────────────────────────────────────────────────────────────────
  // REWARD / COMMISSION POLICY (single source of truth)
  // ──────────────────────────────────────────────────────────────────────────
  static const int pointsPerTakaSpent = 1;       // 1 pt per ৳100
  static const int pointsTakaDivisor = 100;      // → spent / 100 = points
  static const double pointValueTaka = 0.5;      // 1 pt = ৳0.5 off
  static const int minPointsRedemption = 1;      // any positive amount
  static const double commissionRate = 0.10;     // 10% flat

  // Pure helpers — used by UI and ledger code alike.
  static int computePointsForAmount(int amountTaka) =>
      amountTaka <= 0 ? 0 : amountTaka ~/ pointsTakaDivisor;

  static int computeCommissionForAmount(int amountTaka) =>
      amountTaka <= 0 ? 0 : (amountTaka * commissionRate).round();

  static int computeDiscountForPoints(int points) =>
      points <= 0 ? 0 : (points * pointValueTaka).round();

  /// Strip the dollar/taka prefix and any thousands separators from the legacy
  /// agreedPrice string and round to whole taka. "$500" / "৳1,500" / "500/hr"
  /// all collapse to 500. Bad input → 0.
  static int _parseAgreedAmountTaka(String raw) {
    if (raw.isEmpty) return 0;
    final cleaned = raw.replaceAll(RegExp(r'[^0-9.]'), '');
    final v = double.tryParse(cleaned);
    if (v == null || v <= 0) return 0;
    return v.round();
  }

  // ──────────────────────────────────────────────────────────────────────────
  // USER OPERATIONS
  // ──────────────────────────────────────────────────────────────────────────

  /// Save user basic information
  static Future<void> saveUserData({
    required String userId,
    required String phoneNumber,
    required String displayName,
    required String email,
    required bool isClient,
    required String nidNumber,
    required String dateOfBirth,
    required String fatherName,
    required String motherName,
    String password = '',
  }) async {
    try {
      final userData = {
        'userId': userId,
        'phoneNumber': phoneNumber,
        'displayName': displayName,
        'email': email,
        'isClient': isClient,
        'userType': isClient ? 'client' : 'provider',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'isActive': true,
      };

      // Save to users collection (merge so we never wipe existing profile fields)
      await _firestore
          .collection(usersCollection)
          .doc(userId)
          .set(userData, SetOptions(merge: true));

      // Save to specific role collection
      final roleCollection = isClient ? clientsCollection : providersCollection;
      final roleData = {
        ...userData,
        'nidNumber': nidNumber,
        'dateOfBirth': dateOfBirth,
        'fatherName': fatherName,
        'motherName': motherName,
        'password': password,
        'profileComplete': true,
        'latitude': null,
        'longitude': null,
        'locationUpdatedAt': null,
        if (!isClient) ...{
          'serviceRadiusKm': 5,
          // Providers must be approved by admin before they can sign in.
          'isApproved': false,
        },
      };
      // Mirror approval state on the users doc so the login gate can read it
      // without needing to fetch the role collection again.
      if (!isClient) {
        userData['isApproved'] = false;
      }

      await _firestore
          .collection(roleCollection)
          .doc(userId)
          .set(roleData, SetOptions(merge: true));
    } catch (e) {
      throw Exception('Failed to save user data: $e');
    }
  }

  /// Update user profile
  static Future<void> updateUserProfile({
    required String userId,
    required Map<String, dynamic> updates,
  }) async {
    try {
      updates['updatedAt'] = FieldValue.serverTimestamp();

      await _firestore.collection(usersCollection).doc(userId).update(updates);

      // Also update the role-specific collection
      // This will be determined by querying the user first
      final userDoc = await _firestore
          .collection(usersCollection)
          .doc(userId)
          .get();
      if (userDoc.exists) {
        final userType = userDoc['userType'] as String;
        final roleCollection = userType == 'client'
            ? clientsCollection
            : providersCollection;
        await _firestore.collection(roleCollection).doc(userId).update(updates);
      }
    } catch (e) {
      throw Exception('Failed to update user profile: $e');
    }
  }

  /// Get user data
  static Future<Map<String, dynamic>?> getUserData(String userId) async {
    try {
      final doc = await _firestore
          .collection(usersCollection)
          .doc(userId)
          .get();
      return doc.data();
    } catch (e) {
      throw Exception('Failed to fetch user data: $e');
    }
  }

  /// Get full user details including NID info and password from role collection
  static Future<Map<String, dynamic>?> getUserFullDetails(
    String userId,
    String userType,
  ) async {
    try {
      final roleCollection = userType == 'client'
          ? clientsCollection
          : providersCollection;
      final doc = await _firestore.collection(roleCollection).doc(userId).get();
      if (doc.exists) return {'id': doc.id, ...doc.data()!};
      return await getUserData(userId);
    } catch (e) {
      throw Exception('Failed to fetch user details: $e');
    }
  }

  /// Get user by phone number
  static Future<Map<String, dynamic>?> getUserByPhoneNumber(
    String phoneNumber,
  ) async {
    try {
      final snapshot = await _firestore
          .collection(usersCollection)
          .where('phoneNumber', isEqualTo: phoneNumber)
          .limit(1)
          .get();

      if (snapshot.docs.isNotEmpty) {
        return snapshot.docs.first.data();
      }
      return null;
    } catch (e) {
      throw Exception('Failed to fetch user by phone: $e');
    }
  }

  // ──────────────────────────────────────────────────────────────────────────
  // CLIENT-SPECIFIC OPERATIONS
  // ──────────────────────────────────────────────────────────────────────────

  /// Get client profile
  static Future<Map<String, dynamic>?> getClientProfile(String userId) async {
    try {
      final doc = await _firestore
          .collection(clientsCollection)
          .doc(userId)
          .get();
      return doc.data();
    } catch (e) {
      throw Exception('Failed to fetch client profile: $e');
    }
  }

  /// Update client profile
  static Future<void> updateClientProfile({
    required String userId,
    required Map<String, dynamic> updates,
  }) async {
    try {
      updates['updatedAt'] = FieldValue.serverTimestamp();
      await _firestore
          .collection(clientsCollection)
          .doc(userId)
          .update(updates);
      await _firestore.collection(usersCollection).doc(userId).update(updates);
    } catch (e) {
      throw Exception('Failed to update client profile: $e');
    }
  }

  /// Store GPS coordinates for a user in both users and their role collection.
  static Future<void> updateUserLocation({
    required String userId,
    required double latitude,
    required double longitude,
    required bool isClient,
  }) async {
    try {
      final data = {
        'latitude': latitude,
        'longitude': longitude,
        'locationUpdatedAt': FieldValue.serverTimestamp(),
      };
      await _firestore
          .collection(usersCollection)
          .doc(userId)
          .set(data, SetOptions(merge: true));
      final roleCollection = isClient ? clientsCollection : providersCollection;
      await _firestore
          .collection(roleCollection)
          .doc(userId)
          .set(data, SetOptions(merge: true));
    } catch (e) {
      throw Exception('Failed to update location: $e');
    }
  }

  /// Update the km radius a provider is willing to serve.
  static Future<void> updateProviderServiceRadius({
    required String userId,
    required int radiusKm,
  }) async {
    try {
      final data = {
        'serviceRadiusKm': radiusKm,
        'updatedAt': FieldValue.serverTimestamp(),
      };
      await _firestore
          .collection(providersCollection)
          .doc(userId)
          .set(data, SetOptions(merge: true));
      await _firestore
          .collection(usersCollection)
          .doc(userId)
          .set(data, SetOptions(merge: true));
    } catch (e) {
      throw Exception('Failed to update service radius: $e');
    }
  }

  // ──────────────────────────────────────────────────────────────────────────
  // PROVIDER-SPECIFIC OPERATIONS
  // ──────────────────────────────────────────────────────────────────────────

  /// Get provider profile
  static Future<Map<String, dynamic>?> getProviderProfile(String userId) async {
    try {
      final userDoc = await _firestore
          .collection(usersCollection)
          .doc(userId)
          .get();
      final providerDoc = await _firestore
          .collection(providersCollection)
          .doc(userId)
          .get();

      final userData = userDoc.data();
      final providerData = providerDoc.data();

      if (userData == null && providerData == null) {
        return null;
      }

      // providers/{uid} is the canonical source for profile-specific fields
      // (about, services, hourlyRate, availability). Spread it last so its
      // values win over any stale or basic-only entries in users/{uid}.
      return {...?userData, ...?providerData};
    } catch (e) {
      throw Exception('Failed to fetch provider profile: $e');
    }
  }

  /// Update provider profile
  static Future<void> updateProviderProfile({
    required String userId,
    required Map<String, dynamic> updates,
  }) async {
    try {
      final normalizedUpdates = Map<String, dynamic>.from(updates);
      final aboutValue =
          (normalizedUpdates['aboutText'] ?? normalizedUpdates['about'] ?? '')
              .toString();
      final servicesValue =
          normalizedUpdates['services'] ??
          normalizedUpdates['servicesOffered'] ??
          const <String>[];
      final hourlyRateValue =
          normalizedUpdates['hourlyRate'] ?? normalizedUpdates['price'];
      final availabilityValue =
          normalizedUpdates['availabilityText'] ??
          normalizedUpdates['availableText'];
      final jobsValue =
          normalizedUpdates['jobsCompleted'] ?? normalizedUpdates['jobs'];
      final expValue =
          normalizedUpdates['experience'] ?? normalizedUpdates['exp'];

      normalizedUpdates['about'] = aboutValue;
      normalizedUpdates['aboutText'] = aboutValue;
      normalizedUpdates['services'] = servicesValue;
      normalizedUpdates['servicesOffered'] = servicesValue;
      if (hourlyRateValue != null) {
        normalizedUpdates['hourlyRate'] = hourlyRateValue;
        normalizedUpdates['price'] = hourlyRateValue;
      }
      if (availabilityValue != null) {
        normalizedUpdates['availabilityText'] = availabilityValue;
      }
      if (jobsValue != null) {
        normalizedUpdates['jobs'] = jobsValue;
        normalizedUpdates['jobsCompleted'] = jobsValue;
        normalizedUpdates['totalJobs'] = jobsValue;
      }
      if (expValue != null) {
        normalizedUpdates['experience'] = expValue;
        normalizedUpdates['exp'] = expValue;
      }
      normalizedUpdates['updatedAt'] = FieldValue.serverTimestamp();

      await _firestore
          .collection(providersCollection)
          .doc(userId)
          .set(normalizedUpdates, SetOptions(merge: true));
      await _firestore
          .collection(usersCollection)
          .doc(userId)
          .set(normalizedUpdates, SetOptions(merge: true));
    } catch (e) {
      throw Exception('Failed to update provider profile: $e');
    }
  }

  /// Get all providers by service type
  static Future<List<Map<String, dynamic>>> getProvidersByServiceType(
    String serviceType,
  ) async {
    try {
      final snapshot = await _firestore
          .collection(providersCollection)
          .where('isActive', isEqualTo: true)
          .get();

      final requestedCategory = _canonicalCategory(serviceType);
      final providers = <Map<String, dynamic>>[];

      for (var doc in snapshot.docs) {
        final providerId = doc.id;
        final providerData = doc.data();

        // Also fetch from users collection to get latest updates
        final userDoc = await _firestore
            .collection(usersCollection)
            .doc(providerId)
            .get();
        final userData = userDoc.data();

        // Merge with users data taking priority
        final merged = {...providerData, ...?userData};

        final displayName =
            (merged['displayName'] ?? merged['name'] ?? 'Provider').toString();
        final specialty = (merged['serviceType'] ?? merged['specialty'] ?? '')
            .toString();
        final hourlyRate = merged['hourlyRate'] ?? merged['price'] ?? '0';
        final services =
            merged['services'] ?? merged['servicesOffered'] ?? const [];

        final provider = {
          'id': providerId,
          ...merged,
          'name': displayName,
          'specialty': specialty.isNotEmpty ? specialty : serviceType,
          'available': merged['isAvailable'] ?? merged['available'] ?? true,
          'price': hourlyRate,
          'rating': _toDouble(merged['ratingAvg'] ?? merged['rating']),
          'reviews': _toInt(merged['totalReviews'] ?? merged['reviews']),
          'jobs': _toInt(merged['jobsCompleted'] ?? merged['jobs']),
          'exp': merged['experience'] ?? merged['exp'] ?? '',
          'initials': merged['initials'] ?? _initialsFromName(displayName),
          'services': services,
          'about': merged['about'] ?? merged['aboutText'] ?? '',
          'aboutText': merged['aboutText'] ?? merged['about'] ?? '',
          'availabilityText':
              merged['availabilityText'] ?? merged['availableText'] ?? '',
        };

        // Filter by requested category
        if (requestedCategory.isNotEmpty) {
          final specialtyCanonical = _canonicalCategory(
            provider['specialty'].toString(),
          );
          final serviceTypeValue = _canonicalCategory(
            (provider['serviceType'] ?? '').toString(),
          );
          if (specialtyCanonical == requestedCategory ||
              serviceTypeValue == requestedCategory ||
              specialtyCanonical.contains(requestedCategory) ||
              requestedCategory.contains(specialtyCanonical)) {
            providers.add(provider);
          }
        } else {
          providers.add(provider);
        }
      }

      providers.sort(
        (a, b) => _toDouble(b['rating']).compareTo(_toDouble(a['rating'])),
      );
      return providers;
    } catch (e) {
      throw Exception('Failed to fetch providers: $e');
    }
  }

  // ──────────────────────────────────────────────────────────────────────────
  // USER ACTIVITY/STATUS OPERATIONS
  // ──────────────────────────────────────────────────────────────────────────

  /// Set user online/offline status
  ///
  /// Writes to BOTH `users/{uid}` and `providers/{uid}` so the value can't be
  /// shadowed by stale data when `getProviderProfile` merges the two
  /// collections (provider data wins in that merge). Uses `set(merge:true)`
  /// instead of `update()` so a missing document or missing field can't make
  /// the write silently fail.
  static Future<void> setUserStatus({
    required String userId,
    required bool isOnline,
  }) async {
    try {
      final payload = {
        'isOnline': isOnline,
        'lastActive': FieldValue.serverTimestamp(),
      };
      await _firestore
          .collection(usersCollection)
          .doc(userId)
          .set(payload, SetOptions(merge: true));
      await _firestore
          .collection(providersCollection)
          .doc(userId)
          .set(payload, SetOptions(merge: true));
    } catch (e) {
      throw Exception('Failed to update user status: $e');
    }
  }

  /// Deactivate user account
  static Future<void> deactivateUserAccount(String userId) async {
    try {
      await _firestore.collection(usersCollection).doc(userId).update({
        'isActive': false,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Also deactivate in role-specific collection
      final userDoc = await _firestore
          .collection(usersCollection)
          .doc(userId)
          .get();
      if (userDoc.exists) {
        final userType = userDoc['userType'] as String;
        final roleCollection = userType == 'client'
            ? clientsCollection
            : providersCollection;
        await _firestore.collection(roleCollection).doc(userId).update({
          'isActive': false,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
    } catch (e) {
      throw Exception('Failed to deactivate account: $e');
    }
  }

  // ──────────────────────────────────────────────────────────────────────────
  // BATCH OPERATIONS
  // ──────────────────────────────────────────────────────────────────────────

  /// Delete user data (should be called when user account is deleted)
  static Future<void> deleteUserData(String userId) async {
    try {
      WriteBatch batch = _firestore.batch();

      // Delete from users collection
      batch.delete(_firestore.collection(usersCollection).doc(userId));

      // Determine user type and delete from role collection
      final userDoc = await _firestore
          .collection(usersCollection)
          .doc(userId)
          .get();
      if (userDoc.exists) {
        final userType = userDoc['userType'] as String;
        final roleCollection = userType == 'client'
            ? clientsCollection
            : providersCollection;
        batch.delete(_firestore.collection(roleCollection).doc(userId));
      }

      await batch.commit();
    } catch (e) {
      throw Exception('Failed to delete user data: $e');
    }
  }

  /// Check if user exists
  static Future<bool> userExists(String userId) async {
    try {
      final doc = await _firestore
          .collection(usersCollection)
          .doc(userId)
          .get();
      return doc.exists;
    } catch (e) {
      throw Exception('Failed to check user existence: $e');
    }
  }

  /// Get user count by type
  static Future<int> getUserCountByType(String userType) async {
    try {
      final snapshot = await _firestore
          .collection(usersCollection)
          .where('userType', isEqualTo: userType)
          .count()
          .get();
      return snapshot.count ?? 0;
    } catch (e) {
      throw Exception('Failed to get user count: $e');
    }
  }

  // ──────────────────────────────────────────────────────────────────────────
  // SERVICE REQUEST OPERATIONS
  // ──────────────────────────────────────────────────────────────────────────

  static Future<void> createServiceRequest({
    required String clientId,
    required String category,
    required String description,
    required String location,
    required String budget,
    required bool isUrgent,
    double? latitude,
    double? longitude,
  }) async {
    try {
      await _firestore.collection(requestsCollection).add({
        'clientId': clientId,
        'category': category,
        'categoryKey': _canonicalCategory(category),
        'description': description,
        'location': location,
        'budget': budget,
        'isUrgent': isUrgent,
        'status': 'open',
        if (latitude != null) 'latitude': latitude,
        if (longitude != null) 'longitude': longitude,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw Exception('Failed to create service request: $e');
    }
  }

  static Future<List<Map<String, dynamic>>> getClientRequests(
    String clientId,
  ) async {
    try {
      final snapshot = await _firestore
          .collection(requestsCollection)
          .where('clientId', isEqualTo: clientId)
          .get();

      final requests = snapshot.docs
          .map((doc) => {'id': doc.id, ...doc.data()})
          .toList();
      _sortByCreatedAtDesc(requests);
      return requests;
    } catch (e) {
      throw Exception('Failed to fetch client requests: $e');
    }
  }

  static Future<List<Map<String, dynamic>>> getOpenRequests({
    String? category,
  }) async {
    try {
      final snapshot = await _firestore
          .collection(requestsCollection)
          .where('status', isEqualTo: 'open')
          .get();

      final requests = snapshot.docs
          .map((doc) => {'id': doc.id, ...doc.data()})
          .toList();

      final normalizedCategory = _canonicalCategory(category ?? '');
      if (normalizedCategory.isNotEmpty) {
        final filtered = requests.where((r) {
          final raw = (r['category'] ?? '').toString();
          final key = (r['categoryKey'] ?? '').toString();
          final normalizedRaw = _canonicalCategory(raw);
          return key == normalizedCategory ||
              normalizedRaw == normalizedCategory ||
              raw.toLowerCase().contains(normalizedCategory) ||
              normalizedCategory.contains(raw.toLowerCase());
        }).toList();

        _sortByCreatedAtDesc(filtered);
        return filtered;
      }

      _sortByCreatedAtDesc(requests);
      return requests;
    } catch (e) {
      throw Exception('Failed to fetch open requests: $e');
    }
  }

  static Future<Map<String, dynamic>> getClientStats(String clientId) async {
    try {
      final activeSnapshot = await _firestore
          .collection(requestsCollection)
          .where('clientId', isEqualTo: clientId)
          .where('status', whereIn: ['open', 'accepted', 'in_progress'])
          .get();

      final completedSnapshot = await _firestore
          .collection(requestsCollection)
          .where('clientId', isEqualTo: clientId)
          .where('status', isEqualTo: 'completed')
          .get();

      return {
        'active': activeSnapshot.docs.length,
        'completed': completedSnapshot.docs.length,
      };
    } catch (e) {
      throw Exception('Failed to fetch client stats: $e');
    }
  }

  // ──────────────────────────────────────────────────────────────────────────
  // BOOKING OPERATIONS
  // ──────────────────────────────────────────────────────────────────────────

  static Future<String> createBooking({
    required String requestId,
    required String clientId,
    required String providerId,
    required String agreedPrice,
    String description = '',
    String status = 'pending',
    String specialty = '',
    int pointsToRedeem = 0,
  }) async {
    try {
      final bookingRef = _firestore.collection(bookingsCollection).doc();

      // Resolve specialty from the provider profile when caller didn't supply it,
      // so the admin category breakdown can classify every booking accurately.
      String resolvedSpecialty = specialty.trim();
      if (resolvedSpecialty.isEmpty && providerId.isNotEmpty) {
        try {
          final providerDoc = await _firestore
              .collection(providersCollection)
              .doc(providerId)
              .get();
          final data = providerDoc.data();
          resolvedSpecialty = (data?['specialty'] ??
                  data?['serviceType'] ??
                  '')
              .toString();
        } catch (_) {}
      }
      // Pull category from the request when this booking originated from one.
      if (resolvedSpecialty.isEmpty && requestId.isNotEmpty) {
        try {
          final reqDoc = await _firestore
              .collection(requestsCollection)
              .doc(requestId)
              .get();
          final data = reqDoc.data();
          resolvedSpecialty = (data?['category'] ??
                  data?['categoryKey'] ??
                  '')
              .toString();
        } catch (_) {}
      }
      final categoryKey = _canonicalCategory(resolvedSpecialty);

      // Parse the legacy agreedPrice string into an integer-taka snapshot we
      // can do math on later. Both fields are persisted: the string for
      // back-compat with existing readers, the int for the ledger.
      final agreedAmountTaka = _parseAgreedAmountTaka(agreedPrice);
      final discountTaka = computeDiscountForPoints(pointsToRedeem);

      final baseBooking = <String, dynamic>{
        'requestId': requestId,
        'clientId': clientId,
        'providerId': providerId,
        'agreedPrice': agreedPrice,
        'agreedAmountTaka': agreedAmountTaka,
        'pointsRedeemed': pointsToRedeem,
        'discountTaka': discountTaka,
        'pointsRecorded': false,
        'commissionRecorded': false,
        'description': description,
        'status': status,
        'specialty': resolvedSpecialty,
        'serviceType': resolvedSpecialty,
        'category': resolvedSpecialty,
        'categoryKey': categoryKey,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (pointsToRedeem > 0) {
        // Defensive validation inside the transaction. The UI also validates
        // before calling, but balance can change between sheet open and
        // submit, so we re-check against the live document here.
        if (pointsToRedeem < minPointsRedemption) {
          throw Exception(
            'Minimum redemption is $minPointsRedemption points',
          );
        }
        if (discountTaka > agreedAmountTaka) {
          throw Exception(
            'Discount cannot exceed the agreed amount',
          );
        }

        final clientUserRef =
            _firestore.collection(usersCollection).doc(clientId);
        final clientRoleRef =
            _firestore.collection(clientsCollection).doc(clientId);
        final txnRef =
            _firestore.collection(transactionsCollection).doc();

        await _firestore.runTransaction((tx) async {
          final clientSnap = await tx.get(clientUserRef);
          final currentBalance =
              _toInt(clientSnap.data()?['pointsBalance']);
          if (pointsToRedeem > currentBalance) {
            throw Exception(
              'Not enough points (have $currentBalance, need $pointsToRedeem)',
            );
          }
          final lifetimeRedeemed =
              _toInt(clientSnap.data()?['pointsLifetimeRedeemed']);

          tx.set(bookingRef, baseBooking);

          tx.set(txnRef, {
            'userId': clientId,
            'userRole': 'client',
            'type': 'points_redeemed',
            'amount': pointsToRedeem,
            'currency': 'POINTS',
            'bookingId': bookingRef.id,
            'description':
                'Redeemed $pointsToRedeem pts (৳$discountTaka off)',
            'createdAt': FieldValue.serverTimestamp(),
          });

          tx.set(clientUserRef, {
            'pointsBalance': currentBalance - pointsToRedeem,
            'pointsLifetimeRedeemed': lifetimeRedeemed + pointsToRedeem,
            'updatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
          tx.set(clientRoleRef, {
            'pointsBalance': currentBalance - pointsToRedeem,
            'pointsLifetimeRedeemed': lifetimeRedeemed + pointsToRedeem,
            'updatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
        });
      } else {
        await bookingRef.set(baseBooking);
      }

      if (requestId.isNotEmpty) {
        await _firestore.collection(requestsCollection).doc(requestId).update({
          'status': status,
          'providerId': providerId,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }

      // Ensure a conversation exists so either party can chat before acceptance.
      try {
        await getOrCreateConversation(
          clientId: clientId,
          providerId: providerId,
        );
      } catch (_) {}

      return bookingRef.id;
    } catch (e) {
      throw Exception('Failed to create booking: $e');
    }
  }

  static Future<List<Map<String, dynamic>>> getProviderBookings(
    String providerId,
  ) async {
    try {
      final snapshot = await _firestore
          .collection(bookingsCollection)
          .where('providerId', isEqualTo: providerId)
          .get();

      final bookings = snapshot.docs
          .map((doc) => {'id': doc.id, ...doc.data()})
          .toList();
      _sortByCreatedAtDesc(bookings);
      return bookings;
    } catch (e) {
      throw Exception('Failed to fetch provider bookings: $e');
    }
  }

  static Future<List<Map<String, dynamic>>> getClientBookings(
    String clientId,
  ) async {
    try {
      final snapshot = await _firestore
          .collection(bookingsCollection)
          .where('clientId', isEqualTo: clientId)
          .get();

      final bookings = snapshot.docs
          .map((doc) => {'id': doc.id, ...doc.data()})
          .toList();
      _sortByCreatedAtDesc(bookings);
      return bookings;
    } catch (e) {
      throw Exception('Failed to fetch client bookings: $e');
    }
  }

  /// Fetch a service request by its document id.
  static Future<Map<String, dynamic>?> getServiceRequest(
    String requestId,
  ) async {
    if (requestId.isEmpty) return null;
    try {
      final doc = await _firestore
          .collection(requestsCollection)
          .doc(requestId)
          .get();
      if (!doc.exists) return null;
      return {'id': doc.id, ...?doc.data()};
    } catch (_) {
      return null;
    }
  }

  static Future<void> updateBookingStatus({
    required String bookingId,
    required String status,
  }) async {
    try {
      await _firestore.collection(bookingsCollection).doc(bookingId).update({
        'status': status,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      final bookingDoc = await _firestore
          .collection(bookingsCollection)
          .doc(bookingId)
          .get();
      final requestId = bookingDoc.data()?['requestId'] as String?;
      if (requestId != null && requestId.isNotEmpty) {
        await _firestore.collection(requestsCollection).doc(requestId).update({
          'status': status,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
    } catch (e) {
      throw Exception('Failed to update booking status: $e');
    }
  }

  static Future<Map<String, dynamic>> getProviderStats(
    String providerId,
  ) async {
    try {
      final activeSnapshot = await _firestore
          .collection(bookingsCollection)
          .where('providerId', isEqualTo: providerId)
          .where('status', whereIn: ['confirmed', 'in_progress'])
          .get();

      final allSnapshot = await _firestore
          .collection(bookingsCollection)
          .where('providerId', isEqualTo: providerId)
          .get();

      double totalEarnings = 0;
      int completedJobs = 0;
      for (final doc in allSnapshot.docs) {
        final data = doc.data();
        if ((data['status'] ?? '') == 'completed') {
          completedJobs += 1;
          final total = _toDouble(data['totalAmount']);
          totalEarnings += total > 0 ? total : _toDouble(data['agreedPrice']);
        }
      }

      return {
        'activeJobs': activeSnapshot.docs.length,
        'totalJobs': completedJobs,
        'totalEarnings': totalEarnings,
      };
    } catch (e) {
      throw Exception('Failed to fetch provider stats: $e');
    }
  }

  // ──────────────────────────────────────────────────────────────────────────
  // CONVERSATION + MESSAGE OPERATIONS
  // ──────────────────────────────────────────────────────────────────────────

  static Future<String> getOrCreateConversation({
    required String clientId,
    required String providerId,
  }) async {
    try {
      final existing = await _firestore
          .collection(conversationsCollection)
          .where('clientId', isEqualTo: clientId)
          .where('providerId', isEqualTo: providerId)
          .limit(1)
          .get();

      if (existing.docs.isNotEmpty) {
        return existing.docs.first.id;
      }

      final docRef = _firestore.collection(conversationsCollection).doc();
      await docRef.set({
        'clientId': clientId,
        'providerId': providerId,
        'lastMessage': '',
        'lastMessageAt': FieldValue.serverTimestamp(),
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      return docRef.id;
    } catch (e) {
      throw Exception('Failed to create conversation: $e');
    }
  }

  static Future<List<Map<String, dynamic>>> getUserConversations(
    String userId,
    bool isClient,
  ) async {
    try {
      final field = isClient ? 'clientId' : 'providerId';
      final snapshot = await _firestore
          .collection(conversationsCollection)
          .where(field, isEqualTo: userId)
          .get();

      final convs = snapshot.docs
          .map((doc) => {'id': doc.id, ...doc.data()})
          .toList();
      convs.sort((a, b) {
        final at = a['lastMessageAt'];
        final bt = b['lastMessageAt'];
        final ams = at is Timestamp ? at.millisecondsSinceEpoch : 0;
        final bms = bt is Timestamp ? bt.millisecondsSinceEpoch : 0;
        return bms.compareTo(ams);
      });
      return convs;
    } catch (e) {
      throw Exception('Failed to fetch conversations: $e');
    }
  }

  static Stream<List<Map<String, dynamic>>> streamUserConversations(
    String userId,
    bool isClient,
  ) {
    final field = isClient ? 'clientId' : 'providerId';
    return _firestore
        .collection(conversationsCollection)
        .where(field, isEqualTo: userId)
        .snapshots()
        .map((snapshot) {
          final convs = snapshot.docs
              .map((doc) => {'id': doc.id, ...doc.data()})
              .toList();
          convs.sort((a, b) {
            final at = a['lastMessageAt'];
            final bt = b['lastMessageAt'];
            final ams = at is Timestamp ? at.millisecondsSinceEpoch : 0;
            final bms = bt is Timestamp ? bt.millisecondsSinceEpoch : 0;
            return bms.compareTo(ams);
          });
          return convs;
        });
  }

  static Future<void> sendMessage({
    required String conversationId,
    required String senderId,
    required String content,
  }) async {
    try {
      await _firestore
          .collection(conversationsCollection)
          .doc(conversationId)
          .collection(messagesCollection)
          .add({
            'senderId': senderId,
            'content': content,
            'messageType': 'text',
            'readBy': [senderId],
            'createdAt': FieldValue.serverTimestamp(),
          });

      await _firestore
          .collection(conversationsCollection)
          .doc(conversationId)
          .update({
            'lastMessage': content,
            'lastMessageAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
          });
    } catch (e) {
      throw Exception('Failed to send message: $e');
    }
  }

  static Stream<List<Map<String, dynamic>>> streamMessages(
    String conversationId,
  ) {
    return _firestore
        .collection(conversationsCollection)
        .doc(conversationId)
        .collection(messagesCollection)
        .orderBy('createdAt')
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => {'id': doc.id, ...doc.data()})
              .toList(),
        );
  }

  static Future<void> markMessagesAsRead({
    required String conversationId,
    required String readerId,
  }) async {
    try {
      final snapshot = await _firestore
          .collection(conversationsCollection)
          .doc(conversationId)
          .collection(messagesCollection)
          .get();

      final batch = _firestore.batch();
      for (final doc in snapshot.docs) {
        final data = doc.data();
        if ((data['senderId'] ?? '') == readerId) continue;
        final readBy = List<String>.from(data['readBy'] ?? const []);
        if (!readBy.contains(readerId)) {
          batch.update(doc.reference, {
            'readBy': [...readBy, readerId],
          });
        }
      }
      await batch.commit();
    } catch (_) {
      // Non-critical: read receipts should never block chat UI.
    }
  }

  // ──────────────────────────────────────────────────────────────────────────
  // REVIEW OPERATIONS
  // ──────────────────────────────────────────────────────────────────────────

  static Future<void> createReview({
    required String bookingId,
    required String clientId,
    required String providerId,
    required int rating,
    required String reviewText,
  }) async {
    try {
      final trimmedText = reviewText.trim();
      await _firestore.collection(reviewsCollection).add({
        'bookingId': bookingId,
        'clientId': clientId,
        'providerId': providerId,
        'rating': rating.toDouble(),
        'reviewText': reviewText,
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (bookingId.isNotEmpty) {
        try {
          await _firestore
              .collection(bookingsCollection)
              .doc(bookingId)
              .update({
                'reviewed': true,
                'reviewRating': rating,
                'reviewHasText': trimmedText.isNotEmpty,
                'reviewedAt': FieldValue.serverTimestamp(),
              });
        } catch (_) {}
      }

      // Reward points only when the client gave BOTH stars and a written
      // review. Stars-only submissions intentionally do not earn points.
      if (rating > 0 &&
          trimmedText.isNotEmpty &&
          bookingId.isNotEmpty &&
          clientId.isNotEmpty) {
        try {
          await _awardPointsForReview(
            bookingId: bookingId,
            clientId: clientId,
          );
        } catch (_) {
          // Reward failures must not block the review submission itself —
          // the review is the user-visible action.
        }
      }

      final reviews = await _firestore
          .collection(reviewsCollection)
          .where('providerId', isEqualTo: providerId)
          .get();

      if (reviews.docs.isNotEmpty) {
        double sum = 0;
        for (final doc in reviews.docs) {
          sum += _toDouble(doc.data()['rating']);
        }
        final avg = sum / reviews.docs.length;
        await _firestore.collection(providersCollection).doc(providerId).set({
          'ratingAvg': avg,
          'totalReviews': reviews.docs.length,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }
    } catch (e) {
      throw Exception('Failed to create review: $e');
    }
  }

  static Future<List<Map<String, dynamic>>> getProviderReviews(
    String providerId,
  ) async {
    try {
      final snapshot = await _firestore
          .collection(reviewsCollection)
          .where('providerId', isEqualTo: providerId)
          .get();

      List<Map<String, dynamic>> output = [];
      for (final doc in snapshot.docs) {
        final data = doc.data();
        final clientId = data['clientId'] as String? ?? '';

        String name = 'Client';
        if (clientId.isNotEmpty) {
          final clientDoc = await _firestore
              .collection(clientsCollection)
              .doc(clientId)
              .get();
          name = clientDoc.data()?['displayName'] as String? ?? 'Client';
        }

        final parts = name.split(' ');
        final initials = parts.length >= 2
            ? '${parts.first[0]}${parts.last[0]}'.toUpperCase()
            : name.isNotEmpty
            ? name[0].toUpperCase()
            : 'C';

        output.add({
          'id': doc.id,
          'name': name,
          'initials': initials,
          'date': _formatDate(data['createdAt']),
          'rating': _toDouble(data['rating']),
          'text': (data['reviewText'] ?? '').toString(),
          '_createdAt': data['createdAt'],
        });
      }

      // Sort newest-first in Dart (avoids requiring a Firestore composite index)
      output.sort((a, b) {
        final aTs = a['_createdAt'];
        final bTs = b['_createdAt'];
        if (aTs is Timestamp && bTs is Timestamp) return bTs.compareTo(aTs);
        return 0;
      });
      for (final item in output) {
        item.remove('_createdAt');
      }

      return output;
    } catch (e) {
      throw Exception('Failed to fetch provider reviews: $e');
    }
  }

  // ──────────────────────────────────────────────────────────────────────────
  // BOOKMARK OPERATIONS
  // ──────────────────────────────────────────────────────────────────────────

  static const String bookmarksCollection = 'bookmarks';

  static Future<void> toggleBookmark(String clientId, String providerId) async {
    if (clientId.isEmpty || providerId.isEmpty) return;
    final ref = _firestore.collection(bookmarksCollection).doc(clientId);
    try {
      final doc = await ref.get();
      final ids = List<String>.from(doc.data()?['providerIds'] ?? []);
      if (ids.contains(providerId)) {
        await ref.set({
          'providerIds': FieldValue.arrayRemove([providerId]),
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      } else {
        await ref.set({
          'providerIds': FieldValue.arrayUnion([providerId]),
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }
    } catch (e) {
      throw Exception('Failed to toggle bookmark: $e');
    }
  }

  static Future<bool> isBookmarked(String clientId, String providerId) async {
    if (clientId.isEmpty || providerId.isEmpty) return false;
    try {
      final doc = await _firestore
          .collection(bookmarksCollection)
          .doc(clientId)
          .get();
      final ids = List<String>.from(doc.data()?['providerIds'] ?? []);
      return ids.contains(providerId);
    } catch (_) {
      return false;
    }
  }

  static Future<List<Map<String, dynamic>>> getBookmarkedProviders(
    String clientId,
  ) async {
    if (clientId.isEmpty) return [];
    try {
      final doc = await _firestore
          .collection(bookmarksCollection)
          .doc(clientId)
          .get();
      final ids = List<String>.from(doc.data()?['providerIds'] ?? []);
      if (ids.isEmpty) return [];
      final results = <Map<String, dynamic>>[];
      for (final id in ids) {
        final profile = await getProviderProfile(id);
        if (profile != null) {
          results.add({'id': id, ...profile});
        }
      }
      return results;
    } catch (e) {
      throw Exception('Failed to fetch bookmarked providers: $e');
    }
  }

  // ──────────────────────────────────────────────────────────────────────────
  // LIVE CLIENT STATS
  // ──────────────────────────────────────────────────────────────────────────

  static Future<Map<String, int>> getClientLiveStats(String clientId) async {
    try {
      final reqSnap = await _firestore
          .collection(requestsCollection)
          .where('clientId', isEqualTo: clientId)
          .get();

      final completedSnap = await _firestore
          .collection(bookingsCollection)
          .where('clientId', isEqualTo: clientId)
          .where('status', isEqualTo: 'completed')
          .get();

      final reviewSnap = await _firestore
          .collection(reviewsCollection)
          .where('clientId', isEqualTo: clientId)
          .get();

      return {
        'totalRequests': reqSnap.docs.length,
        'completedBookings': completedSnap.docs.length,
        'reviewsGiven': reviewSnap.docs.length,
      };
    } catch (_) {
      return {'totalRequests': 0, 'completedBookings': 0, 'reviewsGiven': 0};
    }
  }

  // ──────────────────────────────────────────────────────────────────────────
  // SESSION/CLEANUP OPERATIONS
  // ──────────────────────────────────────────────────────────────────────────

  static Future<void> signOutCleanup(String userId) async {
    try {
      // Don't flip isOnline:false on sign-out — the toggle on the provider
      // feed is the only switch users explicitly control, and clobbering it
      // here meant providers reappeared as Unavailable to clients on every
      // re-sign-in until the next app launch wrote it back to true.
      await _firestore.collection(usersCollection).doc(userId).set({
        'lastActive': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (_) {
      // Avoid blocking sign-out for non-critical cleanup updates.
    }
  }

  static double _toDouble(dynamic value) {
    if (value is num) return value.toDouble();
    if (value is String) {
      final cleaned = value.replaceAll(RegExp(r'[^0-9.]'), '');
      return double.tryParse(cleaned) ?? 0;
    }
    return 0;
  }

  static int _toInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) {
      return int.tryParse(value.replaceAll(RegExp(r'[^0-9-]'), '')) ?? 0;
    }
    return 0;
  }

  static String _initialsFromName(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) {
      return 'P';
    }
    if (parts.length == 1) {
      return parts.first[0].toUpperCase();
    }
    return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
  }

  static String _formatDate(dynamic timestamp) {
    if (timestamp is! Timestamp) return '';
    final dt = timestamp.toDate();
    final y = dt.year.toString().padLeft(4, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  static void _sortByCreatedAtDesc(List<Map<String, dynamic>> items) {
    items.sort((a, b) {
      final aTs = a['createdAt'];
      final bTs = b['createdAt'];
      if (aTs is Timestamp && bTs is Timestamp) {
        return bTs.compareTo(aTs);
      }
      if (aTs is Timestamp) return -1;
      if (bTs is Timestamp) return 1;
      return 0;
    });
  }

  // ──────────────────────────────────────────────────────────────────────────
  // ADMIN OPERATIONS
  // ──────────────────────────────────────────────────────────────────────────

  static Future<Map<String, int>> getAdminStats() async {
    try {
      final usersSnap = await _firestore.collection(usersCollection).get();
      int totalUsers = 0, totalClients = 0, totalProviders = 0;
      for (final doc in usersSnap.docs) {
        final type = (doc.data()['userType'] ?? '').toString();
        if (type == 'admin') continue;
        totalUsers++;
        if (type == 'client') totalClients++;
        if (type == 'provider') totalProviders++;
      }
      final requestsSnap = await _firestore
          .collection(requestsCollection)
          .get();
      final bookingsSnap = await _firestore
          .collection(bookingsCollection)
          .get();
      final reportsSnap = await _firestore.collection(reportsCollection).get();
      return {
        'totalUsers': totalUsers,
        'totalClients': totalClients,
        'totalProviders': totalProviders,
        'totalRequests': requestsSnap.docs.length,
        'totalBookings': bookingsSnap.docs.length,
        'totalReports': reportsSnap.docs.length,
      };
    } catch (e) {
      throw Exception('Failed to fetch admin stats: $e');
    }
  }

  static Future<List<Map<String, dynamic>>> getAllUsers({
    String? filterType,
  }) async {
    try {
      Query query = _firestore.collection(usersCollection);
      if (filterType != null && filterType != 'all') {
        query = query.where('userType', isEqualTo: filterType);
      }
      final snap = await query.get();
      final users = snap.docs
          .map((doc) => {'id': doc.id, ...doc.data() as Map<String, dynamic>})
          .where((u) => u['userType'] != 'admin')
          .toList();
      _sortByCreatedAtDesc(users);
      return users;
    } catch (e) {
      throw Exception('Failed to fetch users: $e');
    }
  }

  static Future<List<Map<String, dynamic>>> getAllServiceRequests() async {
    try {
      final snap = await _firestore.collection(requestsCollection).get();
      final requests = snap.docs
          .map((doc) => {'id': doc.id, ...doc.data()})
          .toList();
      _sortByCreatedAtDesc(requests);
      return requests;
    } catch (e) {
      throw Exception('Failed to fetch all requests: $e');
    }
  }

  static Future<List<Map<String, dynamic>>> getAllBookings() async {
    try {
      final results = await Future.wait([
        _firestore.collection(bookingsCollection).get(),
        _firestore.collection(usersCollection).get(),
      ]);
      final bookingsSnap = results[0];
      final usersSnap = results[1];

      // Build userId → displayName map so legacy bookings that never stored a
      // denormalized clientName/providerName still resolve to a real name.
      final Map<String, String> userNames = {};
      for (final doc in usersSnap.docs) {
        final name = (doc.data()['displayName'] ?? '').toString();
        if (name.isNotEmpty) userNames[doc.id] = name;
      }

      final bookings = bookingsSnap.docs.map((doc) {
        final data = {'id': doc.id, ...doc.data()};
        final cid = (data['clientId'] ?? '').toString();
        final pid = (data['providerId'] ?? '').toString();
        if ((data['clientName'] ?? '').toString().isEmpty &&
            userNames[cid] != null) {
          data['clientName'] = userNames[cid];
        }
        if ((data['providerName'] ?? '').toString().isEmpty &&
            userNames[pid] != null) {
          data['providerName'] = userNames[pid];
        }
        return data;
      }).toList();
      _sortByCreatedAtDesc(bookings);
      return bookings;
    } catch (e) {
      throw Exception('Failed to fetch all bookings: $e');
    }
  }

  static Future<void> deleteUser(String userId, String userType) async {
    try {
      await _cascadeDeleteUserData(userId, userType);
    } catch (e) {
      throw Exception('Failed to delete user: $e');
    }
  }

  /// Permanently delete a user and every Firestore document linked to them.
  /// Used by admin "Delete" and the in-app "Delete account" action.
  static Future<void> _cascadeDeleteUserData(
    String userId,
    String userType,
  ) async {
    if (userId.isEmpty) return;

    Future<void> deleteWhere(String coll, String field) async {
      final snap = await _firestore
          .collection(coll)
          .where(field, isEqualTo: userId)
          .get();
      if (snap.docs.isEmpty) return;
      // Firestore batches cap at 500 writes; chunk just in case.
      for (var i = 0; i < snap.docs.length; i += 450) {
        final end = (i + 450 < snap.docs.length) ? i + 450 : snap.docs.length;
        final batch = _firestore.batch();
        for (final doc in snap.docs.sublist(i, end)) {
          batch.delete(doc.reference);
        }
        await batch.commit();
      }
    }

    // Conversations + their message subcollections
    Future<void> deleteConversations(String field) async {
      final snap = await _firestore
          .collection(conversationsCollection)
          .where(field, isEqualTo: userId)
          .get();
      for (final conv in snap.docs) {
        final msgs = await conv.reference.collection(messagesCollection).get();
        for (var i = 0; i < msgs.docs.length; i += 450) {
          final end =
              (i + 450 < msgs.docs.length) ? i + 450 : msgs.docs.length;
          final batch = _firestore.batch();
          for (final m in msgs.docs.sublist(i, end)) {
            batch.delete(m.reference);
          }
          await batch.commit();
        }
        await conv.reference.delete();
      }
    }

    await deleteWhere(requestsCollection, 'clientId');
    await deleteWhere(bookingsCollection, 'clientId');
    await deleteWhere(bookingsCollection, 'providerId');
    await deleteWhere(reviewsCollection, 'clientId');
    await deleteWhere(reviewsCollection, 'providerId');
    await deleteWhere(reportsCollection, 'clientId');
    await deleteWhere(reportsCollection, 'providerId');
    await deleteWhere(notificationsCollection, 'userId');
    await deleteConversations('clientId');
    await deleteConversations('providerId');

    final batch = _firestore.batch();
    if (userType == 'client') {
      batch.delete(_firestore.collection(clientsCollection).doc(userId));
    } else if (userType == 'provider') {
      batch.delete(_firestore.collection(providersCollection).doc(userId));
    } else {
      // Caller didn't know — clean both just in case.
      batch.delete(_firestore.collection(clientsCollection).doc(userId));
      batch.delete(_firestore.collection(providersCollection).doc(userId));
    }
    batch.delete(_firestore.collection(usersCollection).doc(userId));
    await batch.commit();
  }

  /// Cascade-delete the currently signed-in user's data. Wraps the same logic
  /// as the admin delete, so client/provider profile "Delete account" actions
  /// purge every linked document before we sign out and remove the auth user.
  static Future<void> deleteOwnAccountData({
    required String userId,
    required String userType,
  }) async {
    try {
      await _cascadeDeleteUserData(userId, userType);
    } catch (e) {
      throw Exception('Failed to delete account data: $e');
    }
  }

  /// Returns approval/active state needed by the login screen to gate access.
  /// Returns null if no user record exists (treated as "not signed up here").
  static Future<Map<String, dynamic>?> getLoginGateInfo(String userId) async {
    if (userId.isEmpty) return null;
    try {
      final userDoc = await _firestore
          .collection(usersCollection)
          .doc(userId)
          .get();
      if (!userDoc.exists) return null;
      final data = userDoc.data() ?? {};
      final type = (data['userType'] ?? '').toString();
      bool? isApproved = data['isApproved'] as bool?;
      // Fall back to the role collection for older accounts that don't
      // carry the approval flag on the users doc.
      if (type == 'provider' && isApproved == null) {
        final p = await _firestore
            .collection(providersCollection)
            .doc(userId)
            .get();
        isApproved = p.data()?['isApproved'] as bool?;
      }
      return {
        'userType': type,
        'isActive': data['isActive'] as bool? ?? true,
        'isApproved': isApproved ?? (type != 'provider'),
      };
    } catch (_) {
      return null;
    }
  }

  /// Re-activate a user after a successful login. Admin-deactivated accounts
  /// remain hidden until the owner returns and signs in again.
  static Future<void> activateUserOnLogin(String userId) async {
    if (userId.isEmpty) return;
    try {
      final updates = {
        'isActive': true,
        'updatedAt': FieldValue.serverTimestamp(),
      };
      await _firestore
          .collection(usersCollection)
          .doc(userId)
          .set(updates, SetOptions(merge: true));
      final userDoc = await _firestore
          .collection(usersCollection)
          .doc(userId)
          .get();
      final type = (userDoc.data()?['userType'] ?? '').toString();
      if (type == 'client') {
        await _firestore
            .collection(clientsCollection)
            .doc(userId)
            .set(updates, SetOptions(merge: true));
      } else if (type == 'provider') {
        await _firestore
            .collection(providersCollection)
            .doc(userId)
            .set(updates, SetOptions(merge: true));
      }
    } catch (_) {
      // Non-critical: don't block login on this.
    }
  }

  static Future<void> setUserActiveStatus(String userId, bool isActive) async {
    try {
      final updates = {
        'isActive': isActive,
        'updatedAt': FieldValue.serverTimestamp(),
      };
      await _firestore.collection(usersCollection).doc(userId).update(updates);
      final userDoc = await _firestore
          .collection(usersCollection)
          .doc(userId)
          .get();
      if (userDoc.exists) {
        final userType = (userDoc.data()?['userType'] ?? '').toString();
        if (userType == 'client') {
          await _firestore
              .collection(clientsCollection)
              .doc(userId)
              .set(updates, SetOptions(merge: true));
        } else if (userType == 'provider') {
          await _firestore
              .collection(providersCollection)
              .doc(userId)
              .set(updates, SetOptions(merge: true));
        }
      }
    } catch (e) {
      throw Exception('Failed to update user status: $e');
    }
  }

  // ──────────────────────────────────────────────────────────────────────────
  // REPORT OPERATIONS
  // ──────────────────────────────────────────────────────────────────────────

  static const String reportsCollection = 'reports';

  static Future<void> submitReport({
    required String clientId,
    required String clientName,
    required String providerId,
    required String providerName,
    required String subject,
    required String description,
  }) async {
    try {
      await _firestore.collection(reportsCollection).add({
        'clientId': clientId,
        'clientName': clientName,
        'providerId': providerId,
        'providerName': providerName,
        'subject': subject,
        'description': description,
        'status': 'pending',
        'adminFeedback': '',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw Exception('Failed to submit report: $e');
    }
  }

  static Future<List<Map<String, dynamic>>> getAllReports() async {
    try {
      final snap = await _firestore.collection(reportsCollection).get();
      final reports = snap.docs
          .map((doc) => {'id': doc.id, ...doc.data()})
          .toList();
      _sortByCreatedAtDesc(reports);
      return reports;
    } catch (e) {
      throw Exception('Failed to fetch reports: $e');
    }
  }

  static Future<List<Map<String, dynamic>>> getClientReports(
    String clientId,
  ) async {
    try {
      final snap = await _firestore
          .collection(reportsCollection)
          .where('clientId', isEqualTo: clientId)
          .get();
      final reports = snap.docs
          .map((doc) => {'id': doc.id, ...doc.data()})
          .toList();
      _sortByCreatedAtDesc(reports);
      return reports;
    } catch (e) {
      throw Exception('Failed to fetch client reports: $e');
    }
  }

  static Future<void> sendReportFeedback({
    required String reportId,
    required String feedback,
  }) async {
    try {
      await _firestore.collection(reportsCollection).doc(reportId).update({
        'adminFeedback': feedback,
        'status': 'reviewed',
        'feedbackAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw Exception('Failed to send feedback: $e');
    }
  }

  static Future<void> markNotificationAsRead(String reportId) async {
    try {
      await _firestore.collection(reportsCollection).doc(reportId).update({
        'notificationRead': true,
        'readAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw Exception('Failed to mark notification as read: $e');
    }
  }

  static Future<void> approveProvider(String userId, bool approved) async {
    try {
      final updates = {
        'isApproved': approved,
        'updatedAt': FieldValue.serverTimestamp(),
      };
      await _firestore
          .collection(providersCollection)
          .doc(userId)
          .set(updates, SetOptions(merge: true));
      await _firestore
          .collection(usersCollection)
          .doc(userId)
          .set(updates, SetOptions(merge: true));
    } catch (e) {
      throw Exception('Failed to update provider approval: $e');
    }
  }

  // ──────────────────────────────────────────────────────────────────────────
  // NOTIFICATION OPERATIONS
  // ──────────────────────────────────────────────────────────────────────────

  static Future<void> createNotification({
    required String userId,
    required String type,
    required String title,
    required String message,
    String bookingId = '',
    Map<String, dynamic>? extra,
  }) async {
    try {
      await _firestore.collection(notificationsCollection).add({
        'userId': userId,
        'type': type,
        'title': title,
        'message': message,
        'bookingId': bookingId,
        'extra': extra ?? const {},
        'read': false,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (_) {
      // Notifications are best-effort; don't block the primary action.
    }
  }

  static Stream<List<Map<String, dynamic>>> streamUserNotifications(
    String userId,
  ) {
    return _firestore
        .collection(notificationsCollection)
        .where('userId', isEqualTo: userId)
        .snapshots()
        .map((snap) {
          final list = snap.docs
              .map((d) => {'id': d.id, ...d.data()})
              .toList();
          list.sort((a, b) {
            final at = a['createdAt'];
            final bt = b['createdAt'];
            final ams = at is Timestamp ? at.millisecondsSinceEpoch : 0;
            final bms = bt is Timestamp ? bt.millisecondsSinceEpoch : 0;
            return bms.compareTo(ams);
          });
          return list;
        });
  }

  static Future<int> getUnreadNotificationCount(String userId) async {
    try {
      final snap = await _firestore
          .collection(notificationsCollection)
          .where('userId', isEqualTo: userId)
          .where('read', isEqualTo: false)
          .get();
      return snap.docs.length;
    } catch (_) {
      return 0;
    }
  }

  static Future<void> markAppNotificationRead(String notificationId) async {
    try {
      await _firestore
          .collection(notificationsCollection)
          .doc(notificationId)
          .update({
            'read': true,
            'readAt': FieldValue.serverTimestamp(),
          });
    } catch (_) {}
  }

  // ──────────────────────────────────────────────────────────────────────────
  // RATE / HOURS / PAYMENT HELPERS
  // ──────────────────────────────────────────────────────────────────────────

  static Future<void> updateBookingRate({
    required String bookingId,
    required String newRate,
  }) async {
    try {
      await _firestore.collection(bookingsCollection).doc(bookingId).update({
        'agreedPrice': newRate,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw Exception('Failed to update booking rate: $e');
    }
  }

  static Future<void> submitHoursWorked({
    required String bookingId,
    required double hours,
  }) async {
    try {
      final doc = await _firestore
          .collection(bookingsCollection)
          .doc(bookingId)
          .get();
      final rate = _toDouble(doc.data()?['agreedPrice']);
      final total = rate * hours;
      await _firestore.collection(bookingsCollection).doc(bookingId).update({
        'hoursWorked': hours,
        'totalAmount': total,
        'status': 'awaiting_payment',
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw Exception('Failed to submit hours: $e');
    }
  }

  static Future<void> markBookingPaid({
    required String bookingId,
    int paymentTimePointsToRedeem = 0,
  }) async {
    try {
      final bookingRef =
          _firestore.collection(bookingsCollection).doc(bookingId);

      // Single transaction: read booking, no-op if already recorded, otherwise
      // write the commission ledger entry + booking flags + client/provider
      // lifetime counters. Belt-and-suspenders idempotency: in-doc flag +
      // (in the ledger query that admin/UI use) bookingId+type uniqueness.
      String providerId = '';
      String clientId = '';
      String requestId = '';
      int paidAmountTaka = 0;
      int pointsEarnedByClient = 0;
      int commissionAmount = 0;
      int providerNetTaka = 0;
      bool wasAlreadyRecorded = false;

      await _firestore.runTransaction((tx) async {
        // ── PHASE 1: ALL READS ────────────────────────────────────────
        // Firestore transactions require every read to happen before any
        // write. We read booking + provider + (optionally) client docs
        // up front, compute all amounts, then issue every write.
        final snap = await tx.get(bookingRef);
        final data = snap.data() ?? {};

        // Use commissionRecorded as the payment-side idempotency flag.
        // Points earning is now gated on a qualifying review (rating +
        // text), so it's tracked separately via pointsRecorded.
        if (data['commissionRecorded'] == true) {
          wasAlreadyRecorded = true;
          return;
        }

        providerId = (data['providerId'] ?? '').toString();
        clientId = (data['clientId'] ?? '').toString();
        requestId = (data['requestId'] ?? '').toString();

        // The hourly rate captured at booking creation (used for the
        // redemption-cap check). Fallback to the legacy string field for
        // bookings created before this feature shipped.
        final agreedHourlyRateTaka = data['agreedAmountTaka'] is num
            ? (data['agreedAmountTaka'] as num).toInt()
            : _parseAgreedAmountTaka(
                (data['agreedPrice'] ?? '').toString(),
              );
        // The actual bill = hours × rate, written by submitHoursWorked.
        // This is what the client pays and what commission applies to.
        // Falls back to the hourly rate for bookings without hours data.
        final billedAmountTaka = _toInt(data['totalAmount']) > 0
            ? _toInt(data['totalAmount'])
            : agreedHourlyRateTaka;

        // Existing booking-time redemption (set in createBooking).
        final bookingTimePointsRedeemed = _toInt(data['pointsRedeemed']);
        final bookingTimeDiscount = _toInt(data['discountTaka']) > 0
            ? _toInt(data['discountTaka'])
            : computeDiscountForPoints(bookingTimePointsRedeemed);

        // Payment-time redemption (NEW). Validate against the live
        // balance and the remaining bill, then add on top of any
        // booking-time redemption.
        int paymentDiscount = 0;
        int finalPointsRedeemed = bookingTimePointsRedeemed;
        DocumentReference<Map<String, dynamic>>? redeemClientUserRef;
        DocumentReference<Map<String, dynamic>>? redeemClientRoleRef;
        int currentRedeemBalance = 0;
        int currentRedeemLifetime = 0;
        if (paymentTimePointsToRedeem > 0) {
          if (paymentTimePointsToRedeem < minPointsRedemption) {
            throw Exception(
              'Minimum redemption is $minPointsRedemption points',
            );
          }
          if (clientId.isEmpty) {
            throw Exception('Booking has no client to redeem against');
          }
          redeemClientUserRef =
              _firestore.collection(usersCollection).doc(clientId);
          redeemClientRoleRef =
              _firestore.collection(clientsCollection).doc(clientId);
          final clientSnap = await tx.get(redeemClientUserRef);
          currentRedeemBalance =
              _toInt(clientSnap.data()?['pointsBalance']);
          currentRedeemLifetime =
              _toInt(clientSnap.data()?['pointsLifetimeRedeemed']);
          if (paymentTimePointsToRedeem > currentRedeemBalance) {
            throw Exception(
              'Not enough points (have $currentRedeemBalance, need $paymentTimePointsToRedeem)',
            );
          }
          paymentDiscount =
              computeDiscountForPoints(paymentTimePointsToRedeem);
          // Combined discount can't exceed the bill.
          if (bookingTimeDiscount + paymentDiscount > billedAmountTaka) {
            throw Exception(
              'Discount cannot exceed the bill amount',
            );
          }
          finalPointsRedeemed =
              bookingTimePointsRedeemed + paymentTimePointsToRedeem;
        }

        final totalDiscountTaka = bookingTimeDiscount + paymentDiscount;

        paidAmountTaka =
            (billedAmountTaka - totalDiscountTaka).clamp(0, billedAmountTaka);
        // Pending points the client *will* earn IF they leave a
        // qualifying review (stars + written review). Snapshotted here so
        // the review-time awarding code has a stable amount to credit.
        pointsEarnedByClient = computePointsForAmount(paidAmountTaka);
        // Commission is applied ONCE on the full billed amount. The
        // platform absorbs any points discount.
        commissionAmount = computeCommissionForAmount(billedAmountTaka);
        providerNetTaka = billedAmountTaka - commissionAmount;

        DocumentReference<Map<String, dynamic>>? providerUserRef;
        DocumentReference<Map<String, dynamic>>? providerRoleRef;
        int currentLifetimeNet = 0;
        int currentLifetimeCommission = 0;
        double currentLegacyGross = 0;
        int currentProviderJobs = 0;
        if (providerId.isNotEmpty) {
          providerUserRef =
              _firestore.collection(usersCollection).doc(providerId);
          providerRoleRef =
              _firestore.collection(providersCollection).doc(providerId);
          final providerSnap = await tx.get(providerRoleRef);
          final pData = providerSnap.data() ?? {};
          currentLifetimeNet = _toInt(pData['lifetimeEarningsTaka']);
          currentLifetimeCommission =
              _toInt(pData['lifetimeCommissionPaidTaka']);
          currentLegacyGross = _toDouble(pData['totalEarnings']);
          currentProviderJobs =
              _toInt(pData['jobsCompleted'] ?? pData['jobs']);
        }

        // ── PHASE 2: ALL WRITES ───────────────────────────────────────
        tx.update(bookingRef, {
          'paid': true,
          'status': 'completed',
          'paidAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
          // Overwrite agreedAmountTaka with the FINAL billed amount so the
          // earnings UI shows the full job total (not the per-hour rate).
          'agreedAmountTaka': billedAmountTaka,
          'agreedHourlyRateTaka': agreedHourlyRateTaka,
          'billedAmountTaka': billedAmountTaka,
          'paidAmountTaka': paidAmountTaka,
          // Cumulative redemption: booking-time + payment-time.
          'pointsRedeemed': finalPointsRedeemed,
          'discountTaka': totalDiscountTaka,
          'paymentTimePointsRedeemed': paymentTimePointsToRedeem,
          'commissionAmount': commissionAmount,
          'commissionRate': commissionRate,
          'providerNetTaka': providerNetTaka,
          // Pending — credited when the client posts a qualifying review.
          'pointsEarnedByClient': pointsEarnedByClient,
          'pointsRecorded': false,
          'commissionRecorded': true,
        });

        // Ledger entry: platform charges commission against the provider.
        if (providerId.isNotEmpty && commissionAmount > 0) {
          final commRef =
              _firestore.collection(transactionsCollection).doc();
          tx.set(commRef, {
            'userId': providerId,
            'userRole': 'provider',
            'type': 'commission_charged',
            'amount': commissionAmount,
            'currency': 'BDT',
            'bookingId': bookingId,
            'description':
                '10% commission on ৳$billedAmountTaka (net ৳$providerNetTaka)',
            'createdAt': FieldValue.serverTimestamp(),
          });
        }

        // Payment-time redemption: write ledger entry + decrement balance.
        if (paymentTimePointsToRedeem > 0 &&
            redeemClientUserRef != null &&
            redeemClientRoleRef != null) {
          final redeemRef =
              _firestore.collection(transactionsCollection).doc();
          tx.set(redeemRef, {
            'userId': clientId,
            'userRole': 'client',
            'type': 'points_redeemed',
            'amount': paymentTimePointsToRedeem,
            'currency': 'POINTS',
            'bookingId': bookingId,
            'description':
                'Redeemed $paymentTimePointsToRedeem pts at payment (৳$paymentDiscount off)',
            'createdAt': FieldValue.serverTimestamp(),
          });
          final clientUpdate = {
            'pointsBalance':
                currentRedeemBalance - paymentTimePointsToRedeem,
            'pointsLifetimeRedeemed':
                currentRedeemLifetime + paymentTimePointsToRedeem,
            'updatedAt': FieldValue.serverTimestamp(),
          };
          tx.set(redeemClientUserRef, clientUpdate, SetOptions(merge: true));
          tx.set(redeemClientRoleRef, clientUpdate, SetOptions(merge: true));
        }

        // Update provider lifetime counters + keep the legacy gross
        // totalEarnings / jobsCompleted fields rolling for back-compat.
        if (providerUserRef != null && providerRoleRef != null) {
          final providerUpdate = {
            'lifetimeEarningsTaka':
                currentLifetimeNet + providerNetTaka,
            'lifetimeCommissionPaidTaka':
                currentLifetimeCommission + commissionAmount,
            'totalEarnings':
                currentLegacyGross + paidAmountTaka.toDouble(),
            'jobsCompleted': currentProviderJobs + 1,
            'jobs': currentProviderJobs + 1,
            'totalJobs': currentProviderJobs + 1,
            'updatedAt': FieldValue.serverTimestamp(),
          };
          tx.set(providerRoleRef, providerUpdate, SetOptions(merge: true));
          tx.set(providerUserRef, providerUpdate, SetOptions(merge: true));
        }
      });

      if (wasAlreadyRecorded) return;

      // Mirror status onto the originating service request (outside the
      // transaction — non-critical for ledger correctness).
      if (requestId.isNotEmpty) {
        await _firestore.collection(requestsCollection).doc(requestId).update({
          'status': 'completed',
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
    } catch (e) {
      throw Exception('Failed to mark booking paid: $e');
    }
  }

  /// Idempotent: writes a `points_earned` ledger entry and bumps the
  /// client's points balance + lifetime-earned counter ONCE for the given
  /// booking. Triggered from createReview when the client posts a
  /// qualifying review (rating + non-empty text). Skipped if the booking
  /// hasn't been paid, or points have already been recorded.
  static Future<void> _awardPointsForReview({
    required String bookingId,
    required String clientId,
  }) async {
    final bookingRef =
        _firestore.collection(bookingsCollection).doc(bookingId);
    final clientUserRef =
        _firestore.collection(usersCollection).doc(clientId);
    final clientRoleRef =
        _firestore.collection(clientsCollection).doc(clientId);
    final ledgerRef = _firestore.collection(transactionsCollection).doc();

    await _firestore.runTransaction((tx) async {
      // ── PHASE 1: ALL READS ──────────────────────────────────────────
      final bookingSnap = await tx.get(bookingRef);
      final bookingData = bookingSnap.data();
      if (bookingData == null) return;
      if (bookingData['paid'] != true) return;
      if (bookingData['pointsRecorded'] == true) return;

      final pointsToAward = _toInt(bookingData['pointsEarnedByClient']);
      final paidAmountTaka = _toInt(bookingData['paidAmountTaka']);

      // No reward to issue (e.g. paid amount < 100 taka) — still flip the
      // flag so we don't keep re-checking on subsequent review edits.
      if (pointsToAward <= 0) {
        tx.update(bookingRef, {
          'pointsRecorded': true,
          'pointsAwardedAt': FieldValue.serverTimestamp(),
        });
        return;
      }

      final clientSnap = await tx.get(clientUserRef);
      final balance = _toInt(clientSnap.data()?['pointsBalance']);
      final lifetimeEarned =
          _toInt(clientSnap.data()?['pointsLifetimeEarned']);

      // ── PHASE 2: ALL WRITES ─────────────────────────────────────────
      tx.set(ledgerRef, {
        'userId': clientId,
        'userRole': 'client',
        'type': 'points_earned',
        'amount': pointsToAward,
        'currency': 'POINTS',
        'bookingId': bookingId,
        'description':
            'Earned $pointsToAward pts for reviewing ৳$paidAmountTaka job',
        'createdAt': FieldValue.serverTimestamp(),
      });

      final clientUpdate = {
        'pointsBalance': balance + pointsToAward,
        'pointsLifetimeEarned': lifetimeEarned + pointsToAward,
        'updatedAt': FieldValue.serverTimestamp(),
      };
      tx.set(clientUserRef, clientUpdate, SetOptions(merge: true));
      tx.set(clientRoleRef, clientUpdate, SetOptions(merge: true));

      tx.update(bookingRef, {
        'pointsRecorded': true,
        'pointsAwardedAt': FieldValue.serverTimestamp(),
      });
    });
  }

  /// How many points the client *will* earn when they post a qualifying
  /// review for this booking. Returns 0 if already credited or unpaid.
  static Future<int> getPendingReviewPoints(String bookingId) async {
    if (bookingId.isEmpty) return 0;
    try {
      final doc = await _firestore
          .collection(bookingsCollection)
          .doc(bookingId)
          .get();
      final data = doc.data();
      if (data == null) return 0;
      if (data['paid'] != true) return 0;
      if (data['pointsRecorded'] == true) return 0;
      return _toInt(data['pointsEarnedByClient']);
    } catch (_) {
      return 0;
    }
  }

  // ──────────────────────────────────────────────────────────────────────────
  // POINTS / COMMISSION READ HELPERS
  // ──────────────────────────────────────────────────────────────────────────

  static Future<int> getPointsBalance(String userId) async {
    if (userId.isEmpty) return 0;
    try {
      final doc =
          await _firestore.collection(usersCollection).doc(userId).get();
      return _toInt(doc.data()?['pointsBalance']);
    } catch (_) {
      return 0;
    }
  }

  static Future<Map<String, int>> getPointsSummary(String userId) async {
    if (userId.isEmpty) {
      return {'balance': 0, 'lifetimeEarned': 0, 'lifetimeRedeemed': 0};
    }
    try {
      final doc =
          await _firestore.collection(usersCollection).doc(userId).get();
      final data = doc.data() ?? {};
      return {
        'balance': _toInt(data['pointsBalance']),
        'lifetimeEarned': _toInt(data['pointsLifetimeEarned']),
        'lifetimeRedeemed': _toInt(data['pointsLifetimeRedeemed']),
      };
    } catch (_) {
      return {'balance': 0, 'lifetimeEarned': 0, 'lifetimeRedeemed': 0};
    }
  }

  /// Client-facing points history (earned + redeemed). Newest first.
  static Future<List<Map<String, dynamic>>> getPointsHistory(
    String userId, {
    int limit = 50,
  }) async {
    if (userId.isEmpty) return const [];
    try {
      // Fetch without orderBy to dodge composite-index requirements; sort
      // client-side. This collection is per-user and small in practice.
      final snap = await _firestore
          .collection(transactionsCollection)
          .where('userId', isEqualTo: userId)
          .where('type', whereIn: ['points_earned', 'points_redeemed'])
          .limit(limit * 2)
          .get();
      final items = snap.docs
          .map((d) => {'id': d.id, ...d.data()})
          .toList();
      items.sort((a, b) {
        final ta = a['createdAt'];
        final tb = b['createdAt'];
        final ma = ta is Timestamp ? ta.millisecondsSinceEpoch : 0;
        final mb = tb is Timestamp ? tb.millisecondsSinceEpoch : 0;
        return mb.compareTo(ma);
      });
      return items.take(limit).toList();
    } catch (_) {
      return const [];
    }
  }

  /// Provider-facing earnings history. Returns commission_charged ledger
  /// entries enriched with the booking's gross/net snapshot.
  static Future<List<Map<String, dynamic>>> getProviderEarningsHistory(
    String providerId, {
    int limit = 50,
  }) async {
    if (providerId.isEmpty) return const [];
    try {
      final snap = await _firestore
          .collection(transactionsCollection)
          .where('userId', isEqualTo: providerId)
          .where('type', isEqualTo: 'commission_charged')
          .limit(limit * 2)
          .get();
      final entries = snap.docs
          .map((d) => {'id': d.id, ...d.data()})
          .toList();
      entries.sort((a, b) {
        final ta = a['createdAt'];
        final tb = b['createdAt'];
        final ma = ta is Timestamp ? ta.millisecondsSinceEpoch : 0;
        final mb = tb is Timestamp ? tb.millisecondsSinceEpoch : 0;
        return mb.compareTo(ma);
      });
      // Hydrate with booking gross/net for the UI.
      final out = <Map<String, dynamic>>[];
      for (final e in entries.take(limit)) {
        final bookingId = (e['bookingId'] ?? '').toString();
        Map<String, dynamic>? booking;
        if (bookingId.isNotEmpty) {
          try {
            final b = await _firestore
                .collection(bookingsCollection)
                .doc(bookingId)
                .get();
            booking = b.data();
          } catch (_) {}
        }
        out.add({
          ...e,
          'agreedAmountTaka':
              _toInt(booking?['agreedAmountTaka']),
          'providerNetTaka': _toInt(booking?['providerNetTaka']),
          'clientId': (booking?['clientId'] ?? '').toString(),
          'specialty':
              (booking?['specialty'] ?? booking?['serviceType'] ?? '')
                  .toString(),
        });
      }
      return out;
    } catch (_) {
      return const [];
    }
  }

  /// Admin-side query: list ledger entries with optional filters. Sort
  /// newest-first client-side to avoid composite-index requirements.
  static Future<List<Map<String, dynamic>>> getTransactions({
    String? type,
    DateTime? since,
    DateTime? until,
    int limit = 200,
  }) async {
    try {
      Query<Map<String, dynamic>> q =
          _firestore.collection(transactionsCollection);
      if (type != null && type.isNotEmpty) {
        q = q.where('type', isEqualTo: type);
      }
      final snap = await q.limit(limit * 2).get();
      var items = snap.docs
          .map((d) => {'id': d.id, ...d.data()})
          .where((it) {
        final ts = it['createdAt'];
        if (ts is! Timestamp) return true;
        final dt = ts.toDate();
        if (since != null && dt.isBefore(since)) return false;
        if (until != null && dt.isAfter(until)) return false;
        return true;
      }).toList();
      items.sort((a, b) {
        final ta = a['createdAt'];
        final tb = b['createdAt'];
        final ma = ta is Timestamp ? ta.millisecondsSinceEpoch : 0;
        final mb = tb is Timestamp ? tb.millisecondsSinceEpoch : 0;
        return mb.compareTo(ma);
      });
      return items.take(limit).toList();
    } catch (_) {
      return const [];
    }
  }

  /// Validate a redemption attempt before submitting a booking. Returns a
  /// record with `ok` true/false and a human-readable error.
  static Future<({bool ok, String? error})> validatePointsRedemption({
    required String userId,
    required int pointsToRedeem,
    required int agreedAmountTaka,
  }) async {
    if (pointsToRedeem == 0) return (ok: true, error: null);
    if (pointsToRedeem < minPointsRedemption) {
      return (
        ok: false,
        error: 'Minimum redemption is $minPointsRedemption points',
      );
    }
    final balance = await getPointsBalance(userId);
    if (pointsToRedeem > balance) {
      return (
        ok: false,
        error: 'You only have $balance points',
      );
    }
    final discount = computeDiscountForPoints(pointsToRedeem);
    if (discount > agreedAmountTaka) {
      return (
        ok: false,
        error: 'Discount cannot exceed the agreed amount',
      );
    }
    return (ok: true, error: null);
  }

  static String _canonicalCategory(String raw) {
    final s = raw.trim().toLowerCase();
    if (s.isEmpty) return '';
    if (s.contains('electric')) return 'electrician';
    if (s.contains('plumb')) return 'plumber';
    if (s.contains('clean')) return 'cleaner';
    if (s.contains('paint')) return 'painter';
    return s;
  }

  // ──────────────────────────────────────────────────────────────────────────
  // ADMIN DASHBOARD ANALYTICS
  // ──────────────────────────────────────────────────────────────────────────

  static Future<Map<String, dynamic>> getAdminDashboardStats() async {
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final monthStart = DateTime(now.year, now.month, 1);

    final results = await Future.wait([
      _firestore.collection(usersCollection).get(),
      _firestore.collection(requestsCollection).get(),
      _firestore.collection(bookingsCollection).get(),
      _firestore.collection(reportsCollection).get(),
      _firestore.collection(reviewsCollection).get(),
      _firestore.collection(providersCollection).get(),
    ]);

    final usersSnap = results[0];
    final bookingsSnap = results[2];
    final reportsSnap = results[3];
    final reviewsSnap = results[4];

    int totalUsers = 0, totalClients = 0, totalProviders = 0;
    int newUsersThisMonth = 0;
    for (final doc in usersSnap.docs) {
      final data = doc.data();
      final type = (data['userType'] ?? '').toString();
      if (type == 'admin') continue;
      totalUsers++;
      if (type == 'client') totalClients++;
      if (type == 'provider') totalProviders++;
      final createdAt = (data['createdAt'] as Timestamp?)?.toDate();
      if (createdAt != null && createdAt.isAfter(monthStart)) newUsersThisMonth++;
    }

    // Build a providerId → specialty index so we can correctly classify
    // bookings whose own specialty/category fields were never recorded.
    final providersSnap = results[5];
    final Map<String, String> providerSpecialty = {};
    for (final doc in providersSnap.docs) {
      final data = doc.data();
      final spec = (data['specialty'] ??
              data['serviceType'] ??
              '')
          .toString();
      if (spec.isNotEmpty) providerSpecialty[doc.id] = spec;
    }

    int bookingsToday = 0, completedBookings = 0, newBookingsThisMonth = 0;
    final Map<String, int> categoryCount = {};
    for (final doc in bookingsSnap.docs) {
      final data = doc.data();
      final createdAt = (data['createdAt'] as Timestamp?)?.toDate();
      if (createdAt != null && createdAt.isAfter(todayStart)) bookingsToday++;
      if (createdAt != null && createdAt.isAfter(monthStart)) newBookingsThisMonth++;
      if ((data['status'] ?? '') == 'completed') completedBookings++;

      var rawCat = (data['specialty'] ??
              data['category'] ??
              data['serviceType'] ??
              data['categoryKey'] ??
              '')
          .toString();
      if (rawCat.isEmpty) {
        final pid = (data['providerId'] ?? '').toString();
        if (pid.isNotEmpty) {
          rawCat = providerSpecialty[pid] ?? '';
        }
      }
      // Skip uncategorized bookings rather than dumping them into 'Other'
      // (which the dashboard merges into Painter and produced the bug).
      if (rawCat.isEmpty) continue;
      final cat = _normalizeCategoryLabel(rawCat);
      categoryCount[cat] = (categoryCount[cat] ?? 0) + 1;
    }

    int newProvidersThisMonth = 0, activeProviders = 0;
    for (final doc in providersSnap.docs) {
      final data = doc.data();
      final createdAt = (data['createdAt'] as Timestamp?)?.toDate();
      if (createdAt != null && createdAt.isAfter(monthStart)) newProvidersThisMonth++;
      if (data['isActive'] == true) activeProviders++;
    }

    int resolvedReports = 0;
    for (final doc in reportsSnap.docs) {
      if ((doc.data()['status'] ?? '') == 'reviewed') resolvedReports++;
    }

    double totalRating = 0;
    for (final doc in reviewsSnap.docs) {
      totalRating += ((doc.data()['rating'] ?? 0) as num).toDouble();
    }
    final totalReviews = reviewsSnap.docs.length;
    final avgRating = totalReviews == 0 ? 0.0 : totalRating / totalReviews;

    final totalBookings = bookingsSnap.docs.length;
    final totalReports = reportsSnap.docs.length;
    final bookingCompletionPct = totalBookings == 0 ? 0 : (completedBookings * 100 ~/ totalBookings);
    final resolvedReportsPct = totalReports == 0 ? 0 : (resolvedReports * 100 ~/ totalReports);
    final activeProviderPct = totalProviders == 0 ? 0 : (activeProviders * 100 ~/ totalProviders);

    return {
      'totalUsers': totalUsers,
      'totalClients': totalClients,
      'totalProviders': totalProviders,
      'activeProviders': activeProviders,
      'totalRequests': results[1].docs.length,
      'totalBookings': totalBookings,
      'completedBookings': completedBookings,
      'totalReports': totalReports,
      'resolvedReports': resolvedReports,
      'totalReviews': totalReviews,
      'bookingsToday': bookingsToday,
      'newUsersThisMonth': newUsersThisMonth,
      'newProvidersThisMonth': newProvidersThisMonth,
      'newBookingsThisMonth': newBookingsThisMonth,
      'bookingCompletionPct': bookingCompletionPct,
      'activeProviderPct': activeProviderPct,
      'resolvedReportsPct': resolvedReportsPct,
      'avgRating': avgRating,
      'categoryBreakdown': categoryCount,
    };
  }

  static String _normalizeCategoryLabel(String raw) {
    final s = raw.trim().toLowerCase();
    if (s.contains('plumb')) return 'Plumbing';
    if (s.contains('clean')) return 'Cleaning';
    if (s.contains('electric')) return 'Electrical';
    if (s.contains('paint')) return 'Painter';
    if (s.isEmpty) return 'Other';
    // Title-case the raw value so counts merge correctly
    return raw.trim().isEmpty ? 'Other' : raw.trim()[0].toUpperCase() + raw.trim().substring(1).toLowerCase();
  }

  // ──────────────────────────────────────────────────────────────────────────
  // REVENUE & EARNINGS
  // ──────────────────────────────────────────────────────────────────────────

  static Future<Map<String, dynamic>> getRevenueData() async {
    final results = await Future.wait([
      _firestore.collection(bookingsCollection).get(),
      _firestore.collection(usersCollection).get(),
      _firestore.collection(transactionsCollection).get(),
    ]);

    final bookingsSnap = results[0];
    final usersSnap = results[1];
    final transactionsSnap = results[2];

    final Map<String, Map<String, dynamic>> userMap = {};
    for (final doc in usersSnap.docs) {
      userMap[doc.id] = {'id': doc.id, ...doc.data()};
    }

    // Prepare last-6-months buckets
    final now = DateTime.now();
    final Map<String, double> monthlyAmounts = {};
    final Map<String, int> monthlyCounts = {};
    for (int i = 5; i >= 0; i--) {
      final m = DateTime(now.year, now.month - i, 1);
      final key =
          '${m.year}-${m.month.toString().padLeft(2, '0')}';
      monthlyAmounts[key] = 0;
      monthlyCounts[key] = 0;
    }

    final Map<String, double> providerEarnings = {};
    final Map<String, int> providerJobCount = {};
    final Map<String, double> clientSpending = {};
    final Map<String, int> clientJobCount = {};
    final Map<String, List<Map<String, dynamic>>> providerTxns = {};
    final Map<String, List<Map<String, dynamic>>> clientTxns = {};
    double totalRevenue = 0;

    for (final doc in bookingsSnap.docs) {
      final data = doc.data();
      final status = (data['status'] ?? '').toString();
      if (status != 'completed') continue;

      final amount = _toDouble(data['totalAmount']) > 0
          ? _toDouble(data['totalAmount'])
          : _toDouble(data['agreedPrice']);
      if (amount <= 0) continue;

      totalRevenue += amount;
      final providerId = (data['providerId'] ?? '').toString();
      final clientId = (data['clientId'] ?? '').toString();
      final createdAt = data['createdAt'] as Timestamp?;

      if (createdAt != null) {
        final dt = createdAt.toDate();
        final key =
            '${dt.year}-${dt.month.toString().padLeft(2, '0')}';
        if (monthlyAmounts.containsKey(key)) {
          monthlyAmounts[key] = (monthlyAmounts[key] ?? 0) + amount;
          monthlyCounts[key] = (monthlyCounts[key] ?? 0) + 1;
        }
      }

      if (providerId.isNotEmpty) {
        providerEarnings[providerId] =
            (providerEarnings[providerId] ?? 0) + amount;
        providerJobCount[providerId] =
            (providerJobCount[providerId] ?? 0) + 1;
        providerTxns.putIfAbsent(providerId, () => []).add({
          'id': doc.id,
          'amount': amount,
          'clientId': clientId,
          'createdAt': data['createdAt'],
          'status': status,
          'specialty': (data['specialty'] ?? data['serviceType'] ?? '').toString(),
        });
      }

      if (clientId.isNotEmpty) {
        clientSpending[clientId] =
            (clientSpending[clientId] ?? 0) + amount;
        clientJobCount[clientId] =
            (clientJobCount[clientId] ?? 0) + 1;
        clientTxns.putIfAbsent(clientId, () => []).add({
          'id': doc.id,
          'amount': amount,
          'providerId': providerId,
          'createdAt': data['createdAt'],
          'status': status,
          'specialty': (data['specialty'] ?? data['serviceType'] ?? '').toString(),
        });
      }
    }

    // Build user earnings list
    final List<Map<String, dynamic>> userEarnings = [];

    for (final entry in providerEarnings.entries) {
      final user = userMap[entry.key] ?? {};
      userEarnings.add({
        'userId': entry.key,
        'name': (user['displayName'] ?? 'Provider').toString(),
        'type': 'provider',
        'amount': entry.value,
        'transactionCount': providerJobCount[entry.key] ?? 0,
        'transactions': providerTxns[entry.key] ?? [],
        'userMap': user,
      });
    }

    for (final entry in clientSpending.entries) {
      final user = userMap[entry.key] ?? {};
      userEarnings.add({
        'userId': entry.key,
        'name': (user['displayName'] ?? 'Client').toString(),
        'type': 'client',
        'amount': entry.value,
        'transactionCount': clientJobCount[entry.key] ?? 0,
        'transactions': clientTxns[entry.key] ?? [],
        'userMap': user,
      });
    }

    userEarnings.sort((a, b) =>
        (b['amount'] as double).compareTo(a['amount'] as double));

    // Monthly list ordered
    const monthNames = [
      '', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    final List<Map<String, dynamic>> monthlyRevenue =
        monthlyAmounts.entries.map((e) {
      final parts = e.key.split('-');
      final month = int.parse(parts[1]);
      final year = int.parse(parts[0]);
      return {
        'key': e.key,
        'label': '${monthNames[month]} ${year.toString().substring(2)}',
        'amount': e.value,
        'count': monthlyCounts[e.key] ?? 0,
      };
    }).toList();
    monthlyRevenue.sort(
        (a, b) => (a['key'] as String).compareTo(b['key'] as String));

    // Forecast: linear trend from last 2 non-zero months
    double forecastNextMonth = 0;
    double forecastGrowthPct = 0;
    final nonZero = monthlyRevenue
        .where((m) => (m['amount'] as double) > 0)
        .toList();
    if (nonZero.length >= 2) {
      final last = (nonZero.last['amount'] as double);
      final secondLast = (nonZero[nonZero.length - 2]['amount'] as double);
      final rate = secondLast == 0 ? 0.0 : (last - secondLast) / secondLast;
      forecastNextMonth = last * (1 + rate);
      forecastGrowthPct = rate * 100;
    } else if (nonZero.isNotEmpty) {
      forecastNextMonth = (nonZero.last['amount'] as double);
    }

    // Ledger aggregates — drives the new commission/points panels on the
    // admin revenue screen without touching the existing keys above.
    int totalCommissionTaka = 0;
    int totalPointsIssued = 0;
    int totalPointsRedeemed = 0;
    final Map<String, int> commissionByMonth = {};
    for (int i = 5; i >= 0; i--) {
      final m = DateTime(now.year, now.month - i, 1);
      final key = '${m.year}-${m.month.toString().padLeft(2, '0')}';
      commissionByMonth[key] = 0;
    }

    for (final doc in transactionsSnap.docs) {
      final data = doc.data();
      final type = (data['type'] ?? '').toString();
      final amount = _toInt(data['amount']);
      final ts = data['createdAt'];
      switch (type) {
        case 'commission_charged':
          totalCommissionTaka += amount;
          if (ts is Timestamp) {
            final dt = ts.toDate();
            final key =
                '${dt.year}-${dt.month.toString().padLeft(2, '0')}';
            if (commissionByMonth.containsKey(key)) {
              commissionByMonth[key] =
                  (commissionByMonth[key] ?? 0) + amount;
            }
          }
          break;
        case 'points_earned':
          totalPointsIssued += amount;
          break;
        case 'points_redeemed':
          totalPointsRedeemed += amount;
          break;
      }
    }

    final platformNetTaka = totalCommissionTaka -
        (totalPointsRedeemed * pointValueTaka).round();

    return {
      'totalRevenue': totalRevenue,
      'forecastNextMonth': forecastNextMonth,
      'forecastGrowthPct': forecastGrowthPct,
      'userEarnings': userEarnings,
      'monthlyRevenue': monthlyRevenue,
      'totalCommissionTaka': totalCommissionTaka,
      'totalPointsIssued': totalPointsIssued,
      'totalPointsRedeemed': totalPointsRedeemed,
      'platformNetTaka': platformNetTaka,
      'commissionByMonth': commissionByMonth,
    };
  }

  static Future<List<Map<String, dynamic>>> getRecentActivities({int limit = 8}) async {
    // Fetch without orderBy to avoid requiring composite Firestore indexes.
    // Each collection is fetched independently; results are merged and sorted client-side.
    final activities = <Map<String, dynamic>>[];
    final fetchCount = limit * 3;

    Future<List<Map<String, dynamic>>> safeFetch(String collection) async {
      try {
        final snap = await _firestore.collection(collection).limit(fetchCount).get();
        return snap.docs.map((d) => {'id': d.id, ...d.data()}).toList();
      } catch (_) {
        return [];
      }
    }

    final results = await Future.wait([
      safeFetch(bookingsCollection),
      safeFetch(reportsCollection),
      safeFetch(usersCollection),
      safeFetch(reviewsCollection),
    ]);

    // Build a userId → displayName map so legacy records that never persisted
    // a denormalized name still surface a real name in the activity feed.
    final Map<String, String> userNames = {};
    for (final data in results[2]) {
      final id = (data['id'] ?? '').toString();
      final name = (data['displayName'] ?? '').toString();
      if (id.isNotEmpty && name.isNotEmpty) userNames[id] = name;
    }

    String resolveName(Map<String, dynamic> data, String preferredKey,
        String idKey) {
      final stored = (data[preferredKey] ?? '').toString();
      if (stored.isNotEmpty) return stored;
      final id = (data[idKey] ?? '').toString();
      return userNames[id] ?? 'Unknown';
    }

    // Bookings — emit a "task complete" item separately so admin notifications
    // can surface only feedback + completed tasks while the activity feed keeps
    // the full history.
    for (final data in results[0]) {
      final status = (data['status'] ?? '').toString();
      activities.add({
        'type': 'booking',
        'status': status,
        'name': resolveName(data, 'clientName', 'clientId'),
        'subtitle': status == 'completed'
            ? 'Task completed'
            : 'New booking created',
        'timestamp': status == 'completed'
            ? (data['paidAt'] ?? data['updatedAt'] ?? data['createdAt'])
            : data['createdAt'],
      });
    }

    // Reports — admin feedback flow. Status === 'reviewed' means the admin sent
    // feedback to the complainant; surface that as an "upcoming feedback" item.
    for (final data in results[1]) {
      final status = (data['status'] ?? '').toString();
      activities.add({
        'type': 'report',
        'status': status,
        'name': resolveName(data, 'clientName', 'clientId'),
        'subtitle': status == 'reviewed'
            ? 'Admin feedback sent'
            : 'Complaint raised',
        'timestamp': status == 'reviewed'
            ? (data['feedbackAt'] ?? data['updatedAt'] ?? data['createdAt'])
            : data['createdAt'],
      });
    }

    // Users
    for (final data in results[2]) {
      if ((data['userType'] ?? '') == 'admin') continue;
      final isProvider = data['userType'] == 'provider';
      activities.add({
        'type': isProvider ? 'provider' : 'user',
        'name': (data['displayName'] ?? 'Unknown').toString(),
        'subtitle': isProvider ? 'Provider registered' : 'New user joined',
        'timestamp': data['createdAt'],
      });
    }

    // Reviews — clients giving feedback to providers.
    for (final data in results[3]) {
      final stored = (data['clientName'] ?? data['reviewerName'] ?? '').toString();
      final name = stored.isNotEmpty
          ? stored
          : (userNames[(data['clientId'] ?? '').toString()] ?? 'Unknown');
      activities.add({
        'type': 'review',
        'name': name,
        'subtitle': 'Review submitted',
        'timestamp': data['createdAt'],
      });
    }

    // Sort newest-first client-side
    activities.sort((a, b) {
      final ta = a['timestamp'];
      final tb = b['timestamp'];
      if (ta == null && tb == null) return 0;
      if (ta == null) return 1;
      if (tb == null) return -1;
      final msA = ta is Timestamp ? ta.millisecondsSinceEpoch : 0;
      final msB = tb is Timestamp ? tb.millisecondsSinceEpoch : 0;
      return msB.compareTo(msA);
    });

    return activities.take(limit).toList();
  }
}
