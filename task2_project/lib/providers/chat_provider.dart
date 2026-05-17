import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';

class ChatProvider {
  final FirebaseFirestore firebaseFirestore;
  final FirebaseStorage firebaseStorage;

  ChatProvider({
    required this.firebaseFirestore,
    required this.firebaseStorage,
  });

  // upload image
  UploadTask uploadFile(File image, String fileName) {
    final ref = firebaseStorage.ref().child('chat_images/$fileName');
    return ref.putFile(image);
  }

  // update user status
  Future<void> updateDataFirestore(
      String collectionPath,
      String docPath,
      Map<String, dynamic> data) {
    return firebaseFirestore.collection(collectionPath).doc(docPath).update(data);
  }

  // 🔥 FIX STREAM CHAT
  Stream<QuerySnapshot> getChatStream(String groupChatId, int limit) {
    return firebaseFirestore
        .collection('chat')
        .doc(groupChatId)
        .collection('messages')
        .orderBy('timestamp', descending: true)
        .limit(limit)
        .snapshots();
  }

  // 🔥 FIX SEND MESSAGE
  Future<void> sendMessage(
    String content,
    int type,
    String groupChatId,
    String currentUserId,
    String peerId,
  ) async {
    final docRef = firebaseFirestore
        .collection('chat')
        .doc(groupChatId)
        .collection('messages')
        .doc();

    final message = {
      'idFrom': currentUserId,
      'idTo': peerId,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
      'content': content,
      'type': type,
    };

    await docRef.set(message);
  }
}