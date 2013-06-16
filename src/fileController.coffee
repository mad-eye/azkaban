async = require 'async'
{logger} = require './logger'
{Project, File, wrapDbError} = require './models'
{crc32} = require("madeye-common")
fs = require "fs"
{Settings} = require 'madeye-common'
uuid = require 'node-uuid'
wrench = require 'wrench'
_ = require 'underscore'

class FileController
  constructor: (@settings=Settings) ->

  sendErrorResponse: (res, err) ->
    logger.error err.message, err
    res.json 500, {error:err}

  #TODO: Check for permissions
  getFile: (req, res) ->
    res.header 'Access-Control-Allow-Origin', '*'
    fileId = req.params['fileId']
    projectId = req.params['projectId']
    reset = req.query?['reset'] ? false
    @azkaban.fileSyncer.loadFile projectId, fileId, reset, (err, checksum, warning) =>
      if err
        @sendErrorResponse(res, err)
      else
        res.json projectId: projectId, fileId:fileId, checksum:checksum, warning: warning

  saveFile: (req, res) ->
    res.header 'Access-Control-Allow-Origin', '*'
    fileId = req.params['fileId']
    projectId = req.params['projectId']
    contents = req.body.contents
    checksum = crc32 contents if contents
    logger.debug "Saving file contents", {projectId, fileId, checksum}
    @azkaban.dementorChannel.saveFile projectId, fileId, contents, (err) =>
      logger.debug "Returned saveFile", {hasError:err?, projectId:projectId, fileId:fileId}
      if err
        @sendErrorResponse(res, err)
      else
        res.json {projectId: projectId, fileId:fileId, saved:true}
        File.update {_id:fileId}, {modified_locally:false, checksum}
        @azkaban.ddpClient.invokeMethod 'markDirty', ['files', fileId]

  #TODO maybe this and impressJS should be broken out into another file?
  #TODO add test for saveStaticFile
  saveStaticFile: (req, res) ->
    res.header 'Access-Control-Allow-Origin', '*'
    fileId = req.params['fileId']
    projectId = req.params['projectId']
    contents = req.body.contents

    fs.writeFile file.path, contents, (err)->
      if err
        @sendErrorResponse(res, err)
      else
        res.json {projectId, fileId, saved:true}
        File.update {_id:fileId}, {modified_locally:false, checksum}
        @azkaban.ddpClient.invokeMethod 'markDirty', ['files', fileId]

  recursiveRead = (dir, callback)->
    allFiles = []
    dirCount = 0
    fs.readdir dir, (err, files)->
      fullPathFiles = _.map files, (file)-> "#{dir}/#{file}"
      allFiles = allFiles.concat _.map fullPathFiles, (path)-> {path, isDir: false}
      directories = []
      async.map fullPathFiles, fs.stat, (err, stats)->
        for stat, i in stats
          if stat.isDirectory()
            allFiles[i].isDir = true
            directories.push("#{dir}/#{files[i]}")
        uncrawledDirCount = directories.length
        return callback(null, allFiles) if uncrawledDirCount == 0

        fullPathFiles = _.map files, (file)-> {path: "#{dir}/#{file}", isDir: false}

        async.map directories, recursiveRead, (err, results)->
          for result in results
            allFiles = allFiles.concat result
          callback null, allFiles

  createImpressJSProject: (req, res) ->
    res.header 'Access-Control-Allow-Origin', '*'
    Project.create {name: "impress.js", isImpressJS: true}, (err, proj) =>
      projectId = proj.id
      projectDir = "#{@settings.userStaticFiles}/#{projectId}"

      #maybe clearer/faster to just shell out?
      wrench.copyDirRecursive "#{__dirname}/../template_projects/impress.js", projectDir, {}, (err)->
        #delete .git file that is copied over
        fs.unlink "#{projectDir}/.git", ->
          #create files for each of the files that was copied over
          recursiveRead projectDir, (error, files)->
            createFileInDb = (fileObject, callback)->
              File.create {orderingPath: fileObject.path, path: fileObject.path, projectId, saved:true, isDir: fileObject.isDir}, (err)->
                console.error err if err
                callback(err)
            async.map files, createFileInDb, (err)->
              res.json {projectId}


module.exports = FileController
