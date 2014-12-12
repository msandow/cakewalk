extensions = require('./extensions.coffee')
utilities = require('./utilities.coffee')
fs = require('fs')
url = require('url')
async = require('async')
_ = require('underscore')
_path = require('path')
http = require('http')

module.exports = class Server
  constructor: () ->
    @port = null
    @server = null
    @routes = []
    
  serverHandler: (req, res) =>
    self = this
  
    utilities.parseRequest(req, (parsed) =>
      found = false
      tokenFinder = new RegExp('\\{\\{(.+?)\\}\\}', '')
      testingRoute = null
      
      for r in @routes
        if tokenFinder.test(r.route)
          testingRoute = utilities.escapeRegExp(r.route)
          tokenReference = []

          for token in r.route.match(new RegExp(tokenFinder.source, 'gi'))
            testingRoute = testingRoute.replace(utilities.escapeRegExp(token),'([^\/]+?)')
            tokenReference.push( token.replace(tokenFinder,'$1') )
          
          testingRoute+='$'
          fedTokens = do () ->
            reg = parsed.path.match(new RegExp(testingRoute, ''))
            if reg then reg.slice(1) else []

          for v,k in tokenReference
            parsed.params[v] = fedTokens[k] if fedTokens[k]

        else
          testingRoute = utilities.escapeRegExp(r.route)+'$'

        found = r if new RegExp(testingRoute,'').test(parsed.path) and
          (r.method is 'ALL' or r.method is parsed.method)

      utilities.objectInts(parsed)
      
      if found
        found.handler.apply(self, [parsed, res])
      else
        @notFound(res)
    )
    
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
          transforms[parsed.ext](res, streamText)
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
  
  send: (res, data, customType) ->
    if typeof data is 'object'
      contentType = extensions.json
      data = JSON.stringify(data)
    if typeof data is 'number' or typeof data is 'string'
      contentType = extensions.txt
    if typeof data is 'boolean'
      contentType = extensions.txt
      data = ''
      
    res.writeHead(200,
      'Content-Type': customType or contentType
    )
    
    res.end(data)
  
  notFound: (res) ->
    res.writeHead(404,
      'Content-Type': extensions.txt
    )
    
    res.end('')
  
  assignRoute: (method, route, handler) ->
    newRoute = _path.resolve(__dirname, process.cwd() + route)

    if route[route.length-1] is '/' and newRoute[newRoute.length-1] isnt '/'
      newRoute += '/'

    @routes.push(
      method: method
      route: newRoute
      handler: handler
    )

  all: (route, handler) ->
    @assignRoute('ALL', route, handler)

  get: (route, handler) ->
    @assignRoute('GET', route, handler)

  post: (route, handler) ->
    @assignRoute('POST', route, handler)

  put: (route, handler) ->
    @assignRoute('PUT', route, handler)

  delete: (route, handler) ->
    @assignRoute('DELETE', route, handler)

  static: (path, root=false, transforms={}) ->
    self = this
    
    if utilities.isDirectory(path)
      utilities.directoryWalker(path, (files) =>
        if root
          files = files.map((i) ->
            {
              path: i.replace(path,root)
              src: i
            }
          )
        else
          files = files.map((i) ->
            {
              path: i
              src: i
            }
          )

        for file in files
          filePath = _path.relative( process.cwd(), file.path )
          filePath = '/' + filePath if filePath[0] isnt '/' and filePath[0] isnt '.'
          src = file.src
          
          do (filePath, src) =>
            #console.log(filePath, src)
            self.get(filePath, (req, res) =>
              self.sendFile(res, src, transforms)
            )
        #console.log(@routes)
      )
  
  render: (res, path, tokens={}) ->
    dir = _path.dirname(path)
    
    res.writeHead(200,
      'Content-Type': extensions.html
    )
    
    regexps =
      inserts: new RegExp('\\{\\{\\s*\\>\\s*(.+?)\\s*\\}\\}', 'gim')
      tokens: new RegExp('\\{\\{\\s*\\*\\s*(.+?)\\s*\\}\\}', 'gim')
    
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
            content = content.replace(new RegExp(utilities.escapeRegExp(reg.token), 'gm'), reg.content)

          parser(content)
        )
      else
        for token in _.uniq(content.match(regexps.tokens))
          variable = token.replace(regexps.tokens, '$1').trim()
          
          if tokens[variable]
            variable = tokens[variable]
          else
            variable = '<!-- Undefined HTML token '+variable+' -->'

          content = content.replace(new RegExp(utilities.escapeRegExp(token), 'gm'), variable)

        res.end(content)
        
    if utilities.isFile(path)
      fs.readFile(path, 'utf8', (err, content) ->
        parser(content)
      )
  
  listen: (port = 8000) ->
    @port = port
    @server = http
      .createServer(@serverHandler)
      .listen(@port)
  
  reset: () ->
    @port = null
    @routes = []
  
  close: () ->
    @server.close()