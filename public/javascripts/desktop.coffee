socket = io.connect('http://10.32.11.196:3000')
selfDOM = document.getElementById('self')
mainDOM = document.getElementById('main')
localStream = null

socket.on 'sourceOffer', (data)->
  createAnswer data.sdp

socket.on 'sourceAnswer', (data)->
  answerSDP = new RTCSessionDescription
    sdp: data.sdp
    type: 'answer'
  peer.setRemoteDescription answerSDP

socket.on 'candidate', (data)->
  peer.addIceCandidate new RTCIceCandidate
    sdpMLineIndex: data.candidate.sdpMLineIndex
    candidate: data.candidate.candidate

iceServers =
  iceServers: [{
    url: 'stun:stun.l.google.com:19302'
  }]

optionalRtpDataChannels =
  optional: [{
    RtpDataChannels: true
  }]

RTCPeerConnection = RTCPeerConnection or webkitRTCPeerConnection or mozRTCPeerConnection

peer = new RTCPeerConnection iceServers, optionalRtpDataChannels

window.peer = peer

dataChannel = null

# ICE
peer.onicecandidate = (event)->
  return if !peer or !event or !event.candidate
  socket.emit 'candidate', event.candidate

peer.onaddstream = (event)->
  return if !event or !event.stream
  mainDOM.src = URL.createObjectURL event.stream
  mainDOM.play()

mediaConstraints =
  optional: []
  mandatory:
    OfferToReceiveAudio: true
    OfferToReceiveVideo: true

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
# -----------------------------------------------------

createAnswer = (offerSDP)->
  offerSDP = new RTCSessionDescription
    sdp: offerSDP
    type: 'offer'

  dataChannel = peer.createDataChannel 'RTCDataChannel',
    reliable: false

  window.dc = dataChannel

  setChannelEvents dataChannel, 'general2'

  peer.addStream localStream
  peer.setRemoteDescription offerSDP
  peer.createAnswer (sessionDescription)->
    peer.setLocalDescription sessionDescription

    socket.emit 'sourceAnswer', 
      sdp: sessionDescription.sdp
  , null, mediaConstraints

createOffer = ->
  peer.addStream localStream
  dataChannel = peer.createDataChannel 'RTCDataChannel',
    reliable: false

  window.dc = dataChannel

  setChannelEvents dataChannel, 'general'

  peer.createOffer (sessionDescription)->
    peer.setLocalDescription sessionDescription
    
    # Send to Partner
    socket.emit 'sourceOffer', 
      sdp: sessionDescription.sdp
  , null, mediaConstraints

window.createOffer = createOffer

# ----------------------------------------
getUserMedia = navigator.getUserMedia or navigator.webkitGetUserMedia or navigator.mozGetUserMedia

getUserMedia.call navigator,
  video: true
  audio: true
, (stream)->
  selfDOM.src = URL.createObjectURL stream
  selfDOM.play()
  localStream = stream