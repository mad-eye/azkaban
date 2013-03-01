messageMaker = require("madeye-common").messageMaker
{logger} = require './logger'

class FileController
  constructor: () ->
    @request = require "request"
    @Settings = require("madeye-common").Settings

  sendErrorResponse: (res, err) ->
    logger.error err.message, err
    res.json 500, {error:err}

  #TODO: Check for permissions
  getFile: (req, res) ->
    res.header 'Access-Control-Allow-Origin', '*'
    fileId = req.params['fileId']
    projectId = req.params['projectId']
    reset = req.query?['reset']
    if reset then logger.debug "Resetting file contents", {projectId:projectId, fileId:fileId}
    @azkaban.dementorChannel.getFileContents projectId, fileId, (err, contents) =>
      logger.debug "Returned getFile", {hasError:err?, projectId:projectId, fileId:fileId}
      return @sendErrorResponse(res, err) if err
      @azkaban.bolideClient.setDocumentContents fileId, reset, contents, (err) =>
        return @sendErrorResponse(res, err) if err
        res.json projectId: projectId, fileId:fileId

  saveFile: (req, res) ->
    res.header 'Access-Control-Allow-Origin', '*'
    fileId = req.params['fileId']
    projectId = req.params['projectId']
    contents = req.body.contents
    logger.debug "Saving file contents", {projectId:projectId, fileId:fileId}
    @azkaban.dementorChannel.saveFile projectId, fileId, contents, (err) =>
      logger.debug "Returned saveFile", {hasError:err?, projectId:projectId, fileId:fileId}
      if err
        @sendErrorResponse(res, err)
      else
        res.send JSON.stringify {projectId: projectId, fileId:fileId, saved:true}

module.exports = FileController
