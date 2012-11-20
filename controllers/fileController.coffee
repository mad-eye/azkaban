{ServiceKeeper} = require '../ServiceKeeper'
{SocketConnection} = require '../connectors/SocketConnection'
{Settings} = require 'madeye-common'
{DementorChannel} = require '../channels/DementorChannel'

sendErrorResponse = (res, err) ->
  #console.log "Sending error ", err
  resObject = {error:err.message}
  res.send JSON.stringify(resObject)

#TODO: Check for permissions
exports.getFile = (req, res) ->
  fileId = req.params['fileId']
  projectId = req.params['projectId']
  socketServer = ServiceKeeper.getSocketServer()
  socketServer.tell projectId, DementorChannel.fileRequestMessage(fileId), (err, message) ->
    if err
      sendErrorResponse(res, err)
    else
      #console.log "Sending response for body", message.data.body
      res.send JSON.stringify({projectId: projectId, fileId:fileId, body:message.data.body})

