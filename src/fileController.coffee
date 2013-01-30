messageMaker = require("madeye-common").messageMaker
{logger} = require './logger'

class FileController
  constructor: ->
    @dementorChannel = require('../ServiceKeeper').ServiceKeeper.instance().getDementorChannel()
    @Settings = require('madeye-common').Settings
    @request = require "request"

  sendErrorResponse: (res, err) ->
    logger.error err.message, err
    res.json 500, {error:err}

  #TODO: Check for permissions
  getFile: (req, res) =>
    res.header 'Access-Control-Allow-Origin', '*'
    fileId = req.params['fileId']
    projectId = req.params['projectId']
    logger.debug "Getting file contents", {projectId:projectId, fileId:fileId}
    @dementorChannel.getFileContents projectId, fileId, (err, contents) =>
      if err
        @sendErrorResponse(res, err)
      else
        res.send JSON.stringify projectId: projectId, fileId:fileId, body:contents


  saveFile: (req, res) ->
    res.header 'Access-Control-Allow-Origin', '*'
    fileId = req.params['fileId']
    projectId = req.params['projectId']
    contents = req.body.contents
    logger.debug "Saving file contents", {projectId:projectId, fileId:fileId}
    @dementorChannel.saveFile projectId, fileId, contents, (err) =>
      if err
        @sendErrorResponse(res, err)
      else
        res.send JSON.stringify {projectId: projectId, fileId:fileId, saved:true}

module.exports = FileController
