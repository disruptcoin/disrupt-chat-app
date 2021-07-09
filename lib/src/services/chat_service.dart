import 'dart:async';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:flutter_firebase_chat/src/services/auth_service.dart';
import 'package:flutter_firebase_chat/src/pages/chats/chats.dart';
import 'package:flutter_firebase_chat/src/pages/chat/chat.dart';

class ChatService {
  Firestore _firestore = Firestore.instance;
  FirebaseStorage _firebaseStorage = FirebaseStorage.instance;
  AuthService _authService = AuthService();

  Stream<List<ChatModel>> watchChats() async* {
    Query chatsQuery = _firestore
      .collection('chats')
      .where('userIds', arrayContains: await _authService.getCurrentUserId());
    yield* chatsQuery.snapshots().transform(
      StreamTransformer<QuerySnapshot, List<ChatModel>>
        .fromHandlers(handleData: (chatsSnapshot, sink) async {
          sink.add(await _getChatsByDocs(chatsSnapshot.documents));
        })
    );
  }

  Future<List<ChatModel>> getChats() async {
    QuerySnapshot chatsSnapshot = await _firestore
      .collection('chats')
      .where('userIds', arrayContains: await _authService.getCurrentUserId())
      .getDocuments();
    return _getChatsByDocs(chatsSnapshot.documents);
  }

  Future<ChatsUsersModel> getChatsAndUsersByQuery(String query) async {
    List<UserModel> users = await _getUsersByQuery(query);
    List<ChatModel> chats = await _getChatsByUserIds(
      users.map((user) => user.id).toList()
    );
    users = users.where((user) =>
      chats.indexWhere((chat) =>
        (chat.members.length == 2) && chat.members.containsKey(user.id)
      ) == -1
    ).toList();
    return ChatsUsersModel(
      chats: chats,
      users: users
    );
  }

  Future<List<UserModel>> getUsersByQueryExceptMembers(
    String query,
    Map members
  ) async {
    List<UserModel> users = await _getUsersByQuery(query);
    return users.where((user) =>
      !members.containsKey(user.id)
    ).toList();
  }

  Future<Map> createChat(List<String> userIds) async {
    userIds.add(await _authService.getCurrentUserId());
    List<Map> membersList = await Future.wait(userIds.map((userId) =>
      _getChatMembers(userId, {})
    ));
    Map members = {};
    membersList.forEach((memberMap) =>
      members.addAll(memberMap)
    );
    String newChatId = (await _firestore.collection('chats').add({
      'members': members,
      'userIds': userIds
    })).documentID;
    return {
      'chatId': newChatId,
      'members': members
    };
  }

  Future removeChat(String chatId) async {
    DocumentReference chatDocRef = _firestore
      .collection('chats')
      .document(chatId);
    QuerySnapshot chatsSnapshot = await chatDocRef
      .collection('messages')
      .getDocuments();
    await Future.wait(chatsSnapshot.documents.map((chatDoc) =>
      chatDoc.reference.delete()
    ));
    return chatDocRef.delete();
  }

  Future<void> addChatMember(
    String chatId,
    String userId,
    Map members
  ) async {
    members = await _getChatMembers(
      userId, members
    );
    return _updateChatMembers(chatId, members);
  }

  Future<Map> updateLastVisitTimestamp(
    String chatId,
    Map members
  ) async {
    String currentUserId = await _authService.getCurrentUserId();
    members[currentUserId]['lastVisitTimestamp'] = DateTime.now();
    await _updateChatMembers(chatId, members);
    return members;
  }

  Stream<Map> getChatMembersInfo(String chatId) {
    Stream chatStream = _firestore
      .collection('chats')
      .document(chatId)
      .snapshots();
    return chatStream.transform(
      StreamTransformer<DocumentSnapshot, Map>
        .fromHandlers(handleData: (chatSnapshot, sink) async {
          String currentUserId = await _authService.getCurrentUserId();
          Map members = chatSnapshot.data['members'];
          sink.add({
            'members': members,
            'chatName': _getChatNameByMembers(currentUserId, members)
          });
      })
    );
  }

  Stream<List> getMessages(
    String chatId,
    [DocumentSnapshot docSnapshot]
  ) {
    Query messagesQuery = _firestore
      .collection('chats')
      .document(chatId)
      .collection('messages')
      .orderBy('date', descending: true)
      .limit(10);
    if (docSnapshot != null)
      messagesQuery = messagesQuery.startAfterDocument(docSnapshot);
    return messagesQuery.snapshots().transform(
      StreamTransformer<QuerySnapshot, List>
        .fromHandlers(handleData: (messagesSnapshot, sink) async {
          String currentUserId = await _authService.getCurrentUserId();
          List<MessageModel> messages = messagesSnapshot.documents.map((messageDoc) =>
            MessageModel(
              content: messageDoc.data['content'],
              contentType: messageDoc.data['contentType'],
              date: timeago.format(messageDoc.data['date'].toDate()),
              userId: (currentUserId != messageDoc.data['userId']) ? messageDoc.data['userId'] : null,
              docSnapshot: messageDoc
            )
          ).toList().reversed.toList();
          sink.add(messages);
        })
    );
  }

  Future<DocumentReference> sendTextMessage(
    String chatId,
    String message
  ) async {
    return _firestore
      .collection('chats')
      .document(chatId)
      .collection('messages')
      .add({
        'content': message,
        'contentType': 'text',
        'date': DateTime.now(),
        'userId': await _authService.getCurrentUserId()
      });
  }

  Future<DocumentReference> sendImageMessage(
    String chatId,
    File message
  ) async {
    StorageReference firebaseStorageRef = _firebaseStorage.ref().child(
      'messages/image/' +
      chatId +
      DateTime.now().millisecondsSinceEpoch.toString() +
      '.jpg'
    );
    StorageUploadTask uploadTask = firebaseStorageRef.putFile(message);
    String imageUrl = await (await uploadTask.onComplete).ref.getDownloadURL();
    return _firestore
      .collection('chats')
      .document(chatId)
      .collection('messages')
      .add({
        'content': imageUrl,
        'contentType': 'image',
        'date': DateTime.now(),
        'userId': await _authService.getCurrentUserId()
      });
  }

  Future<List<ChatModel>> _getChatsByUserIds(List<String> userIds) async {
    List<List<ChatModel>> chats = await Future.wait(userIds.map((userId) async {
      QuerySnapshot chatsSnapshot = await _firestore
        .collection('chats')
        .where('userIds', arrayContains: userId)
        .getDocuments();
      return _getChatsByDocs(chatsSnapshot.documents);
    }));
    return chats.fold<List<ChatModel>>([], (prevChats, currentChats) {
      currentChats.forEach((currentChat) {
        int prevIndex = prevChats.indexWhere((prevChat) => prevChat.id == currentChat.id);
        if (prevIndex == -1)
          prevChats.add(currentChat);
      });
      return prevChats;
    });
  }

  Future<List<ChatModel>> _getChatsByDocs(
    List<DocumentSnapshot> chatDocs
  ) async {
    if (chatDocs.length == 0)
      return [];

    String currentUserId = await _authService.getCurrentUserId();
    return Future.wait(chatDocs.map((chatDoc) async {
      QuerySnapshot messagesSnapshot = await _firestore
        .collection('chats')
        .document(chatDoc.documentID)
        .collection('messages')
        .orderBy('date', descending: true)
        .limit(1).getDocuments();
      List<DocumentSnapshot> messageDocs = messagesSnapshot.documents;

      Map members = chatDoc.data['members'];
      List<String> imageUrls = [];
      if (members != null)
        members.forEach((key, value) {
          if (key != currentUserId)
            imageUrls.add(value['imageUrl']);
        });
      else imageUrls.add('');

      bool hasUnreadMessages;
      if (messageDocs.length > 0 && members != null) {
        String latestMessageUserId = messageDocs[0].data['userId'];
        DateTime latestMessageDate = messageDocs[0].data['date'].toDate();
        hasUnreadMessages = (members[currentUserId] != null) &&
          (!members[currentUserId].containsKey('lastVisitTimestamp') ||
          (members[currentUserId].containsKey('lastVisitTimestamp') &&
          (latestMessageUserId != currentUserId) &&
          (latestMessageDate.isAfter(members[currentUserId]['lastVisitTimestamp'].toDate()))));
      }
      else hasUnreadMessages = true;

      return ChatModel(
        id: chatDoc.documentID,
        imageUrls: imageUrls,
        name: (members != null) ?
          _getChatNameByMembers(currentUserId, members) :
          '',
        text: (messageDocs.length > 0) ?
          (messageDocs[0].data['contentType'] == 'text') ?
            messageDocs[0].data['content'] :
            messageDocs[0].data['contentType'] :
          '',
        date: timeago.format(
          (messageDocs.length > 0) ?
            messageDocs[0].data['date'].toDate() :
            DateTime.now()
        ),
        hasUnreadMessages: hasUnreadMessages,
        members: members
      );
    }));
  }

  Future<List<UserModel>> _getUsersByQuery(String query) async {
    Query usersQuery = _firestore.collection('users');
    if (query.isNotEmpty) {
      query = query.toLowerCase();
      usersQuery = usersQuery.where('searchTerms', arrayContains: query);
    }
    List<DocumentSnapshot> userDocs = (await usersQuery.getDocuments()).documents;
    String currentUserId = await _authService.getCurrentUserId();
    return userDocs.map((userDoc) =>
      UserModel(
        id: userDoc.documentID,
        imageUrl: userDoc.data['imageUrl'],
        name: userDoc.data['username']
      )
    ).toList().where((user) =>
      user.id != currentUserId
    ).toList();
  }

  Future<Map> _getChatMembers(
    String userId,
    Map members
  ) async {
    DocumentReference userDocRef = _firestore
      .collection('users')
      .document(userId);
    DocumentSnapshot userSnapshot = await userDocRef.get();
    members[userId] = {
      'username': userSnapshot.data['username'],
      'imageUrl': userSnapshot.data['imageUrl']
    };
    return members;
  }

  String _getChatNameByMembers(
    String currentUserId,
    Map members
  ) {
    List<String> membersNames = [];
    String chatName = '';
    members.forEach((key, value) {
      if (key != currentUserId)
        membersNames.add(value['username']);
    });
    if (membersNames.length > 1)
      chatName = membersNames.sublist(0, 2).join(', ');
    else chatName = membersNames.join(', ');
    if (membersNames.length > 2)
      chatName += ' and ${membersNames.length - 2} other(s)';
    return chatName;
  }

  Future<void> _updateChatMembers(
    String chatId,
    Map members
  ) {
    return _firestore
      .collection('chats')
      .document(chatId)
      .updateData({
        'members': members,
        'userIds': members.keys.toList()
      });
  }
}