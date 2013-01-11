{Settings} = require 'madeye-common'

sendErrorResponse = (res, err) ->
  console.log "Sending error ", err
  res.json 500, {error:err}

class DementorController
  constructor: () ->
    @dataCenter = require '../src/dataCenter'

  createProject: (req, res) =>
    @dataCenter.createProject req.params['projectName'], req.body['files'], (err, results) ->
      if err then sendErrorResponse(res, err); return
      results.id = id = results.project._id
      results.url = "http://#{Settings.apogeeHost}:#{Settings.apogeePort}/project/#{id}"
      res.json results

  refreshProject: (req, res) =>
    @dataCenter.refreshProject req.params['projectId'], req.body['files'], (err, results) ->
      if err then sendErrorResponse(res, err); return
      results.id = id = results.project._id
      results.url = "http://#{Settings.apogeeHost}:#{Settings.apogeePort}/project/#{id}"
      res.json results
      

module.exports = DementorController
