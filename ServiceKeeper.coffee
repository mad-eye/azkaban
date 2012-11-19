{Settings} = require 'madeye-common'
{MongoConnector} = require './connectors/MongoConnector'

#Set the connection ivars to override the defaults.
#The defaults are appropriate for the live setting;
#override for testing or development.
ServiceKeeper =
  mongoInstance: ->
    @mongoConnector ?= MongoConnector.instance(Settings.mongoHost, Settings.mongoPort)
    return @mongoConnector

  reset: ->
    @mongoConnector = null


exports.ServiceKeeper = ServiceKeeper
