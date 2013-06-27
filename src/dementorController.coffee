{Project, File, wrapDbError} = require './models'
{errors, errorType} = require 'madeye-common'
{logger} = require './logger'
semver = require 'semver'
FileSyncer = require './fileSyncer'
redisClient = require("redis").createClient()

sendErrorResponse = (res, err) ->
  err = wrapDbError err
  logger.error err.message, err
  res.json 500, {error:err}

class DementorController
  constructor: () ->
    @minDementorVersion = '0.1.0'
    @minNodeVersion = '0.8.21'
    @initRedisPortsCollections()

  checkVersion: (dementorVersion) ->
    return dementorVersion? && semver.gte dementorVersion, @minDementorVersion

  nodeVersionWarning: (nodeVersion) ->
    unless nodeVersion? && semver.gte nodeVersion, @minNodeVersion
      return "Your NodeJs is less than required (#{@minNodeVersion}).  Please upgrade to avoid any funny business."
    return null

  firefoxPerformanceWarning = "Firefox is currently experiencing performance issues with MadEye in Hangouts.\n" +
    "For Hangout mode, please use Chrome or Safari for the best performance."

  createProject: (req, res) =>
    unless @checkVersion req.body['version']
      sendErrorResponse(res, errors.new errorType.OUT_OF_DATE); return
    warning = @nodeVersionWarning(req.body['nodeVersion']) ? firefoxPerformanceWarning

    tunnel = req.body['tunnel']
    writeProject = (port)=>
      Project.create {name: req.body['projectName'], tunnel, port}, (err, proj) =>
        if err then sendErrorResponse(res, err); return
        logger.debug "Project created", {projectId:proj._id}
        @azkaban.fileSyncer.addScratchFile proj._id, (err, scratchFile) ->
          logger.error "Error adding scratchFile", projectId:proj._id, error:err if err
        @azkaban.fileSyncer.syncFiles req.body['files'], proj._id, (err, files) ->
          if err then sendErrorResponse(res, err); return
          res.json project:proj, files: files, warning: warning

    if tunnel
      @findOpenPort (port)->
        writeProject(port)
    else
      writeProject()

  refreshProject: (req, res) =>
    unless @checkVersion req.body['version']
      sendErrorResponse(res, errors.new errorType.OUT_OF_DATE); return
    warning = @nodeVersionWarning(req.body['nodeVersion']) ? firefoxPerformanceWarning
    tunnel = req.body.tunnel

    updateProject = (port)=>
      projectId = req.params['projectId']
      project =
        name: req.body['projectName']
        closed: false
        tunnel: tunnel
      project.port = port if port
      Project.findOneAndUpdate {_id:projectId}, project, {new:true, upsert:true}, (err, proj) =>
        if err then sendErrorResponse(res, err); return
        @azkaban.ddpClient.invokeMethod 'markDirty', ['projects', projectId]
        logger.debug "Project refreshed", {projectId:proj._id}
        deleteMissing = true
        @azkaban.fileSyncer.syncFiles req.body['files'], proj._id, deleteMissing, (err, files) ->
          if err then sendErrorResponse(res, err); return
          res.json project:proj, files: files, warning: warning

    if tunnel
      @findOpenPort (port)->
        updateProject(port)
    else
      updateProject()

  findOpenPort: (callback)=>
    redisClient.srandmember "availablePorts", 1, (err, availablePorts)->
      port = availablePorts[0]
      redisClient.smove "availablePorts", "unavailablePorts", port, (err, results)->
        callback(port)

#initialize if this is the first time running
#(both availablePorts and unavailablePorts = 0

  initRedisPortsCollections: ->
    redisClient.smembers "availablePorts", (err, results)->
      if results.length == 0
        redisClient.smembers "unavailablePorts", (err, results)->
          if results.length == 0
            redisClient.sadd "availablePorts", [7000..8000]

module.exports = DementorController
