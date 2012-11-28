{ServiceKeeper} = require '../ServiceKeeper'
{Settings} = require 'madeye-common'
{messageMaker} = require 'madeye-common'

sendErrorResponse = (res, err) ->
  #console.log "Sending error ", err
  resObject = {error:err.message}
  res.send JSON.stringify(resObject)

#TODO: Check for permissions
exports.getFile = (req, res) ->
  res.header 'Access-Control-Allow-Origin', '*'
  fileId = req.params['fileId']
  projectId = req.params['projectId']
  socketServer = ServiceKeeper.getSocketServer()
  message = messageMaker.requestFileMessage fileId
  socketServer.tell projectId, message, (err, message) ->
    if err
      sendErrorResponse(res, err)
    else
      console.log "Sending response for body", message.data.body
      res.send JSON.stringify({projectId: projectId, fileId:fileId, body:message.data.body})
