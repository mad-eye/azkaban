{Settings} = require 'madeye-common'
{Project, File, wrapDbError} = require './models'
{errors, errorType} = require 'madeye-common'

sendErrorResponse = (res, err) ->
  err = wrapDbError err
  console.log "Sending error ", err
  res.json 500, {error:err}

class DementorController
  constructor: () ->

  createProject: (req, res) =>
    Project.create name: req.body['projectName'], (err, proj) ->
      if err then sendErrorResponse(res, err); return
      File.addFiles req.body['files'], proj._id, (err, files) ->
        if err then sendErrorResponse(res, err); return
        res.json project:proj, files: files

  refreshProject: (req, res) =>
    projectId = req.params['projectId']
    proj =
      name: req.body['projectName']
      closed: false
    Project.findOneAndUpdate {_id:projectId}, proj, {new:true, upsert:true}, (err, project) ->
      if err then sendErrorResponse(res, err); return
      deleteMissing = true
      File.addFiles req.body['files'], project._id, deleteMissing, (err, files) ->
        if err then sendErrorResponse(res, err); return
        res.json project:project, files: files

module.exports = DementorController
