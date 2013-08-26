{Project, File, wrapDbError} = require './models'
{errors, errorType} = require 'madeye-common'
{logger} = require './logger'
semver = require 'semver'
FileSyncer = require './fileSyncer'
redisClient = require("redis").createClient()
async = require 'async'

sendErrorResponse = (res, err) ->
  err = wrapDbError err
  logger.error err.message, err
  res.json 500, {error:err}

class DementorController
  constructor: () ->
    @minDementorVersion = '0.1.8'
    @minNodeVersion = '0.8.18'
    @initRedisPortsCollections()

  checkVersion: (dementorVersion) ->
    return dementorVersion? && semver.gte dementorVersion, @minDementorVersion

  nodeVersionWarning: (nodeVersion) ->
    unless nodeVersion? && semver.gte nodeVersion, @minNodeVersion
      return "Your NodeJs is less than required (#{@minNodeVersion}).  Please upgrade to avoid any funny business."
    return null

  createProject: (req, res) =>
    unless @checkVersion req.body['version']
      sendErrorResponse(res, errors.new errorType.OUT_OF_DATE); return
    warning = @nodeVersionWarning(req.body['nodeVersion'])

    tunnels = req.body['tunnels']
    writeProject = (tunnels)=>
      fields = {name: req.body['projectName'], tunnels}
      if req.params?['projectId']
        #sometimes the project has been deleted; just recreate
        fields._id = req.params['projectId']
      Project.create fields, (err, proj) =>
        if err then sendErrorResponse(res, err); return
        logger.debug "Project created", {projectId:proj._id}
        @azkaban.fileSyncer.addScratchFile proj._id, (err, scratchFile) ->
          logger.error "Error adding scratchFile", projectId:proj._id, error:err if err
        @azkaban.fileSyncer.syncFiles req.body['files'], proj._id, (err, files) ->
          if err then sendErrorResponse(res, err); return
          res.json project:proj, files: files, warning: warning

    if tunnels
      @claimTunnelPorts tunnels, (err, tunnels)->
        if err then sendErrorResponse(res, err); return
        writeProject(tunnels)
    else
      writeProject()

  refreshProject: (req, res) =>
    unless @checkVersion req.body['version']
      sendErrorResponse(res, errors.new errorType.OUT_OF_DATE); return
    warning = @nodeVersionWarning(req.body['nodeVersion'])
    tunnel = req.body.tunnel
    projectId = req.params['projectId']
    
    saveCallback = (err, proj) =>
      if err then sendErrorResponse(res, err); return
      @azkaban.ddpClient.invokeMethod 'markDirty', ['projects', proj._id]
      logger.debug "Project refreshed", {projectId:proj._id}
      deleteMissing = true
      @azkaban.fileSyncer.syncFiles req.body['files'], proj._id, deleteMissing, (err, files) ->
        if err then sendErrorResponse(res, err); return
        res.json project:proj, files: files, warning: warning

    Project.findById projectId, (err, proj) =>
      if err then sendErrorResponse(res, err); return
      unless proj
        #sometimes the project has been deleted; just recreate
        @createProject req, res
        return
      proj.closed = false
      proj.tunnel = req.body.tunnel
      proj.lastOpened = Date.now()
      if proj.tunnel and not proj.port
        @findOpenPort (port) ->
          proj.port = port
          proj.save saveCallback
      else
        proj.save saveCallback
        

  claimTunnelPorts: (tunnels, callback)=>
    redisClient.srandmember "availablePorts", tunnels.length, (err, availablePorts)->
      return callback(err) if err
      async.map availablePorts, (port, callback)->
        redisClient.smove "availablePorts", "unavailablePorts", port, (err, results)->
          tunnel = tunnels.pop()
          tunnel["remote"] = port
          callback(null, tunnel)
      , callback

#initialize if this is the first time running
#(both availablePorts and unavailablePorts = 0

  initRedisPortsCollections: (reset=false, callback)->
    init = ()->
      redisClient.smembers "availablePorts", (err, results)->
        if results.length == 0
          redisClient.smembers "unavailablePorts", (err, results)->
            if results.length == 0
              redisClient.sadd "availablePorts", [7000..8000], (err, results)->
                callback()

    if reset == true
      redisClient.del "availablePorts", (err, results)->
        redisClient.del "unavailablePorts", (err, results)->
          init()
    else
      init()

#TODO tests around cleanup when project is stopped

module.exports = DementorController
