flow = require 'flow'
{DataCenter} = require '../src/dataCenter'
{Settings} = require 'madeye-common'

sendErrorResponse = (res, err) ->
  console.log "Sending error ", err
  res.json 500, {error:err}

exports.init = (req, res, app) ->
  dataCenter = new DataCenter
  dataCenter.createProject req.params['projectName'], req.body['files'], (err, results) ->
    if err then sendErrorResponse(res, err); return
    results.id = id = results.project._id
    results.url = "http://#{Settings.apogeeHost}:#{Settings.apogeePort}/project/#{id}"
    res.json results

exports.refresh = (req, res, app) ->
  dataCenter = new DataCenter
  dataCenter.refreshProject req.params['projectId'], req.body['files'], (err, results) ->
    if err then sendErrorResponse(res, err); return
    results.id = id = results.project._id
    results.url = "http://#{Settings.apogeeHost}:#{Settings.apogeePort}/project/#{id}"
    res.json results
