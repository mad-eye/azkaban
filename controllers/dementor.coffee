{ServiceKeeper} = require '../ServiceKeeper'
{Settings} = require '../Settings'

sendErrorResponse = (res, err) ->
  #console.log "Sending error ", err
  resObject = {error:err.message}
  res.send JSON.stringify(resObject)

exports.init = (req, res, app) ->
  mongoConnector = ServiceKeeper.mongoInstance()
  mongoConnector.createProject (err, projects) ->
    if err
      sendErrorResponse(res, err)
    else
      id = projects[0]._id
      url = "http://#{Settings.apogeeHost}:#{Settings.apogeePort}/project/#{id}"
      res.send JSON.stringify({url:url, id:id})
