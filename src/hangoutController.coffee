{Project, wrapDbError} = require './models'
{errors, errorType} = require 'madeye-common'
{logger} = require './logger'

sendErrorResponse = (res, err) ->
  err = wrapDbError err
  logger.error err.message, err
  res.json 500, {error:err}

class HangoutController
  constructor: () ->

  registerHangout: (req, res) =>
    hangoutId = req.params['hangoutId']
    projectId = req.body['projectId']
    Project.update {_id:projectId}, {hangoutId:hangoutId}, (err) =>
      if err then sendErrorResponse(res, err); return
      logger.debug "Hangout registered", {projectId, hangoutId}
      res.end()

  gotoHangout: (req, res) =>
    projectId = req.params['projectId']
    project = Project.findById projectId, 'hangoutId', (err, project) =>
      hangoutId = project?.hangoutId
      if hangoutId
        url = '' #Fill this out
      else
        url = '' #File this out
      #redirect to url




module.exports = HangoutController
