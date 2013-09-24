{Project, File, wrapDbError} = require './models'
{errors, errorType} = require 'madeye-common'
semver = require 'semver'
FileSyncer = require './fileSyncer'
async = require 'async'
{EventEmitter} = require 'events'

class DementorController extends EventEmitter
  constructor: () ->
    @minDementorVersion = '0.2.0'
    @minNodeVersion = '0.8.18'

  sendErrorResponse: (res, err) ->
    err = wrapDbError err
    @emit 'warn', err.message, err
    res.json 500, {error:err}

  checkVersion: (dementorVersion) ->
    return dementorVersion? && semver.gte dementorVersion, @minDementorVersion

  nodeVersionWarning: (nodeVersion) ->
    unless nodeVersion? && semver.gte nodeVersion, @minNodeVersion
      return "Your NodeJs is less than required (#{@minNodeVersion}).  Please upgrade to avoid any funny business."
    return null

  createProject: (req, res) =>
    @emit 'trace', 'Create request body:', req.body
    unless @checkVersion req.body['version']
      @sendErrorResponse(res, errors.new errorType.OUT_OF_DATE); return
    warning = @nodeVersionWarning(req.body['nodeVersion'])

    fields =
      name: req.body['projectName']
      tunnels: req.body['tunnels']
      lastOpened: Date.now()
    if req.params?['projectId']
      #sometimes the project has been deleted; just recreate
      fields._id = req.params['projectId']
    Project.create fields, (err, proj) =>
      if err then @sendErrorResponse(res, err); return
      @emit 'debug', "Project created", {projectId:proj._id}
      @azkaban.fileSyncer.addScratchFile proj._id, (err, scratchFile) ->
        @emit 'warn', "Error adding scratchFile", projectId:proj._id, error:err if err
      @azkaban.fileSyncer.syncFiles req.body['files'], proj._id, (err, files) =>
        if err then @sendErrorResponse(res, err); return
        res.json project:proj, files: files, warning: warning

  refreshProject: (req, res) =>
    unless @checkVersion req.body['version']
      @sendErrorResponse(res, errors.new errorType.OUT_OF_DATE); return
    warning = @nodeVersionWarning(req.body['nodeVersion'])
    projectId = req.params['projectId']
    @emit 'trace', 'Refresh request body:', req.body
    
    Project.findById projectId, (err, proj) =>
      if err then @sendErrorResponse(res, err); return
      unless proj
        #sometimes the project has been deleted; just recreate
        @createProject req, res
        return
      proj.closed = false
      proj.tunnels = req.body['tunnels']
      proj.lastOpened = Date.now()
      proj.name = req.body['projectName']
      proj.save (err, proj) =>
        if err then @sendErrorResponse(res, err); return
        @azkaban.ddpClient.invokeMethod 'markDirty', ['projects', proj._id]
        @emit 'debug', "Project refreshed", {projectId:proj._id}
        deleteMissing = true
        @azkaban.fileSyncer.syncFiles req.body['files'], proj._id, deleteMissing, (err, files) =>
          if err then @sendErrorResponse(res, err); return
          res.json project:proj, files: files, warning: warning
          
#TODO tests around cleanup when project is stopped

module.exports = DementorController
