mongoose = require 'mongoose'
async = require 'async'
{logger, apogeeLogger, wrapDbError} = require './logger'


metricSchema = mongoose.Schema
  level: {type:String, required: true}
  message: {type:String, required: true}
  projectId: String
  fileId: String
  filePath: String
  isHangout: Boolean
  timestamp: {type: Date, default: Date.now}
  error: mongoose.Schema.Types.Mixed

#From apogee
Metric = mongoose.model 'Metric', metricSchema, 'metrics'

#Need to clean to prevent mongoose from getting confused
cleanDoc = (doc) ->
  newdoc = {}
  for key in ['projectId', 'fileId', 'filePath', 'isHangout', 'timestamp', 'error']
    newdoc[key] = doc[key] if doc[key]?
  return newdoc

class ApogeeLogProcessor
  constructor: (interval=1000) ->
    @handle = setInterval =>
      @findAndLog()
    , interval

  destroy: (callback) ->
    clearInterval @handle
    @handle = null
    callback?()

  findAndLog: ->
    #Read metrics and process them.
    Metric.findOneAndRemove {}, (err, doc) =>
      if err
        logger.error 'Error processing Apogee logs', wrapDbError err
        return
      if doc
        #Recurse all the way down.  Send the next request before we process things
        @findAndLog()
        level = doc.level; delete doc.level
        message = doc.message; delete doc.message
        apogeeLogger.log level, message, cleanDoc doc

module.exports = ApogeeLogProcessor
