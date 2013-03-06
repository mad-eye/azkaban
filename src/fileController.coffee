messageMaker = require("madeye-common").messageMaker
{logger} = require './logger'
{Project, File, wrapDbError} = require './models'

class FileController
  constructor: () ->
    @request = require "request"
    @Settings = require("madeye-common").Settings

  sendErrorResponse: (res, err) ->
    logger.error err.message, err
    res.json 500, {error:err}

  _markLocallyUnmodified = (projectId, fileId)->
    File.findById fileId, (err, file) ->
      if err
        logger.error "Error finding file", projectId: projectId, fileId: fileId, err: wrapDbError err
      else
        file.update {$set: {modified_locally:false}}, (err) ->
          if err
            logger.error "Error updating file", projectId: projectId, fileId: fileId, err: wrapDbError err

  #TODO: Check for permissions
  getFile: (req, res) ->
    res.header 'Access-Control-Allow-Origin', '*'
    fileId = req.params['fileId']
    projectId = req.params['projectId']
    reset = req.query?['reset'] ? false
    if reset then logger.debug "Resetting file contents", {projectId:projectId, fileId:fileId}
    @azkaban.dementorChannel.getFileContents projectId, fileId, (err, contents) =>
      logger.debug "Returned getFile", {hasError:err?, projectId:projectId, fileId:fileId}
      return @sendErrorResponse(res, err) if err
      @azkaban.bolideClient.setDocumentContents fileId, contents, reset, (err) =>
        return @sendErrorResponse(res, err) if err
        res.json projectId: projectId, fileId:fileId
        _markLocallyUnmodified(projectId, fileId)

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
        res.json {projectId: projectId, fileId:fileId, saved:true}
        _markLocallyUnmodified(projectId, fileId)


module.exports = FileController
