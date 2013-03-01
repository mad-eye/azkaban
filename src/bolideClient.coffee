{Settings} = require("madeye-common")
request = require "request"
sharejs = require('share').client
{logger} = require './logger'
{errors, errorType} = require 'madeye-common'

class BolideClient
  constructor: ->

  setDocumentContents: (docId, contents, reset=false, callback) ->
    if 'function' == typeof reset
      callback = reset
      reset = false
    sharejs.open docId, 'text2', "#{Settings.bolideUrl}/channel", (error, doc) ->
      return callback error if error
      if doc.version > 0 and !reset
        return callback errors.new errorType.INITIALIZED_FILE_NOT_EMPTY
      if doc.getText().length > 0
        doc.del 0, doc.getText().length, (error, appliedOp)->
          logger.error(error) if error
      doc.insert 0, contents, (error, appliedOp)->
        logger.error(error) if error
      callback()

module.exports = BolideClient
