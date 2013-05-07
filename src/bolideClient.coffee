{Settings} = require("madeye-common")
request = require "request"
sharejs = require('share').client
{logger} = require './logger'
{errors, errorType} = require 'madeye-common'

wrapShareError = (err) ->
  return err unless err?
  return err if err.madeye
  errors.new errorType.SHAREJS_ERROR, cause:err

class BolideClient
  constructor: ->

  #callback: (error) ->
  setDocumentContents: (docId, contents, reset=false, callback) ->
    if 'function' == typeof reset
      callback = reset
      reset = false
    sharejs.open docId, 'text2', "#{Settings.bolideUrl}/channel", (error, doc) ->
      return callback wrapShareError error if error
      if doc.version > 0 and !reset
        return callback errors.new errorType.INITIALIZED_FILE_NOT_EMPTY
      if doc.getText()?.length > 0
        doc.del 0, doc.getText().length, (error, appliedOp)->
          logger.error "Error delete document contents.", wrapShareError error if error
      doc.insert 0, contents, (error, appliedOp)->
        callback wrapShareError error

module.exports = BolideClient
