{Settings} = require 'madeye-common'
{MongoConnector} = require './connectors/MongoConnector'
{SocketServer} = require 'madeye-common'

#TODO: Should have app set ServiceKeeper's services?
#Right now we have a require loop which causes issues.
ServiceKeeper =
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
    {DementorChannel} = require './channels/DementorChannel'
    @socketServer ?= new SocketServer(new DementorChannel())
    return @socketServer

exports.ServiceKeeper = ServiceKeeper
