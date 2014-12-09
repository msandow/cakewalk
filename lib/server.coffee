extensions = require('./extensions.coffee')
utilities = require('./utilities.coffee')
fs = require('fs')
url = require('url')
_ = require('underscore')
_path = require('path')

module.exports = class Server
  constructor: () ->
    @port = null
    @server = require('http')
    @routes = []
    
  serverHandler: (req, res) =>
    parsed = utilities.parseRequest(req)
    console.log(parsed)
    route = _.find(@routes, (i) ->
      i.route is parsed.path
    )

    if route
      route.handler.apply(@,[req,res])
    else
      @notFound(res)
  
  sendFile: (res, path, name) ->
    parsed = utilities.getExtensionDataForPath(path)
    if parsed
      res.writeHead(200,
        'Content-Type': extensions[parsed.ext]
      )
      stream = fs.createReadStream(path,
        bufferSize: 64 * 1024
      )
      
      stream.pipe(res)
    else
      @notFound(res)
  
  send: (res, data) ->
    if typeof data is 'object'
      contentType = extensions.json
      data = JSON.stringify(data)
    if typeof data is 'number' or typeof data is 'string'
      contentType = extensions.txt
      
    res.writeHead(200,
      'Content-Type': contentType
    )
    
    res.end(data)
  
  notFound: (res) ->
    res.writeHead(404,
      'Content-Type': extensions.txt
    )
    
    res.end('')
  
  on: (route, handler) ->
    currRoute = _.find(@routes, (i) ->
      i.route is route
    )

    newRoute = _path.resolve(__dirname, process.cwd() + route)

    if route[route.length-1] is '/' and newRoute[newRoute.length-1] isnt '/'
      newRoute += '/'

    if not currRoute
      @routes.push(
        route: newRoute
        handler: handler
      )
    else
      route.handler = handler
  
  static: (path) ->
    self = this
    if utilities.isDirectory(path)
      utilities.directoryWalker(path, (files) =>        
        for file in files
          file = _path.relative( process.cwd(), file )
          file = '/' + file if file[0] isnt '/' and file[0] isnt '.'
        
          do (file) =>            
            self.on(file, (req, res) =>
              self.sendFile(res, '.'+file)
            )
        console.log(@routes)
      )
  
  listen: (port = 8000) ->
    @port = port
    @server
      .createServer(@serverHandler)
      .listen(@port)