{Project, File, wrapDbError} = require './models'
{errors, errorType} = require 'madeye-common'
{logger} = require './logger'
semver = require 'semver'
FileSyncer = require './fileSyncer'

sendErrorResponse = (res, err) ->
  err = wrapDbError err
  logger.error err.message, err
  res.json 500, {error:err}

class DementorController
  constructor: () ->
    @minDementorVersion = '0.1.0'
    @minNodeVersion = '0.8.21'

  checkVersion: (dementorVersion) ->
    return dementorVersion? && semver.gte dementorVersion, @minDementorVersion

  nodeVersionWarning: (nodeVersion) ->
    unless nodeVersion? && semver.gte nodeVersion, @minNodeVersion
      return "Your NodeJs is less than required (#{@minNodeVersion}).  Please upgrade to avoid any funny business."
    return null

  firefoxPerformanceWarning = "Firefox is currently experiencing performance issues with MadEye in Hangouts.\n" +
    "For Hangout mode, please use Chrome or Safari for the best performance."
  createProject: (req, res) =>
    unless @checkVersion req.body['version']
      sendErrorResponse(res, errors.new errorType.OUT_OF_DATE); return
    warning = @nodeVersionWarning(req.body['nodeVersion']) ? firefoxPerformanceWarning

    Project.create name: req.body['projectName'], (err, proj) =>
      if err then sendErrorResponse(res, err); return
      logger.debug "Project created", {projectId:proj._id}
      @azkaban.fileSyncer.syncFiles req.body['files'], proj._id, (err, files) ->
        if err then sendErrorResponse(res, err); return
        res.json project:proj, files: files, warning: warning

  refreshProject: (req, res) =>
    unless @checkVersion req.body['version']
      sendErrorResponse(res, errors.new errorType.OUT_OF_DATE); return
    warning = @nodeVersionWarning(req.body['nodeVersion']) ? firefoxPerformanceWarning

    projectId = req.params['projectId']
    project =
      name: req.body['projectName']
      closed: false
    Project.findOneAndUpdate {_id:projectId}, project, {new:true, upsert:true}, (err, proj) =>
      if err then sendErrorResponse(res, err); return
      logger.debug "Project refreshed", {projectId:proj._id}
      deleteMissing = true
      @azkaban.fileSyncer.syncFiles req.body['files'], proj._id, deleteMissing, (err, files) ->
        if err then sendErrorResponse(res, err); return
        res.json project:proj, files: files, warning: warning

module.exports = DementorController
