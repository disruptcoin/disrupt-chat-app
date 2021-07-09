import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:agora_rtc_engine/rtc_engine.dart';
import 'package:agora_rtc_engine/rtc_local_view.dart' as RtcLocalView;
import 'package:agora_rtc_engine/rtc_remote_view.dart' as RtcRemoteView;
import 'package:flutter_firebase_chat/src/themes/colors.dart';
import 'package:flutter_firebase_chat/src/widgets/raw_icon_button.dart';
import 'package:flutter_firebase_chat/src/utils/settings.dart';
import 'package:flutter_firebase_chat/src/pages/video_call/video_call_bloc.dart';

class VideoCallPage extends StatefulWidget {
  @override
  VideoCallPageState createState() => VideoCallPageState();
}

class VideoCallPageState extends State<VideoCallPage> {
  VideoCallBloc _videoCallBloc;

  void _onToggleMute() {
    _videoCallBloc.add(VideoCallMuteAudioEvent());
  }

  void _onSwitchCamera() {
    _videoCallBloc.add(VideoCallSwitchCameraEvent());
  }

  void _initRtcEngine() async {
    _videoCallBloc.add(VideoCallInitEvent(
      rtcEngine: await RtcEngine.create(AGORA_APP_ID))
    );
  }

  @override
  void initState() {
    super.initState();
    _videoCallBloc = BlocProvider.of<VideoCallBloc>(context);
    _initRtcEngine();
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () => Future.value(true),
      child: Scaffold(
        backgroundColor: blackColor,
        body: BlocBuilder<VideoCallBloc, VideoCallState>(
          builder: (_, state) => Stack(
            children: [
              _buildUserRenderWidget(state.userId),
              _buildToolbar(state.muted)
            ]
          )
        )
      )
    );
  }

  Widget _buildUserRenderWidget(int userId) {
    if (userId != null)
      return RtcRemoteView.SurfaceView(uid: userId);
    else return Container();
  }

  Widget _buildToolbar(bool muted) {
    return Positioned(
      bottom: 20,
      left: 20,
      right: 20,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Container(
              width: MediaQuery.of(context).size.width / 4,
              height: MediaQuery.of(context).size.height / 4,
              margin: EdgeInsets.only(bottom: 20),
              child: RtcLocalView.SurfaceView()
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                RawIconButton(
                  padding: EdgeInsets.all(12),
                  icon: Icon(
                    muted ? Icons.mic_off : Icons.mic,
                    color: blackColor,
                    size: 20
                  ),
                  shape: CircleBorder(),
                  fillColor: Colors.white,
                  onPressed: _onToggleMute
                ),
                RawIconButton(
                  padding: EdgeInsets.all(15),
                  icon: Icon(
                    Icons.call_end,
                    color: whiteColor,
                    size: 35
                  ),
                  shape: CircleBorder(),
                  fillColor: Colors.red,
                  onPressed: () => Navigator.pop(context)
                ),
                RawIconButton(
                  padding: EdgeInsets.all(12),
                  icon: Icon(
                    Icons.switch_camera,
                    color: blackColor,
                    size: 20
                  ),
                  shape: CircleBorder(),
                  fillColor: Colors.white,
                  onPressed: _onSwitchCamera
                )
              ]
            )
          ]
        )
      )
    );
  }
}