async = require 'async'
{EventEmitter} = require 'events'
{Project, File, wrapDbError} = require './models'
{crc32} = require("madeye-common")
fs = require "fs"
{Settings} = require 'madeye-common'
_path = require "path"
{ncp} = require "ncp"
ncp.limit = 16
_ = require 'underscore'

class FileController extends EventEmitter
  constructor: (@settings=Settings) ->

  sendErrorResponse: (res, err) ->
    @emit 'warn', err.message, err
    res.json 500, {error:err}

  #TODO: Check for permissions
  getFile: (req, res) ->
    res.header 'Access-Control-Allow-Origin', '*'
    fileId = req.params['fileId']
    projectId = req.params['projectId']
    reset = req.query?['reset'] ? false
    @emit 'trace', "getFile for #{fileId}"
    @azkaban.fileSyncer.loadFile projectId, fileId, reset, (err, checksum) =>
      if err
        @sendErrorResponse(res, err)
      else
        res.json projectId: projectId, fileId:fileId, checksum:checksum


module.exports = FileController
