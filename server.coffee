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

app.get '/tmpl/source', (req, res)->
  res.render 'source'

app.get '/tmpl/desktop', (req, res)->
  res.render 'desktop'

app.get '/tmpl/lobby', (req, res)->
  res.render 'lobby',
    desktops: _.keys desktops
 
server = http.createServer(app)
server.listen app.get('port'), ->
  console.log("Directed Front server listening on port " + app.get('port'))

io = require('socket.io').listen server
desktops = {}
sources = {}
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

  # 遞送 Source Offer
  socket.on 'sourceOffer', (data)->
    if desktops[data.desktopId]?
      desktops[data.desktopId].emit 'sourceOffer',
        sourceId: data.sourceId
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

  # 遞送 Candidate
  socket.on 'candidate', (data)->
    if data.type is 'source'
      if desktops[data.desktopId]?
        desktops[data.desktopId].emit 'candidate',
          candidate: data.candidate
          sourceId: data.sourceId
    else if data.type is 'desktop'
      if sources[data.desktopId]?
        sourceId = parseInt data.sourceId, 10
        if sources[data.desktopId][sourceId - 1]?
          sources[data.desktopId][sourceId - 1].emit 'candidate',
            candidate: data.candidate
    