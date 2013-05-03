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
    projectId = req.params['projectId']
    hangoutUrl = req.body['hangoutUrl']
    Project.update {_id:projectId}, {hangoutUrl}, (err) =>
      if err then sendErrorResponse(res, err); return
      logger.debug "Hangout registered", {projectId, hangoutUrl}
      res.end()

  gotoHangout: (req, res) =>
    projectId = req.params['projectId']
    project = Project.findById projectId, 'hangoutUrl', (err, project) =>
      hangoutUrl = project?.hangoutUrl
      if hangoutUrl
        url = hangoutUrl + "?gid=" + Settings.hangoutAppId
      else
        apogeeUrl = "#{Settings.apogeeUrl}/edit/#{dementor.projectId}"
        url = Settings.hangoutUrlPrefix + "?gid=" + Settings.hangoutAppId + "&gd=" + apogeeUrl
      res.redirect url




module.exports = HangoutController
