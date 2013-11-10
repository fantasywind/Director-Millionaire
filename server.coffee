net = require 'net'
express = require('express')
http = require('http')
path = require('path')
main = require('./routes/main')
 
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
 
app.get '/', main.desktop
 
server = http.createServer(app)
server.listen app.get('port'), ->
  console.log("Directed Front server listening on port " + app.get('port'))

io = require('socket.io').listen server
io.sockets.on 'connection', (socket)->
  socket.on 'sourceOffer', (data)->
    socket.broadcast.emit 'sourceOffer',
      sdp: data.sdp
  socket.on 'sourceAnswer', (data)->
    socket.broadcast.emit 'sourceAnswer',
      sdp: data.sdp
  socket.on 'candidate', (data)->
    socket.broadcast.emit 'candidate',
      candidate: data
 
source = net.createServer (conn)->
  conn.on 'close', ->
    console.info 'Service Close'
  conn.on 'connection', ->
    console.info 'Client Connected.'
  conn.on 'data', (chunk)->
    console.log chunk
    buf = new Buffer chunk
    console.log buf.toString 'utf8'

source.listen 5555, ->
  console.info 'Service Bound on port 5555'