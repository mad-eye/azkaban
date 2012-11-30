{ServiceKeeper} = require '../ServiceKeeper'
{Settings} = require 'madeye-common'
{messageMaker} = require 'madeye-common'
request = require "request"

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
      url = "http://#{Settings.bolideHost}:#{Settings.bolidePort}/doc/#{fileId}"
      #TODO handle error cases, test, abstract this into a class that can be mocked
      request.put url, {body: '{"type": "text"}'}, (error, response, body)->
        res.send JSON.stringify({projectId: projectId, fileId:fileId, body:message.data.body})

exports.saveFile = (req, res) ->
  res.header 'Access-Control-Allow-Origin', '*'
  fileId = req.params['fileId']
  projectId = req.params['projectId']
  socketServer = ServiceKeeper.getSocketServer()
  url = "http://#{Settings.bolideHost}:#{Settings.bolidePort}/doc/#{fileId}"
  message = messageMaker.saveFileMessage {fileId: body}
  socketServer.tell projectId, message, (err, message) ->
    if err
      sendErrorResponse(res, err)
    else
      url = "http://#{Settings.bolideHost}:#{Settings.bolidePort}/doc/#{fileId}"
      #TODO handle error cases, test, abstract this into a class that can be mocked
      request.put url, {body: '{"type": "text"}'}, (error, response, body)->
        res.send JSON.stringify({projectId: projectId, fileId:fileId, body:message.data.body})