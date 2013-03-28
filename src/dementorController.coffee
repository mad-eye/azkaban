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
    @minDementorVersion = '0.0.25'

  checkVersion: (version) ->
    return version? && semver.gte version, @minDementorVersion

  createProject: (req, res) =>
    unless @checkVersion req.body['version']
      sendErrorResponse(res, errors.new errorType.OUT_OF_DATE); return
    Project.create name: req.body['projectName'], (err, proj) =>
      if err then sendErrorResponse(res, err); return
      logger.debug "Project created", {projectId:proj._id}
      @azkaban.fileSyncer.syncFiles req.body['files'], proj._id, (err, files) ->
        if err then sendErrorResponse(res, err); return
        res.json project:proj, files: files

  refreshProject: (req, res) =>
    unless @checkVersion req.body['version']
      sendErrorResponse(res, errors.new errorType.OUT_OF_DATE); return
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
        res.json project:proj, files: files

module.exports = DementorController
