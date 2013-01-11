_ = require 'underscore'
mongo = require 'mongodb'
{Settings} = require 'madeye-common'
{MongoConnector} = require './src/mongoConnector'
{SocketServer} = require 'madeye-common'
{MockDb} = require './tests/mock/MockMongo'

#TODO: Put this in settings?
DB_NAME = 'meteor'

#TODO: Should have app set ServiceKeeper's services?
class exports.ServiceKeeper
  _instance = undefined
  _vars = undefined

  @init: (vars={}) ->
    _vars = vars

  @instance: ->
    _instance ?= new ServiceKeeperInner

  @reset: ->
    _vars = undefined
    _instance = undefined

#XXX: Right now we have a require loop which causes issues.
class ServiceKeeperInner
  constructor: ->

  makeDbConnection: ->
    #console.log "Settings.mockDb", Settings.mockDb
    if Settings.mockDb
      Db = @Db ? new MockDb
      #console.log "Returning mockDb", Db
      return Db
    server = new mongo.Server(Settings.mongoHost, Settings.mongoPort, {auto_reconnect: true})
    return Db = new mongo.Db(DB_NAME, server, {safe:true})



  #Set the connection ivars to override the defaults.
  #The defaults are appropriate for the live setting;
  #override for testing or development.
  mongoInstance: ->
    @mongoConnector ?= MongoConnector.instance(Settings.mongoHost, Settings.mongoPort)
    return @mongoConnector

  reset: ->
    @mongoConnector = null

  getSocketServer: ->
    #Need to do this here, because if we do it above, we require DementorChannel before it's been loaded.
    {DementorChannel} = require './src/dementorChannel'
    @socketServer ?= new SocketServer(new DementorChannel())
    return @socketServer

