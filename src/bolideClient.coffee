{Settings} = require("madeye-common")
request = require "request"
sharejs = require('share').client
{EventEmitter} = require 'events'
{errors, errorType} = require 'madeye-common'

wrapShareError = (err) ->
  return err unless err?
  return err if err.madeye
  errors.new errorType.SHAREJS_ERROR, cause:err

class BolideClient extends EventEmitter
  constructor: ->
    @emit 'trace', "Constructing BolideClient"

  #callback: (error) ->
  setDocumentContents: (docId, contents, reset=false, callback) ->
    if 'function' == typeof reset
      callback = reset
      reset = false
    @emit 'trace', "setDocumentContents #{docId}"
    #TODO replace hard coded localhost or remove impress.js functionality
    sharejs.open docId, 'text2', "http://localhost:3003/channel", (error, doc) ->
      return callback wrapShareError error if error
      if doc.version > 0 and !reset
        return callback errors.new errorType.INITIALIZED_FILE_NOT_EMPTY
      try #ShareJS throws errors, very frustrating
        if doc.getText()?.length > 0
          doc.del 0, doc.getText().length, (error, appliedOp)->
            #XXX: Should return this error?
            @emit 'warn', "Error delete document contents.", wrapShareError error if error
        doc.insert 0, contents, (error, appliedOp)->
          callback wrapShareError error
      catch error
        callback wrapShareError error

module.exports = BolideClient
