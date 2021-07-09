import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:platform_action_sheet/platform_action_sheet.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_firebase_chat/src/themes/colors.dart';
import 'package:flutter_firebase_chat/src/utils/loading.dart';
import 'package:flutter_firebase_chat/src/widgets/raw_icon_button.dart';
import 'package:flutter_firebase_chat/src/pages/chat/chat_bloc.dart';
import 'package:flutter_firebase_chat/src/pages/chat/widgets/message_bubble.dart';
import 'package:flutter_firebase_chat/src/pages/add_user/add_user.dart';
import 'package:flutter_firebase_chat/src/pages/video_call/video_call.dart';

class ChatPage extends StatefulWidget {
  @override
  ChatPageState createState() => ChatPageState();
}

class ChatPageState extends State<ChatPage> {
  ScrollController _chatScrollController = ScrollController();
  TextEditingController _messageController = TextEditingController();
  FocusNode _messageFocusNode = FocusNode();
  Loading _loading;
  ChatBloc _chatBloc;  

  Future<void> _refreshMessages() {
    _chatBloc.add(
      ChatRefreshMessagesEvent()
    );
    return Future.value();
  }

  void _onTextFieldChanged() {
    _chatBloc.add(
      ChatTextFieldChangedEvent(
        message: _messageController.text
      )
    );
  }

  void _sendTextPressed() {
    _chatBloc.add(
      ChatSendTextEvent()
    );
    _messageController.text = '';
  }

  void _sendImagePressed() {
    PlatformActionSheet().displaySheet(
      context: context,
      actions: [
        ActionSheetAction(
          text: 'Take Photo',
          onPressed: () {
            Navigator.pop(context);
            _chatBloc.add(
              ChatSendImageFromCameraEvent()
            );
          }
        ),
        ActionSheetAction(
          text: 'Photo from Library',
          onPressed: () {
            Navigator.pop(context);
            _chatBloc.add(
              ChatSendImageFromLibraryEvent()
            );
          }
        ),
        ActionSheetAction(
          text: "Cancel",
          onPressed: () => Navigator.pop(context),
          isCancel: true,
          defaultAction: true
        )
      ]
    );
  }

  void _onMessageFocusNodeChange() {
    _chatBloc.add(
      ChatScrollToBottomEvent(isScrollToBottom: true)
    );
  }

  void _addUserPressed() {
    Navigator.push(context,
      MaterialPageRoute(builder: (_) =>
        BlocProvider<AddUserBloc>(
          create: (_) => AddUserBloc(
            chatId: _chatBloc.chatId,
            members: _chatBloc.members
          ),
          child: AddUserPage()
        )
      )
    );
  }

  void _videoCallPressed() async {
    await PermissionHandler().requestPermissions([
      PermissionGroup.camera,
      PermissionGroup.microphone
    ]);
    await Navigator.push(context,
      MaterialPageRoute(builder: (_) =>
        BlocProvider<VideoCallBloc>(
          create: (_) => VideoCallBloc(
            chatId: _chatBloc.chatId
          ),
          child: VideoCallPage()
        )
      )
    );
  }

  void _blocListener(_, state) async {
    if (state.isLoading)
      _loading = Loading(context);
    else if (!state.isLoading && _loading != null) {
      _loading.close();
      _loading = null;
    }
    else if (state.isScrollToBottom) {
      await Future.delayed(Duration(milliseconds: 300));
      if (_chatScrollController.hasClients)
        _chatScrollController.jumpTo(_chatScrollController.position.maxScrollExtent);
    }
  }

  @override
  void initState() {
    super.initState();
    _messageFocusNode.addListener(_onMessageFocusNodeChange);
    _chatBloc = BlocProvider.of<ChatBloc>(context);
    _chatBloc.add(ChatInitialFetchEvent());
  }

  @override
  void dispose() {
    _chatScrollController.dispose();
    _messageController.dispose();
    _messageFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () => Future.value(true),
      child: BlocListener<ChatBloc, ChatState>(
        listener: _blocListener,
        child: BlocBuilder<ChatBloc, ChatState>(
          builder: (_, state) {
            List<MessageModel> messages = state.messages;
            return Scaffold(
              appBar: _buildChatAppBar(
                messages,
                state.members,
                state.chatName
              ),
              body: Column(
                children: [
                  _buildChatContent(
                    messages, state.members
                  ),
                  _buildChatBottomBar(state.isMessageValid)
                ]
              )
            );
          }
        )
      )
    );
  }

  Widget _buildChatAppBar(
    List<MessageModel> messages,
    Map members,
    String chatName
  ) {
    return PreferredSize(
      preferredSize: Size.fromHeight(50),
      child: AppBar(
        elevation: 0,
        titleSpacing: 0,
        automaticallyImplyLeading: false,
        backgroundColor: whiteColor,
        brightness: Brightness.light,
        title: Container(
          margin: EdgeInsets.only(right: 22.5),
          child: Row(
            children: [
              RawIconButton(
                height: AppBar().preferredSize.height,
                padding: EdgeInsets.symmetric(horizontal: 30),
                icon: Icon(
                  Icons.arrow_back,
                  color: blackColor,
                  size: 25
                ),
                onPressed: () => Navigator.pop(context)
              ),
              Expanded(
                child: Container(
                  padding: EdgeInsets.only(right: 22.5),
                  child: Text(
                    chatName,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: blackColor
                    )
                  )
                )
              ),
              ((messages.length > 0) &&
                (members.length <= 5)) ?
              RawIconButton(
                height: AppBar().preferredSize.height,
                padding: EdgeInsets.symmetric(horizontal: 7.5),
                icon: Icon(
                  Icons.person_add,
                  color: blackColor,
                  size: 25
                ),
                onPressed: _addUserPressed
              ) : Container(),
              (members.length == 2) ? RawIconButton(
                height: AppBar().preferredSize.height,
                padding: EdgeInsets.symmetric(horizontal: 7.5),
                icon: Icon(
                  Icons.video_call,
                  color: blackColor,
                  size: 33
                ),
                onPressed: _videoCallPressed
              ) : Container()
            ]
          )
        ),
        bottom: PreferredSize(
          child: Container(
            color: lightGreyColor,
            height: 0.5
          ),
          preferredSize: Size.fromHeight(0.5)
        )
      )
    );
  }

  Widget _buildChatContent(
    List<MessageModel> messages,
    Map members
  ) {
    return Expanded(
      child: Container(
        margin: EdgeInsets.symmetric(horizontal: 30),
        alignment: Alignment.bottomCenter,
        child: RefreshIndicator(
          child: ListView.builder(
            padding: EdgeInsets.only(bottom: 20),
            shrinkWrap: true,
            controller: _chatScrollController,
            itemCount: messages.length,
            itemBuilder: (_, index) {
              bool showTopMessagePart = (index == 0) || ((index > 0) &&
                (messages[index - 1].userId != messages[index].userId));
              bool showUserNameAndImageUrl = (members.length > 2 &&
                messages[index].userId != null);
              return MessageBubble(
                content: messages[index].content,
                contentType: messages[index].contentType,
                date: showTopMessagePart ? messages[index].date : null,
                userId: messages[index].userId,
                userName: (showTopMessagePart && showUserNameAndImageUrl) ?
                  members[messages[index].userId]['username'] : null,
                userImageUrl: (showTopMessagePart && showUserNameAndImageUrl) ?
                  members[messages[index].userId]['imageUrl'] : null,
                withoutTopBorders: (index > 0) &&
                  (messages[index].userId == messages[index - 1].userId),
                withoutBottomBorders: (index < (messages.length - 1)) &&
                  (messages[index].userId == messages[index + 1].userId),
                withLeftOffset: showUserNameAndImageUrl
              );
            }
          ),
          onRefresh: _refreshMessages
        )
      )
    );
  }

  Widget _buildChatBottomBar(bool isMessageValid) {
    return SafeArea(
      child: Container(
        margin: EdgeInsets.fromLTRB(15, 0, 30, 5),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            RawIconButton(
              padding: EdgeInsets.symmetric(
                horizontal: 15,
                vertical: 5
              ),
              icon: Icon(
                Icons.add_a_photo,
                color: blackColor,
                size: 25
              ),
              onPressed: _sendImagePressed
            ),
            Expanded(
              child: Container(
                padding: EdgeInsets.only(
                  left: 15,
                  right: 5
                ),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(15),
                  border: Border.all(color: lightGreyColor)
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: TextField(
                        style: TextStyle(
                          fontSize: 16,
                          color: blackColor
                        ),
                        decoration: InputDecoration(
                          hintText: 'Enter message...',
                          border: InputBorder.none,
                          isDense: true,
                          contentPadding: EdgeInsets.symmetric(vertical: 8)
                        ),
                        maxLines: null,
                        controller: _messageController,
                        onChanged: (_) =>_onTextFieldChanged(),
                        focusNode: _messageFocusNode
                      )
                    ),
                    Container(
                      margin: EdgeInsets.only(top: 5),
                      child: RawIconButton(
                        height: 25,
                        width: 25,
                        fillColor: isMessageValid ? blueColor : lightGreyColor,
                        shape: CircleBorder(),
                        icon: Icon(
                          Icons.arrow_upward,
                          size: 18,
                          color: whiteColor
                        ),
                        onPressed: isMessageValid ? _sendTextPressed : null
                      )
                    )
                  ]
                )
              )
            )
          ]
        )
      )
    );
  }
}