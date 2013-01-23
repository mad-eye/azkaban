{Settings} = require 'madeye-common'

sendErrorResponse = (res, err) ->
  console.log "Sending error ", err
  res.json 500, {error:err}

class DementorController
  constructor: () ->
    {DataCenter} = require('../src/dataCenter')
    @dataCenter = new DataCenter

  createProject: (req, res) =>
    proj = {projectId:req.params['projectId'], projectName:req.params['projectName']}
    @dataCenter.createProject proj, req.body['files'], (err, results) ->
      if err then sendErrorResponse(res, err); return
      results.id = id = results.project._id
      results.url = "http://#{Settings.apogeeHost}:#{Settings.apogeePort}/project/#{id}"
      res.json results

  refreshProject: (req, res) =>
    proj = {projectId:req.params['projectId'], projectName:req.body['projectName']}
    @dataCenter.refreshProject proj, req.body['files'], (err, results) ->
      if err then sendErrorResponse(res, err); return
      results.id = id = results.project._id
      results.url = "http://#{Settings.apogeeHost}:#{Settings.apogeePort}/project/#{id}"
      res.json results
      

module.exports = DementorController
