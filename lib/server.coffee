extensions = require('./extensions.coffee')
utilities = require('./utilities.coffee')
fs = require('fs')
url = require('url')
async = require('async')
_ = require('underscore')
_path = require('path')
coffee = require('coffee-script')

module.exports = class Server
  constructor: () ->
    @port = null
    @server = require('http')
    @routes = []
    
  serverHandler: (req, res) =>
    parsed = utilities.parseRequest(req)
    routes = _.filter(@routes, (i) ->
      i.route is parsed.path
    )

    self = this

    if routes.length
      async.series(routes.map((i) ->
        (cb) ->
          next = () ->
            cb(null, true)
          
          i.handler.apply(self, [req, res, next])
      ), (err, results) ->
        res.end()
      )
    else
      @notFound(res)
    
  sendFile: (res, path, transforms) ->
    parsed = utilities.getExtensionDataForPath(path)

    if parsed
      res.writeHead(200,
        'Content-Type': extensions[parsed.ext]
      )
      stream = fs.createReadStream(path,
        bufferSize: 64 * 1024
      )
      
      if transforms[parsed.ext]
        streamText = ''
      
        stream 
        .on('end', ()->
          res.end(coffee.compile(streamText))
        )
        .on('readable', ()->
          chunk
          while(null isnt (chunk = stream.read()))
            streamText += chunk
        )
      else
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
    
    res.write(data)
  
  notFound: (res) ->
    res.writeHead(404,
      'Content-Type': extensions.txt
    )
    
    res.end('')
  
  on: (route, handler) ->
    newRoute = _path.resolve(__dirname, process.cwd() + route)

    if route[route.length-1] is '/' and newRoute[newRoute.length-1] isnt '/'
      newRoute += '/'

    @routes.push(
      route: newRoute
      handler: handler
    )

  static: (path, transforms={}) ->
    self = this
    if utilities.isDirectory(path)
      utilities.directoryWalker(path, (files) =>        
        for file in files
          file = _path.relative( process.cwd(), file )
          file = '/' + file if file[0] isnt '/' and file[0] isnt '.'
        
          do (file) =>            
            self.on(file, (req, res, next) =>
              self.sendFile(res, '.'+file, transforms)
            )
        #console.log(@routes)
      )
  
  render: (res, path, cb) ->
    dir = _path.dirname(path)
    
    res.writeHead(200,
      'Content-Type': extensions.html
    )
    
    regexps =
      inserts: new RegExp('\\{\\{\\s*\\>\\s*(.+)?\\s*\\}\\}', 'gim')
    
    haveParsed ={}
    
    parser  = (content) ->
      inserts = _.uniq(content.match(regexps.inserts))
      
      if inserts.length
        inserts = inserts.map((ins) ->
          (cb) ->
            file = _path.relative(__dirname, _path.join(dir, ins.replace(regexps.inserts, '$1').trim()))

            if haveParsed[file]
              cb(null, haveParsed[file])
              return

            if /\.(html|htm)$/i.test(file)
              fs.readFile(file, 'utf8', (err, content) ->
                if err and err.errno is 34
                  content = '<!-- Cant find HTML insert '+err.path+' -->'

                haveParsed[file] =
                  token: ins
                  content: content

                cb(null, haveParsed[file])
              )
            else if /\.(js|coffee)$/i.test(file)
              haveParsed[file] =
                  token: ins
                  content: require(file)()

              cb(null, haveParsed[file])
        )

        async.series(inserts, (err, results) ->
          for reg in results
            content = content.replace(new RegExp(reg.token,'gim'), reg.content)

          parser(content)
        )
      else
        res.write(content)
        cb()
        
    if utilities.isFile(path)
      fs.readFile(path, 'utf8', (err, content) ->
        parser(content)
      )
  
  listen: (port = 8000) ->
    @port = port
    @server
      .createServer(@serverHandler)
      .listen(@port)