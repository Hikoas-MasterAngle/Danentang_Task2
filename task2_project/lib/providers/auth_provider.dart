import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:task2_project/constants/constants.dart';
import 'package:task2_project/models/models.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum Status {
  uninitialized,
  authenticated,
  authenticating,
  authenticateError,
  authenticateException,
  authenticateCanceled,
}

class AuthProvider extends ChangeNotifier {
  final GoogleSignIn googleSignIn;
  final FirebaseAuth firebaseAuth;
  final FirebaseFirestore firebaseFirestore;
  final SharedPreferences prefs;

  AuthProvider({
    required this.firebaseAuth,
    required this.googleSignIn,
    required this.prefs,
    required this.firebaseFirestore,
  });

  Status _status = Status.uninitialized;

  Status get status => _status;

  // ✅ FIX: lấy UID từ FirebaseAuth (quan trọng nhất)
  String? get userFirebaseId => firebaseAuth.currentUser?.uid;

  Future<bool> isLoggedIn() async {
    final user = firebaseAuth.currentUser;

    if (user != null) {
      await prefs.setString(FirestoreConstants.id, user.uid);
      return true;
    }

    return false;
  }

  Future<bool> handleSignIn() async {
    try {
      _status = Status.authenticating;
      notifyListeners();

      final googleUser = await googleSignIn.signIn();
      if (googleUser == null) {
        _status = Status.authenticateCanceled;
        notifyListeners();
        return false;
      }

      final googleAuth = await googleUser.authentication;

      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      // 🔥 Firebase login
      final firebaseUser =
          (await firebaseAuth.signInWithCredential(credential)).user;

      if (firebaseUser == null) {
        _status = Status.authenticateError;
        notifyListeners();
        return false;
      }

      final uid = firebaseUser.uid;

      // 🔥 check user exists
      final result = await firebaseFirestore
          .collection(FirestoreConstants.pathUserCollection)
          .where(FirestoreConstants.id, isEqualTo: uid)
          .get();

      if (result.docs.isEmpty) {
        // 🔥 create user
        await firebaseFirestore
            .collection(FirestoreConstants.pathUserCollection)
            .doc(uid)
            .set({
          FirestoreConstants.nickname: firebaseUser.displayName ?? "",
          FirestoreConstants.photoUrl: firebaseUser.photoURL ?? "",
          FirestoreConstants.id: uid,
          FirestoreConstants.createdAt:
              DateTime.now().millisecondsSinceEpoch.toString(),
          FirestoreConstants.chattingWith: null,
        });
      }

      // 🔥 sync local cache (IMPORTANT)
      await prefs.setString(FirestoreConstants.id, uid);
      await prefs.setString(
          FirestoreConstants.nickname, firebaseUser.displayName ?? "");
      await prefs.setString(
          FirestoreConstants.photoUrl, firebaseUser.photoURL ?? "");

      _status = Status.authenticated;
      notifyListeners();
      return true;
    } catch (e) {
      _status = Status.authenticateError;
      notifyListeners();
      return false;
    }
  }

  void handleException() {
    _status = Status.authenticateException;
    notifyListeners();
  }

  Future<void> handleSignOut() async {
    _status = Status.uninitialized;
    notifyListeners();

    await firebaseAuth.signOut();
    await googleSignIn.signOut();

    await prefs.clear();
  }
}