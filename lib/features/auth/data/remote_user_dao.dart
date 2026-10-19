import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/constants/firebase_collections.dart';
import '../domain/user_model.dart';
import 'user_dto.dart';

/// Data Access Object (DAO) for User Firestore database operations.
///
/// Encapsulates all Firestore queries, reads, writes, and real-time streams
/// for user documents (`users/{uid}`).
abstract class RemoteUserDao {
  /// Fetches the raw Firestore document snapshot for a user.
  Future<DocumentSnapshot<Map<String, dynamic>>> getUserDoc(String uid);

  /// Retrieves and parses a [UserModel] from Firestore.
  /// Returns null if the document does not exist.
  Future<UserModel?> getUser(String uid);

  /// Creates a new user document in Firestore using [UserDto.toNewUserMap].
  Future<void> createUser(UserModel user);

  /// Updates a single field in the user document and sets `lastUpdatedAt`.
  Future<void> updateUserField(String uid, String field, dynamic value);

  /// Updates `lastLoginAt` and sets `isNewUser = false`.
  Future<void> updateLastLogin(String uid);

  /// Updates profile fields using pre-built update map.
  Future<void> updateProfile(String uid, Map<String, dynamic> updateMap);

  /// Deletes the user document from Firestore.
  Future<void> deleteUserDoc(String uid);

  /// Real-time stream emitting true if the user document exists, false if deleted.
  Stream<bool> watchUserExists(String uid);
}

/// Concrete implementation of [RemoteUserDao].
class RemoteUserDaoImpl implements RemoteUserDao {
  final FirebaseFirestore _firestore;

  RemoteUserDaoImpl({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseCollections.firestore;

  DocumentReference<Map<String, dynamic>> _userRef(String uid) =>
      _firestore.doc(FirebaseCollections.userDoc(uid));

  @override
  Future<DocumentSnapshot<Map<String, dynamic>>> getUserDoc(String uid) {
    return _userRef(uid).get();
  }

  @override
  Future<UserModel?> getUser(String uid) async {
    final doc = await getUserDoc(uid);
    if (!doc.exists || doc.data() == null) return null;
    return UserDto.fromFirestore(doc.data()!);
  }

  @override
  Future<void> createUser(UserModel user) async {
    await _userRef(user.uid).set(UserDto.toNewUserMap(user));
  }

  @override
  Future<void> updateUserField(String uid, String field, dynamic value) async {
    await _userRef(uid).update({
      FirebaseCollections.fieldLastUpdatedAt: FieldValue.serverTimestamp(),
      field: value,
    });
  }

  @override
  Future<void> updateLastLogin(String uid) async {
    await _userRef(uid).update({
      FirebaseCollections.fieldLastLoginAt: FieldValue.serverTimestamp(),
      FirebaseCollections.fieldNewUser: false,
    });
  }

  @override
  Future<void> updateProfile(String uid, Map<String, dynamic> updateMap) async {
    await _userRef(uid).update(updateMap);
  }

  @override
  Future<void> deleteUserDoc(String uid) async {
    await _userRef(uid).delete();
  }

  @override
  Stream<bool> watchUserExists(String uid) {
    return _userRef(uid).snapshots().map((doc) => doc.exists);
  }
}
