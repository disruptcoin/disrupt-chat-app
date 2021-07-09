import 'dart:async';
import 'package:agora_rtc_engine/rtc_engine.dart';
export 'package:agora_rtc_engine/rtc_engine.dart';
import 'package:flutter_firebase_chat/src/services/auth_service.dart';

class VideoCallService {
  final RtcEngine rtcEngine;
  final String chatId;

  StreamController<int> _onUserJoinedController = new StreamController();
  StreamController<int> _onUserOfflineController = StreamController();

  Stream get onUserJoined => _onUserJoinedController.stream;
  Stream get onUserOffline => _onUserOfflineController.stream;

  VideoCallService(
    this.rtcEngine,
    this.chatId
  );

  Future<void> init() async {
    rtcEngine.setEventHandler(RtcEngineEventHandler(
      userJoined: (uid, _) =>
        _onUserJoinedController.add(uid),
      userOffline: (uid, _) =>
        _onUserOfflineController.add(uid),
      error: (error) =>
        print('AgoraRtcEngine Error: $error')
    ));
    await rtcEngine.enableVideo();
    await rtcEngine.setChannelProfile(ChannelProfile.LiveBroadcasting);
    await rtcEngine.setClientRole(ClientRole.Broadcaster);
    return rtcEngine.joinChannelWithUserAccount(
      null,
      chatId,
      await AuthService().getCurrentUserId()
    );
  }

  Future<void> muteAudio(bool muted) async {
    return rtcEngine.muteLocalAudioStream(muted);
  }

  Future<void> switchCamera() {
    return rtcEngine.switchCamera();
  }

  Future<void> dispose() async {
    await _onUserJoinedController.close();
    await _onUserOfflineController.close();
    await rtcEngine?.leaveChannel();
    return rtcEngine?.destroy();
  }
}