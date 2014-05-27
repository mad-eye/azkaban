async = require 'async'
{EventEmitter} = require 'events'
{Project, File, wrapDbError} = require './models'
{crc32} = require("madeye-common")
fs = require "fs"
{Settings} = require 'madeye-common'
_path = require "path"
{ncp} = require "ncp"
ncp.limit = 16
_ = require 'underscore'

class FileController extends EventEmitter
  constructor: (@settings=Settings) ->
    unless fs.existsSync @settings.userStaticFiles
      fs.mkdir @settings.userStaticFiles

  sendErrorResponse: (res, err) ->
    @emit 'warn', err.message, err
    res.json 500, {error:err}

  #TODO: Check for permissions
  getFile: (req, res) ->
    res.header 'Access-Control-Allow-Origin', '*'
    fileId = req.params['fileId']
    projectId = req.params['projectId']
    reset = req.query?['reset'] ? false
    @emit 'trace', "getFile for #{fileId}"
    @azkaban.fileSyncer.loadFile projectId, fileId, reset, (err, checksum) =>
      if err
        @sendErrorResponse(res, err)
      else
        res.json projectId: projectId, fileId:fileId, checksum:checksum

  #TODO maybe this and createImpressJSProject should be broken out into another file?
  saveStaticFile: (req, res) ->
    unless req.body["static"]
      throw new Error 'saveFile for non-static files is obsoleted; please correct calling function.'
    res.header 'Access-Control-Allow-Origin', '*'
    fileId = req.params['fileId']
    contents = req.body.contents

    file = File.findOne {_id: fileId}, (err, file)=>
      projectId = file.projectId
      fs.writeFile "#{@settings.userStaticFiles}/#{projectId}/#{file.path}", contents, (err)=>
        if err
          @sendErrorResponse(res, err)
        else
          res.json {projectId, fileId, saved:true}

  #helper function for recursiveRead
  #callback: (err) ->
  _applyAction = (path, action, callback) ->
    fs.stat path, (err, stat) ->
      return callback err if err
      action path, stat, (err) ->
        return callback err if err
        if stat.isDirectory()
          recursiveRead path, action, callback
        else
          callback null

  #action: (path, stat, cb) ->, called for each file found.
  #callback: (err) ->, called when done
  recursiveRead = (dir, action, callback)->
    fs.readdir dir, (err, files)->
      return callback err if err
      fullPaths = _.map files, (file)-> "#{dir}/#{file}"
      async.each fullPaths, (path, cb) ->
        _applyAction path, action, cb
      , callback

  isBinary = (path)->
    /\.(bmp|gif|jpg|jpeg|png|psd|ai|ps|svg|pdf|exe|jar|dwg|dxf|7z|deb|gz|zip|dmg|iso|avi|mov|mp4|mpg|wmb|vob)$/.exec(path)?

  createImpressJSProject: (req, res) ->
    azkaban = @azkaban

    res.header 'Access-Control-Allow-Origin', '*'
    Project.create {name: "impress.js", impressJS: true}, (err, proj) =>
      projectId = proj.id
      projectDir = "#{@settings.userStaticFiles}/#{projectId}"

      #ignore the .git file
      filter = (path)->
        not /\.git$/.test path

      #callback: (err) ->
      createFileInDb = (path, stat, callback) ->
        relativePath = _path.relative projectDir, path
        dbFile = new File {orderingPath: relativePath, path: relativePath, projectId, saved:true, isDir: stat.isDirectory()}
        if isBinary(path) or stat.isDirectory()
          dbFile.save callback
        else
          fs.readFile path, 'utf-8', (err, data) ->
            return callback err if err
            checksum = crc32 data
            dbFile.fsChecksum = checksum
            dbFile.loadChecksum = checksum
            dbFile.save (err) ->
              return callback err if err
              azkaban.bolideClient.setDocumentContents dbFile._id, data, false, callback


      ncp "#{__dirname}/../template_projects/impress.js", projectDir, {filter}, (err) =>
        return @sendErrorResponse(res, err) if err

        #create files for each of the files that was copied over
        recursiveRead projectDir, createFileInDb, (error) =>
          return @sendErrorResponse(res, error) if error
          res.json {projectId}


module.exports = FileController
