_ = require 'underscore'
mongo = require 'mongodb'
{Settings} = require 'madeye-common'
{MongoConnector} = require './src/mongoConnector'
{SocketServer} = require 'madeye-common'
{MockDb} = require './tests/mock/MockMongo'

#TODO: Put this in settings?
DB_NAME = 'meteor'

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

  makeDbConnection: ->
    #console.log "Settings.mockDb", Settings.mockDb
    if Settings.mockDb
      Db = @Db ? new MockDb
      #console.log "Returning mockDb", Db
      return Db
    server = new mongo.Server(Settings.mongoHost, Settings.mongoPort, {auto_reconnect: true})
    return Db = new mongo.Db(DB_NAME, server, {safe:true})

  getSocketServer: ->
    #Need to do this here, because if we do it above, we require DementorChannel before it's been loaded.
    unless @socketServer
      #console.log "Constructing new socketServer"
      {DementorChannel} = require './src/dementorChannel'
      @socketServer = new SocketServer(new DementorChannel())
    return @socketServer

exports.ServiceKeeper = ServiceKeeper
