{crc32} = require("madeye-common")
{logger} = require './logger'
{Project, File, wrapDbError} = require './models'

class FileController
  constructor: () ->
    @request = require "request"
    @Settings = require("madeye-common").Settings

  sendErrorResponse: (res, err) ->
    logger.error err.message, err
    res.json 500, {error:err}

  _updateFile = (projectId, fileId, updateData)->
    File.findById fileId, (err, file) ->
      if err
        logger.error "Error finding file", projectId: projectId, fileId: fileId, err: wrapDbError err
        return
      file.update {$set: updateData}, (err) ->
        if err
          logger.error "Error updating file", projectId: projectId, fileId: fileId, err: wrapDbError err

  _cleanupLineEndings = (contents) ->
    console.log "cleaning up line endings"
    return contents unless /\r/.test contents
    console.log "yup this file needs some serious cleaning"
    lineBreakRegex = /(\r\n|\r|\n)/gm
    hasDos = /\r\n/.test contents
    hasUnix = /[^\r]\n/.test contents
    hasOldMac = /\r(?!\n)/.test contents
    if hasUnix
      contents.replace lineBreakRegex, '\n'
    else if hasDos and hasOldMac
      contents.replace lineBreakRegex, '\r\n'
    else
      contents

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
      cleanContents = _cleanupLineEndings(contents)
      warning = null
      unless cleanContents == contents
        warning =
          title: "Inconsistent line endings"
          message: "We've converted them into one consistent ending."
      @azkaban.bolideClient.setDocumentContents fileId, cleanContents, reset, (err) =>
        return @sendErrorResponse(res, err) if err
        checksum = crc32 contents if contents?
        res.json projectId: projectId, fileId:fileId, checksum:checksum, warning: warning
        _updateFile projectId, fileId,
          modified_locally:false
          lastOpened:new Date()
          checksum: checksum
          

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
        _updateFile projectId, fileId, {modified_locally:false, checksum}


module.exports = FileController
