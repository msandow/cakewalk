require('coffee-script/register')
require('mocha')
expect = require('chai').expect
http = require('http')
cakewalk = require('./../cakewalk.js')
async = require('async')
coffee = require('coffee-script')
querystring = require('querystring')
port = 7777
timeout = 100
_url = require('url')

makeRequest = (method, url, data=false, cb) ->
  method = method.toUpperCase()
  opts = _url.parse(url, false, true)  
  opts.method = method

  if data and (method is 'GET' or method is 'DELETE')
    if typeof data is 'object'
      data = querystring.stringify(data)

    opts.path += '?'+data

  req = http.request(opts, (res) ->
    body = ''

    res.on('data', (chunk) ->
      body += chunk
    )

    res.on('end', () ->
      cb(res,body)
    )
  )

  if data and (method is 'POST' or method is 'PUT')
    if typeof data is 'object'
      data = querystring.stringify(data)

    req.write(data)

  req.end()


describe('Server', ->

  describe('Defined Routes', ->
    before(() ->
      cakewalk.listen(port)
    )

    after(() ->
      cakewalk.reset()
      cakewalk.close()
    )

    it('Should get defined route', (done)->
      serverSide = null
      
      cakewalk.get('/', (req, res) ->
        serverSide = req
        @send(res,'Hello World')
      )

      cakewalk.get('/bar', (req, res) ->
        serverSide = req
        @send(res,'Hello Bar','text/html')
      )

      setTimeout(->
        async.series(
          found: (cb) ->
            makeRequest('get', 'http://localhost:'+port+'/', false, (res, body) ->
              expect(serverSide.url).to.equal('/')
              expect(serverSide.method).to.equal('GET')
              expect(serverSide.ext).to.equal('')
              expect(serverSide.path).to.equal(process.cwd()+'/')
              expect(res.statusCode).to.equal(200)
              expect(res.headers['content-type']).to.equal('text/plain')
              expect(body).to.equal('Hello World')
              cb()
            )
          notfound: (cb) ->
            makeRequest('get', 'http://localhost:'+port+'/bar', false, (res, body) ->
              expect(serverSide.url).to.equal('/bar')
              expect(serverSide.method).to.equal('GET')
              expect(serverSide.ext).to.equal('')
              expect(serverSide.path).to.equal(process.cwd()+'/bar')
              expect(res.statusCode).to.equal(200)
              expect(res.headers['content-type']).to.equal('text/html')
              expect(body).to.equal('Hello Bar')
              cb()
            )
          badmethod: (cb) ->
            makeRequest('post', 'http://localhost:'+port+'/', false, (res, body) ->
              expect(serverSide.url).to.equal('/bar')
              expect(serverSide.method).to.equal('GET')
              expect(serverSide.ext).to.equal('')
              expect(serverSide.path).to.equal(process.cwd()+'/bar')
              expect(res.statusCode).to.equal(404)
              cb()
            )
        , (err, results) ->
          done()
        )
      ,timeout)
    )

    it('Should 404 undefined route', (done)->
      makeRequest('get', 'http://localhost:'+port+'/foo', false, (res, body) ->
        expect(res.statusCode).to.equal(404)
        done()
      )
    )
  )

  describe('Static Routes', ->
    before(() ->
      cakewalk.listen(port)
    )

    after(() ->
      cakewalk.reset()
      cakewalk.close()
    )

    it('Should get sub static files', (done)->
      cakewalk.static('./public/')

      setTimeout(->
        async.series(
          image: (cb) ->
            makeRequest('get', 'http://localhost:'+port+'/public/images/test.jpg', false, (res, body) ->
              expect(res.statusCode).to.equal(200)
              expect(res.headers['content-type']).to.equal('image/jpeg')
              cb()
            )
          script: (cb) ->
            makeRequest('get', 'http://localhost:'+port+'/public/scripts/site.coffee', false, (res, body) ->
              expect(res.statusCode).to.equal(200)
              expect(res.headers['content-type']).to.equal('application/coffeescript')

              expected = """
                        arr = [1,2,3]
                        for i in arr
                          console.log(i)
                        """

              expect(body).to.equal(expected)

              cb()
            )
          none: (cb) ->
            makeRequest('get', 'http://localhost:'+port+'/public/images/test2.jpg', false, (res, body) ->
              expect(res.statusCode).to.equal(404)
              cb()
            )
        , (err, results) ->
          done()
        )
      ,timeout)
    )

    it('Should root static files', (done)->
      cakewalk.static('./images/')
      cakewalk.static('./scripts/')

      setTimeout(->
        async.series(
          image: (cb) ->
            makeRequest('get', 'http://localhost:'+port+'/images/test.jpg', false, (res, body) ->
              expect(res.statusCode).to.equal(200)
              expect(res.headers['content-type']).to.equal('image/jpeg')
              cb()
            )
          script: (cb) ->
            makeRequest('get', 'http://localhost:'+port+'/scripts/site.coffee', false, (res, body) ->
              expect(res.statusCode).to.equal(200)
              expect(res.headers['content-type']).to.equal('application/coffeescript')

              expected = """
                        arr = [1,2,3]
                        for i in arr
                          console.log(i)
                        """

              expect(body).to.equal(expected)

              cb()
            )
          none: (cb) ->
            makeRequest('get', 'http://localhost:'+port+'/images/test2.jpg', false, (res, body) ->
              expect(res.statusCode).to.equal(404)
              cb()
            )
        , (err, results) ->
          done()
        )
      ,timeout)
    )

    it('Should get sub static files with transform', (done)->
      cakewalk.static('./public/', false,
        'coffee': (res, text)->
          res.writeHead(200,
            'Content-Type': 'application/javascript'
          )

          res.end(coffee.compile(text))
      )

      setTimeout(->
        async.series(
          image: (cb) ->
            makeRequest('get', 'http://localhost:'+port+'/images/test.jpg', false, (res, body) ->
              expect(res.statusCode).to.equal(200)
              expect(res.headers['content-type']).to.equal('image/jpeg')
              cb()
            )
          script: (cb) ->
            makeRequest('get', 'http://localhost:'+port+'/public/scripts/site.coffee', false, (res, body) ->
              expect(res.statusCode).to.equal(200)
              expect(res.headers['content-type']).to.equal('application/javascript')

              expected = """
                        (function() {
                          var arr, i, _i, _len;

                          arr = [1, 2, 3];

                          for (_i = 0, _len = arr.length; _i < _len; _i++) {
                            i = arr[_i];
                            console.log(i);
                          }

                        }).call(this);

                        """

              expect(body).to.equal(expected)

              cb()
            )
        , (err, results) ->
          done()
        )
      ,timeout)
    )

    it('Should get static files mounted to root', (done)->
      cakewalk.static('./public/', './')

      setTimeout(->
        async.series(
          image: (cb) ->
            makeRequest('get', 'http://localhost:'+port+'/images/test.jpg', false, (res, body) ->
              expect(res.statusCode).to.equal(200)
              expect(res.headers['content-type']).to.equal('image/jpeg')
              cb()
            )
          script: (cb) ->
            makeRequest('get', 'http://localhost:'+port+'/scripts/site.coffee', false, (res, body) ->
              expect(res.statusCode).to.equal(200)
              expect(res.headers['content-type']).to.equal('application/coffeescript')

              expected = """
                        arr = [1,2,3]
                        for i in arr
                          console.log(i)
                        """

              expect(body).to.equal(expected)

              cb()
            )
          json: (cb) ->
            makeRequest('get', 'http://localhost:'+port+'/config.json', false, (res, body) ->
              expect(res.statusCode).to.equal(200)
              expect(res.headers['content-type']).to.equal('application/json')

              expected = """
                        {
                          "foo":"bar"
                        }
                        """

              expect(body).to.equal(expected)

              cb()
            )
          none: (cb) ->
            makeRequest('get', 'http://localhost:'+port+'/public/images/test2.jpg', false, (res, body) ->
              expect(res.statusCode).to.equal(404)
              cb()
            )
        , (err, results) ->
          done()
        )
      ,timeout)
    )

  )

  describe('HTML Rendering', ->
    before(() ->
      cakewalk.listen(port)
    )

    after(() ->
      cakewalk.reset()
      cakewalk.close()
    )

    it('Should serve static HTML', (done)->
      cakewalk.static('./views/', './')

      setTimeout(->
        makeRequest('get', 'http://localhost:'+port+'/main.html', false, (res, body) ->
          expect(res.statusCode).to.equal(200)
          expect(res.headers['content-type']).to.equal('text/html')

          expected = """
                    {{ > mod.coffee }}
                    <p>Foo Bar {{* number }}</p>
                    {{ > ./nav.html }}
                    """

          expect(body).to.equal(expected)

          done()
        )
      ,timeout)
    )

    it('Should render HTML templates', (done)->
      cakewalk.post('/index.html', (req, res) ->
        @render(res,'./views/body.html',
          number: 45
        )
      )

      cakewalk.post('/token.html', (req, res) ->
        @render(res,'./views/token.html',
          variable: 'Foo'
        )
      )

      setTimeout(->
        async.series(
          inserts: (cb) ->
            makeRequest('post', 'http://localhost:'+port+'/index.html', false, (res, body) ->
              expect(res.statusCode).to.equal(200)
              expect(res.headers['content-type']).to.equal('text/html')
              expected = """
                        <!DOCTYPE html>
                        <html lang="en">
                          <head>
                            <meta charset="utf-8">
                            <title>title</title>
                          </head>
                          <body>
                            <u>Module</u>
                        <p>Foo Bar 45</p>
                        <nav>
                          My nav
                        </nav>
                          </body>
                        </html>
                        """

              expect(body).to.equal(expected)

              cb()
            )
          tokens: (cb) ->
            makeRequest('post', 'http://localhost:'+port+'/token.html', false, (res, body) ->
              expect(res.statusCode).to.equal(200)
              expect(res.headers['content-type']).to.equal('text/html')
              expected = """
                        <h1>Header - Foo</h1><!-- Undefined HTML token another -->
                        """

              expect(body).to.equal(expected)

              cb()
            )
        , (err, results) ->
          done()
        )
      ,timeout)
    )
  )

  describe('Posting Data', ->
    before(() ->
      cakewalk.listen(port)
    )

    after(() ->
      cakewalk.reset()
      cakewalk.close()
    )

    it('Should chain post and get data', (done)->
      cakewalk.get('/getter', (req, res) ->
        res.end(req.params.foo)
      )

      cakewalk.post('/poster', (req, res) ->
        self = this
        makeRequest('get', 'http://localhost:'+port+'/getter', req.params, (subres, body) ->
          self.send(res,body)
        )
      )

      setTimeout(->
        makeRequest('post', 'http://localhost:'+port+'/poster', 
          foo: 'bar'
          baz: 3
        , (res, body) ->
          expect(res.statusCode).to.equal(200)
          expect(res.headers['content-type']).to.equal('text/plain')

          expect(body).to.equal('bar')

          done()
        )
      ,timeout)
    )
  )
  
  describe('Dynamic routes', ->
    before(() ->
      cakewalk.listen(port)
    )

    after(() ->
      cakewalk.reset()
      cakewalk.close()
    )

    it('Should find dynamic routes', (done)->
      serverSide = null
    
      cakewalk.get('/dostuff/{{action}}/{{id}}', (req, res) ->
        serverSide = req.params
        @send(res,true)
      )

      setTimeout(->
        makeRequest('get', 'http://localhost:'+port+'/dostuff/foo/123', 
          foo: 'bar'
          baz: 3
        , (res, body) ->
          expect(res.statusCode).to.equal(200)
          expect(res.headers['content-type']).to.equal('text/plain')
          expect(serverSide.foo).to.equal('bar')
          expect(serverSide.baz).to.equal(3)
          expect(serverSide.action).to.equal('foo')
          expect(serverSide.id).to.equal(123)

          done()
        )
      ,timeout)
    )
    
    it('Should render from dynamic routes', (done)->
      cakewalk.get('/getuser/{{name}}', (req, res) ->
        @render(res,'./views/main.html',
          number: req.params.name
        )
      )

      setTimeout(->
        makeRequest('get', 'http://localhost:'+port+'/getuser/bob', false, (res, body) ->
          expect(res.statusCode).to.equal(200)
          expect(res.headers['content-type']).to.equal('text/html')

          expected = """
                    <u>Module</u>
                    <p>Foo Bar bob</p>
                    <nav>
                      My nav
                    </nav>
                    """

          expect(body).to.equal(expected)
          
          done()
        )
      ,timeout)
    )
  )
)