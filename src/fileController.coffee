{logger} = require './logger'
{Project, File, wrapDbError} = require './models'
{crc32} = require("madeye-common")
fs = require "fs"
{Settings} = require 'madeye-common'
uuid = require 'node-uuid'
wrench = require 'wrench'

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

  createImpressJSProject: (req, res) ->
    res.header 'Access-Control-Allow-Origin', '*'
    projectId = uuid.v4()
    projectDir = "#{@settings.userStaticFiles}/#{projectId}"

    #TODO ignore git directory
    wrench.copyDirRecursive "#{__dirname}/../template_projects/impress.js", projectDir, {}, (err)->
      #create the project in the db
      #create files for each of the files that was copied over

      res.json {projectId}


module.exports = FileController
