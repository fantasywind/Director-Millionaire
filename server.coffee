net = require 'net'
express = require('express')
http = require('http')
path = require('path')
rs = require('randomstring')
_ = require('underscore')
 
app = express()
cookieParser = express.cookieParser 'screct'
sessionStore = new express.session.MemoryStore()
 
app.configure ->
  app.set 'port', process.env.PORT or 3000
  app.set 'views', __dirname + '/views'
  app.set 'view engine', 'jade'
  app.use express.favicon()
  app.use express.logger('dev')
  app.use express.bodyParser()
  app.use express.methodOverride()
  app.use cookieParser
  app.use express.session()
  app.use app.router
  app.use require('stylus').middleware(__dirname + '/public')
  app.use express.static(path.join(__dirname, 'public'))
 
app.configure 'development', ->
  app.use express.errorHandler()
 
app.get '/', (req, res)->
  res.render 'main'

app.get '/d/:desktopId', (req, res)->
  res.render 'main'

app.get '/s/:desktopId', (req, res)->
  res.render 'main'

app.get '/v/:desktopId', (req, res)->
  res.render 'main'

app.get '/tmpl/source', (req, res)->
  res.render 'source'

app.get '/tmpl/desktop', (req, res)->
  res.render 'desktop'

app.get '/tmpl/viewer', (req, res)->
  res.render 'viewer'

app.get '/tmpl/lobby', (req, res)->
  res.render 'lobby',
    desktops: _.keys desktops
 
server = http.createServer(app)
server.listen app.get('port'), ->
  console.log("Directed Front server listening on port " + app.get('port'))

io = require('socket.io').listen server
desktops = {}
sources = {}
viewers = {}
io.sockets.on 'connection', (socket)->
  # 建立桌面
  socket.on 'makeDesktop', (data)->
    desktopId = rs.generate(6)
    desktops[desktopId] = socket
    socket.emit 'joinedDesktop', 
      desktopId: desktopId

  # 加入桌面
  socket.on 'joinDesktop', (data)->
    if data.desktopId?
      if desktops[data.desktopId]?
        socket.emit 'joinDesktopFail', 
          msg: 'Not Found Desktop'
      else
        desktops[data.desktopId] = socket
        socket.emit 'joinedDesktop', 
          desktopId: data.desktopId
    else
      desktops[data.desktopId] = socket
      socket.emit 'joinedDesktop', 
        desktopId: data.desktopId

  # 加入來源
  socket.on 'joinSource', (data)->
    if data.desktopId?
      if desktops[data.desktopId]?
        sources[data.desktopId] = [] if sources[data.desktopId] is undefined
        sources[data.desktopId].push socket
        socket.emit 'joinedSource',
          sourceId: sources[data.desktopId].length
          desktopId: data.desktopId
      else
        socket.emit 'joinSourceFail', 
          msg: 'Not Found Desktop'
    else
      socket.emit 'joinSourceFail', 
        msg: 'Invalid Parameter'

  # 加入觀看者
  socket.on 'joinViewer', (data)->
    if data.desktopId?
      if desktops[data.desktopId]?
        viewers[data.desktopId] = [] if viewers[data.desktopId] is undefined
        viewers[data.desktopId].push socket
        socket.emit 'joinedViewer', 
          desktopId: data.desktopId
          viewerId: viewers[data.desktopId].length
      else
        socket.emit 'joinViewerFail', 
          msg: 'Not Found Viewer'
    else
      socket.emit 'joinViewerFail', 
        msg: 'Not Found Viewer'

  # 遞送 Source Offer
  socket.on 'sourceOffer', (data)->
    if desktops[data.desktopId]?
      desktops[data.desktopId].emit 'sourceOffer',
        sourceId: data.sourceId
        sdp: data.sdp
        desktopId: data.desktopId

  # 遞送 Viewer Offer
  socket.on 'viewerOffer', (data)->
    if desktops[data.desktopId]?
      desktops[data.desktopId].emit 'viewerOffer',
        viewerId: data.viewerId
        sdp: data.sdp
        desktopId: data.desktopId

  # 遞送 Source Answer
  socket.on 'sourceAnswer', (data)->
    if sources[data.desktopId]?
      sourceId = parseInt data.sourceId, 10
      if sources[data.desktopId][sourceId - 1]?
        sources[data.desktopId][sourceId - 1].emit 'sourceAnswer',
          sdp: data.sdp
          desktopId: data.desktopId

  # 遞送 Viewer Answer
  socket.on 'viewerAnswer', (data)->
    if viewers[data.desktopId]?
      viewerId = parseInt data.viewerId, 10
      if viewers[data.desktopId][viewerId - 1]?
        viewers[data.desktopId][viewerId - 1].emit 'viewerAnswer',
          sdp: data.sdp
          desktopId: data.desktopId1

  # 更換 Source
  socket.on 'changeSource', (data)->
    if viewers[data.desktopId]?
      for viewer in viewers[data.desktopId]
        viewer.emit 'changeSource', {}


  # 遞送 Candidate
  socket.on 'candidate', (data)->
    if data.type is 'source'
      if desktops[data.desktopId]?
        desktops[data.desktopId].emit 'candidate',
          type: data.type
          candidate: data.candidate
          sourceId: data.sourceId
    else if data.type is 'desktop'
      if sources[data.desktopId]?
        sourceId = parseInt data.sourceId, 10
        if sources[data.desktopId][sourceId - 1]?
          sources[data.desktopId][sourceId - 1].emit 'candidate',
            type: data.type
            candidate: data.candidate

  # 遞送 Candidate
  socket.on 'candidateViewer', (data)->
    if data.type is 'viewer'
      if desktops[data.desktopId]?
        desktops[data.desktopId].emit 'candidateViewer',
          type: data.type
          candidate: data.candidate
          viewerId: data.viewerId
    else if data.type is 'desktop'
      if viewers[data.desktopId]?
        viewerId = parseInt data.viewerId, 10
        if viewers[data.desktopId][viewerId - 1]?
          viewers[data.desktopId][viewerId - 1].emit 'candidateViewer',
            type: data.type
            candidate: data.candidate
    