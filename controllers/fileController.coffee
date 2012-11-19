{ServiceKeeper} = require '../ServiceKeeper'
{SocketConnection} = require '../connectors/SocketConnection'
{DementorChannel} = require '../connectors/DementorChannel'
{Settings} = require '../Settings'

sendErrorResponse = (res, err) ->
  #console.log "Sending error ", err
  resObject = {error:err.message}
  res.send JSON.stringify(resObject)

#TODO: Check for permissions
#XXX: I worry about a mismatch between fileID/contents, and path.
#What happens when a file is moved, so the path and the fileId don't match up?
exports.getFile = (req, res) ->
  fileId = req.params['fileId']
  mongoConnector = ServiceKeeper.mongoInstance()
  mongoConnector.getFile fileId, (err, file) ->
    if err
      sendErrorResponse(res, err)
    else
      SocketConnection.tell projectId, DementorChannel.fileRequestMessage fileId, (err, data) ->
        if err
          sendErrorResponse(res, err)
        else
          res.send JSON.stringify({projectId: projectId, fileId:fileId, body:data.body})

