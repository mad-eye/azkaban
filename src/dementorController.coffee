{Settings} = require 'madeye-common'
{Project, File, wrapDbError} = require './models'
{errors, errorType} = require 'madeye-common'
{logger} = require './logger'

sendErrorResponse = (res, err) ->
  err = wrapDbError err
  #logger.error err.message, err
  res.json 500, {error:err}

class DementorController
  constructor: () ->

  createProject: (req, res) =>
    Project.create name: req.body['projectName'], (err, proj) ->
      if err then sendErrorResponse(res, err); return
      logger.debug "Project created", {projectId:proj._id}
      File.addFiles req.body['files'], proj._id, (err, files) ->
        if err then sendErrorResponse(res, err); return
        res.json project:proj, files: files

  refreshProject: (req, res) =>
    projectId = req.params['projectId']
    project =
      name: req.body['projectName']
      closed: false
    Project.findOneAndUpdate {_id:projectId}, project, {new:true, upsert:true}, (err, proj) ->
      if err then sendErrorResponse(res, err); return
      logger.debug "Project refreshed", {projectId:proj._id}
      deleteMissing = true
      File.addFiles req.body['files'], proj._id, deleteMissing, (err, files) ->
        if err then sendErrorResponse(res, err); return
        res.json project:proj, files: files

module.exports = DementorController
