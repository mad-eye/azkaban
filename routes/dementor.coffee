app = require '../app'
request = require 'request'
{ServiceKeeper} = require '../ServiceKeeper'
console.log "Found ServiceKeeper", ServiceKeeper

sendErrorResponse = (res, err) ->
  console.log "Sending error ", err
  resObject = {error:err.message}
  res.send JSON.stringify(resObject)

exports.init = (req, res) ->
  userId = req.params.userId
  mongo = ServiceKeeper.mongoInstance()
  #console.log "Found MongoConnector", mongo
  mongo.createProject (err, projects) ->
    if err
      sendErrorResponse(res, err)
    else
      console.log "Found project", projects
      id = projects[0]._id
      url = 'http://' + app.get('apogee.hostname') + '/project/' + id
      res.send JSON.stringify({url:url, id:id})
