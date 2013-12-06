{Project, ProjectStatus, wrapDbError} = require './models'
{EventEmitter} = require 'events'
{Settings} = require 'madeye-common'
{errors, errorType} = require 'madeye-common'
Logger = require 'pince'

log = new Logger 'hangoutController'

sendErrorResponse = (res, err) ->
  err = wrapDbError err
  log.warn message, err
  res.json 500, {error:err}

class HangoutController extends EventEmitter
  constructor: () ->

  gotoHangout: (req, res) =>
    projectId = req.params['projectId']
    Project.findById projectId, 'hangoutUrl', (err, project) =>
      console.log "Found project", project
      hangoutUrl = project?.hangoutUrl
      activeHangoutUrl = hangoutUrl + "?gid=" + Settings.hangoutAppId
      #if request goes through nginx, then use the host passed in
      if req.headers['x-forwarded-for']
        protocol = req.headers['x-forwarded-protocol'] ? req.protocol
        log.trace 'Found protocol from nginx:', protocol
        apogeeUrl = "#{protocol}://#{req.host}/edit/#{projectId}"
      else
        apogeeUrl = "#{Settings.apogeeUrl}/edit/#{projectId}"
      inactiveHangoutUrl = Settings.hangoutPrefix + "?gid=" + Settings.hangoutAppId + "&gd=" + apogeeUrl
      #Apogee controls the hangoutUrl now
      if hangoutUrl
        log.trace "Redirecting to", activeHangoutUrl
        res.redirect activeHangoutUrl
      else
        log.trace "Redirecting to", inactiveHangoutUrl
        res.redirect inactiveHangoutUrl


module.exports = HangoutController
