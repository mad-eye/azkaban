app = require './app'
{MongoConnector} = require './connectors/MongoConnector'

#Set the connection ivars to override the defaults.
#The defaults are appropriate for the live setting;
#override for testing or development.
ServiceKeeper =
  mongoConnector: null

  mongoInstance: ->
    @mongoConnector ?= MongoConnector.instance(app.get("mongo.hostname"), app.get("mongo.port"))
    return @mongoConnector


exports.ServiceKeeper = ServiceKeeper
