{Settings} = require 'madeye-common'
{Project} = require './models'

sendErrorResponse = (res, err) ->
  console.log "Sending error ", err
  res.json 500, {error:err}

class DementorController
  constructor: () ->

  createProject: (req, res) =>
    proj = new Project
      name: req.body['projectName']
      files: req.body['files']
    proj.save (err) ->
      if err
        err = errors.new errorType.DATABASE_ERROR, err
        sendErrorResponse(res, err)
        return
      res.json project:proj

  refreshProject: (req, res) =>
    projectId = req.params['projectId']
    Project.findOne {_id:projectId}, (err, proj) ->
      if err
        err = errors.new errorType.DATABASE_ERROR, err
        sendErrorResponse(res, err)
        return
      if proj
        proj.files = req.body['files']
        proj.save (err) ->
          if err
            err = errors.new errorType.DATABASE_ERROR, err
            sendErrorResponse(res, err)
            return
          res.json project:proj
      else
        proj = new Project
          _id: projectId
          name: req.body['projectName']
          files: req.body['files']
        proj.save (err) ->
          if err
            err = errors.new errorType.DATABASE_ERROR, err
            sendErrorResponse(res, err)
            return
          res.json project:proj

module.exports = DementorController
