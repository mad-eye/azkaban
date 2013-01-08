flow = require 'flow'
{ServiceKeeper} = require '../ServiceKeeper'
{Settings} = require 'madeye-common'

sendErrorResponse = (res, err) ->
  console.log "Sending error ", err
  res.json 500, {error:err}

exports.init = (req, res, app) ->
  mongoConnector = ServiceKeeper.mongoInstance()
  mongoConnector.createProject req.params['projectName'], req.body['files'], (err, results) ->
    if err then sendErrorResponse(res, err); return
    results.id = id = results.project._id
    results.url = "http://#{Settings.apogeeHost}:#{Settings.apogeePort}/project/#{id}"
    res.json results

exports.refresh = (req, res, app) ->
  mongoConnector = ServiceKeeper.mongoInstance()
  flow.exec ->
    mongoConnector.refreshProject req.params['projectId'], req.body['files'], this
  , (err, results) ->
    if err then sendErrorResponse(res, err); return
    results.id = id = results.project._id
    results.url = "http://#{Settings.apogeeHost}:#{Settings.apogeePort}/project/#{id}"
    res.json results
