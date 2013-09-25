{Project, File, wrapDbError} = require './models'
#Use old errors for this; we've frozen them in src/errors.coffee
{errors, errorType} = require './errors'
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

  createProject: (req, res) =>
    #These hooks are obsoleted
    @sendErrorResponse(res, errors.new errorType.OUT_OF_DATE); return

  refreshProject: (req, res) =>
    #These hooks are obsoleted
    @sendErrorResponse(res, errors.new errorType.OUT_OF_DATE); return

module.exports = DementorController
