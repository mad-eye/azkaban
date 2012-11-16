{Settings} = require "./Settings"
{MongoConnector} = require './connectors/MongoConnector'

#Set the connection ivars to override the defaults.
#The defaults are appropriate for the live setting;
#override for testing or development.
ServiceKeeper =
  mongoConnector: null

  mongoInstance: ->
    @mongoConnector ?= MongoConnector.instance(Settings.mongoHost, Settings.mongoPort)
    return @mongoConnector


exports.ServiceKeeper = ServiceKeeper
