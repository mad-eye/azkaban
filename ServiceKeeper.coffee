_ = require 'underscore'
mongo = require 'mongodb'
#TODO: Should have app set ServiceKeeper's services?
class ServiceKeeper
  _instance = undefined

  @instance: ->
    _instance ?= new ServiceKeeperInner

  @reset: ->
    #console.log "Resetting ServiceKeeper"
    _instance = undefined

#XXX: Right now we have a require loop which causes issues.
class ServiceKeeperInner
  constructor: ->
    #console.log "Making new ServiceKeeperInner"

  getDementorChannel: ->
    #Need to do this here, because if we do it above, we require DementorChannel before it's been loaded.
    {DementorChannel} = require './src/dementorChannel'
    @dementorChannel ?= new DementorChannel

exports.ServiceKeeper = ServiceKeeper
