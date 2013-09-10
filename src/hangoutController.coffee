{Project, ProjectStatus, wrapDbError} = require './models'
{EventEmitter} = require 'events'
{Settings} = require 'madeye-common'
{errors, errorType} = require 'madeye-common'

sendErrorResponse = (res, err) ->
  err = wrapDbError err
  @emit 'warn', err.message, err
  res.json 500, {error:err}

class HangoutController extends EventEmitter
  constructor: () ->

  registerHangout: (req, res) =>
    projectId = req.params['projectId']
    hangoutUrl = req.body['hangoutUrl']
    Project.update {_id:projectId}, {hangoutUrl}, (err, count) =>
      if err then sendErrorResponse(res, err); return
      @emit 'debug', "Hangout registered", {projectId, hangoutUrl}
      res.end()

  gotoHangout: (req, res) =>
    projectId = req.params['projectId']
    Project.findById projectId, 'hangoutUrl', (err, project) =>
      hangoutUrl = project?.hangoutUrl
      activeHangoutUrl = hangoutUrl + "?gid=" + Settings.hangoutAppId

      apogeeUrl = "#{Settings.apogeeUrl}/edit/#{projectId}"
      inactiveHangoutUrl = Settings.hangoutPrefix + "?gid=" + Settings.hangoutAppId + "&gd=" + apogeeUrl
      unless hangoutUrl
        console.log "Redirecting to", inactiveHangoutUrl
        res.redirect inactiveHangoutUrl
      else
        #Is this still active?  Check for projectStatuses
        ProjectStatus.find {projectId, isHangout:true}, (err, results) =>
          @emit 'warn', "Error checking project status", error: wrapDbError err if err
          if err or !results or results.length == 0
            @emit 'trace', "Redirecting to", inactiveHangoutUrl
            res.redirect inactiveHangoutUrl
          else
            @emit 'trace', "Redirecting to", activeHangoutUrl
            res.redirect activeHangoutUrl




module.exports = HangoutController
