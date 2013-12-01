socket = io.connect('http://10.0.1.111:3000')
localStream = null
activedStream = null
rs = (length)->
  result = ''
  chars = '0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ'
  result += chars[Math.round(Math.random() * (chars.length - 1))] for i in [0...length]
  return result;

# WebRTC
peers = []
viewers = []
dataChannel = null
sourceStreams = {}
iceServers =
  iceServers: [{
    url: 'stun:stun.l.google.com:19302'
  }]
mediaConstraints =
  optional: []
  mandatory:
    OfferToReceiveAudio: true
    OfferToReceiveVideo: true
optionalRtpDataChannels =
  optional: [{
    RtpDataChannels: true
  }]
if mozRTCPeerConnection?
  RTCPeerConnection = mozRTCPeerConnection
  getUserMedia = navigator.mozGetUserMedia
if webkitRTCPeerConnection?
  RTCPeerConnection = webkitRTCPeerConnection
  getUserMedia = navigator.webkitGetUserMedia

# Default Channel Events
setChannelEvents = (channel, channelNameForConsoleOutput)->

  channel.onmessage = (event)->
    console.debug channelNameForConsoleOutput, 'receive a message', event.data

  channel.onopen = ->
    console.debug "channel [ #{channelNameForConsoleOutput} ] open"
    # channel.send 'first text message over RTP data ports'

  channel.onclose = (e)->
    console.error e

  channel.onerror = (e)->
    console.error e

# Page Control
director = angular.module 'director', ['ngRoute'], ($locationProvider, $routeProvider)->
  $locationProvider.html5Mode(true)

  $routeProvider.when '/s/:desktopId',
    controller: 'source'
    templateUrl: '/tmpl/source'
  $routeProvider.when '/d/:desktopId',
    controller: 'desktop'
    templateUrl: '/tmpl/desktop'
  $routeProvider.when '/v/:desktopId',
    controller: 'viewer'
    templateUrl: '/tmpl/viewer'
  $routeProvider.otherwise 
    controller: 'lobby'
    templateUrl: '/tmpl/lobby'

# 觀看器
director.controller 'viewer', ['$scope', '$routeParams', '$location', ($scope, $routeParams, $location)->
  # 加入觀看者
  socket.emit 'joinViewer', 
    desktopId: $routeParams.desktopId

  # Initial
  $scope.desktopId = $routeParams.desktopId

  # 加入觀看
  socket.on 'joinViewerFail', (data)->
    $scope.$apply ->
      $location.path("")

  # 初始化
  socket.on 'joinedViewer', (data)->
    $scope.$apply ->
      $scope.viewerId = data.viewerId

  socket.on 'changeSource', ->
    if peerViewer? and activedStream?
      activedStream.stop()
      peerViewer.removeStream activedStream
      peerViewer = null
    setTimeout ->
      createViewerOffer $scope.desktopId, $scope
    , 300

  # 接收 Viewer Answer
  socket.on 'viewerAnswer', (data)->
    answerSDP = new RTCSessionDescription
      sdp: data.sdp
      type: 'answer'
    peerViewer.setRemoteDescription answerSDP

  # 接收 Viewer Candidate
  socket.on 'candidateViewer', (data)->
    peerViewer.addIceCandidate new RTCIceCandidate
      sdpMLineIndex: data.candidate.sdpMLineIndex
      candidate: data.candidate.candidate
]

# 導播台
director.controller 'desktop', ['$scope', '$routeParams', '$location', ($scope, $routeParams, $location)->
  # 加入導播
  socket.emit 'joinDesktop', 
    desktopId: $routeParams.desktopId

  # Initial
  $scope.desktopId = $routeParams.desktopId
  $scope.videos = []

  # 加入導播失敗
  socket.on 'joinDesktopFail', (data)->
    $scope.$apply ->
      $location.path("")

  # 選擇來源
  $scope.activeVideo = (video, e)->
    for vi in $scope.videos
      vi.active = false
    video.active = true
    document.getElementById('main').src = e.srcElement.src

    activedStream = sourceStreams[video.sourceId]
    viewers = []

    socket.emit 'changeSource',
      desktopId: $scope.desktopId

  # 接收來源
  socket.on 'sourceOffer', (data)->
    return false if data.desktopId isnt $scope.desktopId
    createAnswer data.sdp, $scope.desktopId, $scope, data.sourceId

  # 接收 Candidate
  socket.on 'candidate', (data)->
    for peer in peers
      if peer.id is data.sourceId
        peer.obj.addIceCandidate new RTCIceCandidate
          sdpMLineIndex: data.candidate.sdpMLineIndex
          candidate: data.candidate.candidate
        break

  # 接收 Viewer Candidate
  socket.on 'candidateViewer', (data)->
    for peer in viewers
      if peer.id is data.viewerId
        peer.obj.addIceCandidate new RTCIceCandidate
          sdpMLineIndex: data.candidate.sdpMLineIndex
          candidate: data.candidate.candidate
        break

  # 接收 Viewer
  socket.on 'viewerOffer', (data)->
    createViewerAnswer data.sdp, $scope.desktopId, $scope, data.viewerId
]

# 大廳
director.controller 'lobby', ['$scope', '$location', ($scope, $location)->
  $scope.makeDesktop = ->
    $location.path("d/#{rs(6)}").replace()
]

# 影像來源
director.controller 'source', ['$scope', '$routeParams', '$location', ($scope, $routeParams, $location)->
  preview = document.getElementById('source-preview')

  $scope.gotUserMedia = false
  socket.emit 'joinSource', 
    desktopId: $routeParams.desktopId

  # 加入來源失敗
  socket.on 'joinSourceFail', (data)->
    $scope.$apply ->
      $location.path("")

  # 啟用本地鏡頭
  socket.on 'joinedSource', (data)->
    $scope.$apply ->
      $scope.desktopId = data.desktopId
      $scope.sourceId = data.sourceId
    getUserMedia.call navigator,
      video: true
      audio: true
    , (stream)->
      $scope.gotUserMedia = true
      preview.src = URL.createObjectURL stream
      preview.play()

      createOffer stream, data.desktopId, $scope

    , (err)->
      console.error err

  # 接收 Destop Answer
  socket.on 'sourceAnswer', (data)->
    answerSDP = new RTCSessionDescription
      sdp: data.sdp
      type: 'answer'
    peerSource.setRemoteDescription answerSDP

  # 接收 Candidate
  socket.on 'candidate', (data)->
    peerSource.addIceCandidate new RTCIceCandidate
      sdpMLineIndex: data.candidate.sdpMLineIndex
      candidate: data.candidate.candidate
]

# 建立接收者
createAnswer = (offerSDP, desktopId, $scope, sourceId)->
  offerSDP = new RTCSessionDescription
    sdp: offerSDP
    type: 'offer'

  peer = new RTCPeerConnection iceServers, optionalRtpDataChannels

  # ICE
  peer.onicecandidate = (event)->
    return if !peer or !event or !event.candidate
    socket.emit 'candidate',
      type: 'desktop'
      desktopId: desktopId
      sourceId: sourceId
      candidate: event.candidate

  peer.onaddstream = (event)->
    return if !event or !event.stream

    # Shortcut for stream
    sourceStreams[sourceId] = event.stream

    $scope.$apply ->
      $scope.videos.push
        src: URL.createObjectURL event.stream
        sourceId: sourceId

      setTimeout ->
        vs = document.querySelectorAll("#source-list video")
        vs[vs.length - 1].src = URL.createObjectURL event.stream
      , 250

    #mainDOM.src = URL.createObjectURL event.stream
    #mainDOM.play()

  peers.push
    id: sourceId
    obj: peer

  dataChannel = peer.createDataChannel 'RTCDataChannel',
    reliable: false

  setChannelEvents dataChannel, 'Desktop'

  peer.setRemoteDescription offerSDP
  peer.createAnswer (sessionDescription)->
    peer.setLocalDescription sessionDescription
    socket.emit 'sourceAnswer', 
      sourceId: sourceId
      desktopId: desktopId
      sdp: sessionDescription.sdp
  , null, mediaConstraints

# 建立觀看應答
createViewerAnswer = (offerSDP, desktopId, $scope, viewerId)->
  offerSDP = new RTCSessionDescription
    sdp: offerSDP
    type: 'offer'

  peer = new RTCPeerConnection iceServers, optionalRtpDataChannels

  # ICE
  peer.onicecandidate = (event)->
    return if !peer or !event or !event.candidate
    socket.emit 'candidateViewer',
      type: 'desktop'
      desktopId: desktopId
      viewerId: viewerId
      candidate: event.candidate

  peer.addStream activedStream if activedStream?

  viewers.push
    id: viewerId
    obj: peer

  dataChannel = peer.createDataChannel 'RTCDataChannel',
    reliable: false

  setChannelEvents dataChannel, 'Desktop'

  peer.setRemoteDescription offerSDP
  peer.createAnswer (sessionDescription)->
    peer.setLocalDescription sessionDescription
    socket.emit 'viewerAnswer', 
      viewerId: viewerId
      desktopId: desktopId
      sdp: sessionDescription.sdp
  , null, mediaConstraints

# 建立發送者
peerSource = null
createOffer = (stream, desktopId, $scope)->
  peerSource = new RTCPeerConnection iceServers, optionalRtpDataChannels

  # ICE
  peerSource.onicecandidate = (event)->
    return if !event or !event.candidate

    socket.emit 'candidate',
      type: 'source'
      desktopId: desktopId
      candidate: event.candidate
      sourceId: $scope.sourceId

  peerSource.addStream stream

  # 建立 Data Channel
  dataChannel = peerSource.createDataChannel 'RTCDataChannel',
    reliable: false

  setChannelEvents dataChannel, 'Source'

  peerSource.createOffer (sessionDescription)->
    peerSource.setLocalDescription sessionDescription
    
    # Send to Partner
    socket.emit 'sourceOffer',
      sourceId: $scope.sourceId
      desktopId: desktopId
      sdp: sessionDescription.sdp
  , null, mediaConstraints


# 建立發送者
peerViewer = null
createViewerOffer = (desktopId, $scope)->
  peerViewer = new RTCPeerConnection iceServers, optionalRtpDataChannels

  # ICE
  peerViewer.onicecandidate = (event)->
    return if !event or !event.candidate

    socket.emit 'candidateViewer',
      type: 'viewer'
      desktopId: desktopId
      candidate: event.candidate
      viewerId: $scope.viewerId

  peerViewer.onaddstream = (event)->
    return if !event or !event.stream

    activedStream = event.stream

    viewer = document.getElementById 'viewer-box'
    viewer.src = URL.createObjectURL event.stream

  # 建立 Data Channel
  dataChannel = peerViewer.createDataChannel 'RTCDataChannel',
    reliable: false

  setChannelEvents dataChannel, 'Viewer'

  peerViewer.createOffer (sessionDescription)->
    peerViewer.setLocalDescription sessionDescription
    
    # Send to Partner
    socket.emit 'viewerOffer',
      viewerId: $scope.viewerId
      desktopId: desktopId
      sdp: sessionDescription.sdp

  , null, mediaConstraints
