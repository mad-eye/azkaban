{ServiceKeeper} = require '../ServiceKeeper'
{Settings} = require 'madeye-common'

sendErrorResponse = (res, err) ->
  console.log "Sending error ", err
  resObject = {error:err}
  res.send JSON.stringify(resObject)

exports.init = (req, res, app) ->
  mongoConnector = ServiceKeeper.mongoInstance()
  mongoConnector.createProject req.params['projectName'], (err, projects) ->
    if err
      sendErrorResponse(res, err)
    else
      id = projects[0]._id
      url = "http://#{Settings.apogeeHost}:#{Settings.apogeePort}/project/#{id}"
      res.send JSON.stringify
        url: url
        id: id
        name: projects[0].name

exports.refresh = (req, res, app) ->
  mongoConnector = ServiceKeeper.mongoInstance()
  mongoConnector.refreshProject req.params['projectId'], (err, project) ->
    if err
      sendErrorResponse(res, err)
    else
      id = project._id
      url = "http://#{Settings.apogeeHost}:#{Settings.apogeePort}/project/#{id}"
      res.send JSON.stringify
        url: url
        id: id
        name: project.name
