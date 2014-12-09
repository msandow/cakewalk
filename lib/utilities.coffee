extensions = require('./extensions.coffee')
async = require('async')
parsePath = require('parse-filepath')
fs = require('fs')
url = require('url')
_path = require('path')

module.exports =
  parseRequest: (req) ->
    {
      headers: req.headers
      url: req.url
      method: req.method
      path: _path.join(process.cwd(), url.parse(req.url).pathname)
    }
  
  directoryWalker:  (dir, cb) ->
    paths = []
    q = async.queue((item, callback) ->
      if /\.[\w]+$/gi.test(item.root + item.path)
        paths.push(item.root + item.path)
        callback()
      
      else 
        
        item.path = item.path + '/' if item.path.slice(-1) isnt '/'

        fs.readdir(item.root + item.path, (err, files) ->
          iterate = 0
          for path in files
            do (path, item) ->
              fs.stat(item.root + item.path + path, (err, stats) ->
                if stats.isFile()

                  paths.push(item.root + item.path + path) 
                else if stats.isDirectory() and path isnt 'node_modules'

                  q.push(
                    root: item.root + item.path
                    path: path                  
                  )

                iterate++
                callback() if iterate is files.length
              )
        )
    , 2)
  
    q.drain = () ->
      cb(paths)
    
    q.push(
      path: dir
      root: ''
    )
  
  isDirectory: (path) ->
    if fs.existsSync(path)
      stats = fs.lstatSync(path)
      if stats.isDirectory()
        return true
      else
        console.error('Path',path,'is not a file')
        return false
    else
      console.error('Path',path,'not found')
      return false
  
  isFile: (path) ->
    if fs.existsSync(path)
      stats = fs.lstatSync(path)
      if stats.isFile()
        return true
      else
        console.error('Path',path,'is not a file')
        return false
    else
      console.error('Path',path,'not found')
      return false
  
  getExtensionDataForPath: (path) ->
    if @isFile(path)
      ext = parsePath(path)

      if extensions[ext.extSegments[ext.extSegments.length - 1].replace(/^\.*/g, '')]
        return {
          ext: ext.extSegments[ext.extSegments.length - 1].replace(/^\.*/g, '')
          name: ext.basename.replace(/^\.*/g, '')
        }
      else
        console.error('Path',path,'doesn\'t have a matching extension of',ext)
        return false
    else
      return false