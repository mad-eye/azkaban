{Project, wrapDbError} = require './models'
{Settings} = require 'madeye-common'
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
    console.log "Registering hangout with projId #{projectId} and hangoutUrl #{hangoutUrl}"
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
        apogeeUrl = "#{Settings.apogeeUrl}/edit/#{projectId}"
        url = Settings.hangoutPrefix + "?gid=" + Settings.hangoutAppId + "&gd=" + apogeeUrl
      console.log "Redirecting to", url
      res.redirect url




module.exports = HangoutController
