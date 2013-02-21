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
  getFile: (req, res) =>
    setBolideContents = (projectId, fileId) =>
      @azkaban.dementorChannel.getFileContents projectId, fileId, (err, contents) =>
        logger.debug "Returned getFile", {hasError:err?, projectId:projectId, fileId:fileId}
        if err
          @sendErrorResponse(res, err)
        else
          url = "#{@Settings.bolideUrl}/doc/#{fileId}?v=0"
          #write file contents to ShareJS (p is position, i is insert)
          @request.post url, json: [contents], (error, response, body)=>
            res.json projectId: projectId, fileId:fileId

    res.header 'Access-Control-Allow-Origin', '*'
    fileId = req.params['fileId']
    projectId = req.params['projectId']
    if req.query?['reset']
      logger.debug "Resetting file contents", {projectId:projectId, fileId:fileId}
      url = "#{@Settings.bolideUrl}/doc/#{fileId}"
      @request.del url, (error, response, body) =>
        return @sendErrorResponse(res, err) if error
        setBolideContents(projectId, fileId)
    else
      logger.debug "Getting file contents", {projectId:projectId, fileId:fileId}
      ensureEmptyFile = (callback)=>
        @request.get "#{@Settings.bolideUrl}/doc/#{fileId}", (error, response, body) =>
          return @sendErrorResponse(response, error) if error
          if body
            logger.error "getFile called more than once", {projectId:projectId, fileId:fileId}
            return res.send ""
          callback()
      ensureEmptyFile =>
        setBolideContents projectId, fileId


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
