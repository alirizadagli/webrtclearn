import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:sdp_transform/sdp_transform.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter WebRTC Demo',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const MyHomePage(),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({Key? key}) : super(key: key);

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  bool _offer = false;
  late RTCPeerConnection _peerConnection;
  late MediaStream _localStream;
  final _localRenderer = RTCVideoRenderer();
  final _remoteRenderer = RTCVideoRenderer();

  final sdpController = TextEditingController();

  void initRenderers() async {
    await _localRenderer.initialize();
    await _remoteRenderer.initialize();
  }

  Future<MediaStream> _getUserMedia() async {
    final Map<String, dynamic> mediaConstraints = {
      'audio': true,
      'video': {
        'facingMode': 'user',
      },
    };

    MediaStream stream = await navigator.mediaDevices.getUserMedia(
      mediaConstraints,
    );
    _localRenderer.srcObject = stream;
    return stream;
  }

  void _createOffer() async {
    RTCSessionDescription description = await _peerConnection.createOffer(
      {
        'offerToReceiveVideo': 1,
      },
    );

    var session = description.sdp != null ? parse(description.sdp!) : null;
    print(json.encode(session));
    _offer = true;

    _peerConnection.setLocalDescription(description);
  }

  void _createAnswer() async {
    RTCSessionDescription description = await _peerConnection.createAnswer(
      {
        'offerToReceiveVideo': 1,
      },
    );

    var session = description.sdp != null ? parse(description.sdp!) : null;
    print(json.encode(session));
    _offer = true;

    _peerConnection.setLocalDescription(description);
  }

  void _setRemoteDescription() async {
    String jsonString = sdpController.text;
    dynamic session = await jsonDecode(jsonString);
    String sdp = write(session, null);
    RTCSessionDescription description = RTCSessionDescription(
      sdp,
      _offer ? 'answer' : 'offer',
    );
    print(description.toMap());
    await _peerConnection.setRemoteDescription(description);
  }

  void _setCandidate() async {
    String jsonString = sdpController.text;
    dynamic session = await jsonDecode(jsonString);
    print(session['candidate']);
    dynamic candidate = RTCIceCandidate(
      session['candidate'],
      session['sdpMid'],
      session['sdpMLineIndex'],
    );

    await _peerConnection.addCandidate(candidate);
  }

  Future<RTCPeerConnection> _createPeerConnection() async {
    Map<String, dynamic> configuration = {
      'iceServers': [
        {'url': 'stun:stun.l.google.com:19302'},
      ],
    };

    final Map<String, dynamic> offerSdpConstraints = {
      'mandatory': {
        'OfferToReceiveAudio': true,
        'OfferToReceiveVideo': true,
      },
      'optional': [],
    };

    _localStream = await _getUserMedia();

    RTCPeerConnection pc = await createPeerConnection(
      configuration,
      offerSdpConstraints,
    );

    pc.addStream(_localStream);
    pc.onIceCandidate = (e) {
      if (e.candidate != null) {
        print(
          json.encode(
            {
              'candidate': e.candidate.toString(),
              'sdpMid': e.sdpMid.toString(),
              'sdpMlineIndex': e.sdpMLineIndex,
            },
          ),
        );
      }
    };

    pc.onIceConnectionState = (e) {
      print(e);
    };

    pc.onAddStream = (stream) {
      print('addStream: ${stream.id}');
      _remoteRenderer.srcObject = stream;
    };

    return pc;
  }

  @override
  void initState() {
    initRenderers();
    _createPeerConnection().then((pc) {
      _peerConnection = pc;
    });
    super.initState();
  }

  @override
  void dispose() {
    _localRenderer.dispose();
    _remoteRenderer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Basic WebRTC'),
      ),
      body: Column(
        children: [
          videoRenderers,
          offerAndAnswerButtons,
          sdpCandidateTF,
          sdpCandidateButtons,
        ],
      ),
    );
  }

  SizedBox get videoRenderers {
    return SizedBox(
      height: 210,
      child: Row(
        children: [
          Flexible(
            child: Container(
              key: const Key('local'),
              margin: const EdgeInsets.fromLTRB(5, 5, 5, 5),
              decoration: const BoxDecoration(
                color: Colors.black,
              ),
              child: RTCVideoView(
                _localRenderer,
                mirror: true,
              ),
            ),
          ),
          Flexible(
            child: Container(
              key: const Key('remote'),
              margin: const EdgeInsets.fromLTRB(5, 5, 5, 5),
              decoration: const BoxDecoration(
                color: Colors.black,
              ),
              child: RTCVideoView(_remoteRenderer),
            ),
          ),
        ],
      ),
    );
  }

  Row get offerAndAnswerButtons {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        ElevatedButton(
          onPressed: _createOffer,
          child: const Text('Offer'),
        ),
        ElevatedButton(
          onPressed: _createAnswer,
          child: const Text('Answer'),
        ),
      ],
    );
  }

  Padding get sdpCandidateTF {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: TextField(
        controller: sdpController,
        keyboardType: TextInputType.multiline,
        maxLines: 4,
        maxLength: TextField.noMaxLength,
      ),
    );
  }

  Row get sdpCandidateButtons {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        ElevatedButton(
          onPressed: _setRemoteDescription,
          child: const Text('Set Remote Desc.'),
        ),
        ElevatedButton(
          onPressed: _setCandidate,
          child: const Text('Set Candidate'),
        ),
      ],
    );
  }
}
