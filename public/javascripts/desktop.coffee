socket = io.connect('http://10.0.1.111:3000')
localStream = null
# WebRTC
dataChannel = null
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
    console.debug 'channel open'
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
  $routeProvider.otherwise 
    controller: 'lobby'
    templateUrl: '/tmpl/lobby'

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
]

# 大廳
director.controller 'lobby', ['$scope', '$location', ($scope, $location)->
  $scope.makeDesktop = ->
    socket.emit 'makeDesktop', {}
    $scope.makeDesktop = -> false

  # 監聽建立桌面事件
  socket.on 'joinedDesktop', (data)->
    if data.desktopId?
      $location.path("d/#{data.desktopId}").replace()
      $scope.$apply ->
        $scope.desktopId = data.desktopId
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
peers = []
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

    $scope.$apply ->
      $scope.videos.push
        src: URL.createObjectURL event.stream
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

  window.adc = dataChannel
  window.peer = peer

  setChannelEvents dataChannel, 'Desktop'

  peer.setRemoteDescription offerSDP
  peer.createAnswer (sessionDescription)->
    peer.setLocalDescription sessionDescription
    socket.emit 'sourceAnswer', 
      sourceId: sourceId
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

  window.cdc = dataChannel
  window.peer = peerSource

  setChannelEvents dataChannel, 'Source'

  peerSource.createOffer (sessionDescription)->
    peerSource.setLocalDescription sessionDescription
    
    # Send to Partner
    socket.emit 'sourceOffer',
      sourceId: $scope.sourceId
      desktopId: desktopId
      sdp: sessionDescription.sdp
  , null, mediaConstraints