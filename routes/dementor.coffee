app = require '../app'
request = require 'request'
mongo = require 'mongodb'


exports.init = (req, res) ->
  #TODO: Connect to mongo to create project
  #options = {
    #url : "http://" + app.get("mongo.hostname"),
  #}
  #Mongo returns the id
  id = '1234XYZ'
  url = 'http://' + app.get('apogee.hostname') + '/project/' + id
  #console.log "Responding with url", url
  res.send """
  {
    "url" : "#{url}"
  }"""
