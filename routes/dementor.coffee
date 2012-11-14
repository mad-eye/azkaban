app = require '../app'
request = require 'request'
{MongoConnector} = require '../connectors/MongoConnector'

sendErrorResponse = (res, err) ->
  console.log "Sending error ", err
  resObject = {error:err.message}
  res.send JSON.stringify(resObject)

exports.init = (req, res) ->
  userId = req.params.userId
  mongo = MongoConnector.instance(app.get("mongo.hostname"), app.get("mongo.port"))
  #console.log "Found MongoConnector", mongo
  mongo.createProject (err, projects) ->
    if err
      sendErrorResponse(res, err)
    else
      console.log "Found project", projects
      id = projects[0]._id
      url = 'http://' + app.get('apogee.hostname') + '/project/' + id
      res.send JSON.stringify({url:url, id:id})
