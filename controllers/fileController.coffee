messageMaker = require("madeye-common").messageMaker

class FileController
  constructor: ->
    @socketServer = require('../ServiceKeeper').ServiceKeeper.getSocketServer()
    @Settings = require('madeye-common').Settings
    @request = require "request"

  sendErrorResponse: (res, err) ->
    #console.log "Sending error ", err
    resObject = {error:err.message}
    res.statusCode = 500
    res.send JSON.stringify(resObject)

  #TODO: Check for permissions
  getFile: (req, res) =>
    res.header 'Access-Control-Allow-Origin', '*'
    fileId = req.params['fileId']
    projectId = req.params['projectId']
    message = messageMaker.requestFileMessage fileId
    @socketServer.tell projectId, message, (err, message) =>
      if err
        @sendErrorResponse(res, err)
      else
        url = "http://#{@Settings.bolideHost}:#{@Settings.bolidePort}/doc/#{fileId}"
        #TODO handle error cases, test, abstract this into a class that can be mocked
        @request.put url, {body: '{"type": "text"}'}, (error, response, body)->
          res.send JSON.stringify({projectId: projectId, fileId:fileId, body:message.data.body})

  saveFile : (req, res) ->
    res.header 'Access-Control-Allow-Origin', '*'
    fileId = req.params['fileId']
    projectId = req.params['projectId']
    body = req.params['body']
    url = "http://#{@Settings.bolideHost}:#{@Settings.bolidePort}/doc/#{fileId}"
    @request.get url, (error, response, body)=>
      message = messageMaker.saveFileMessage fileId, body
      @socketServer.tell projectId, message, (err, message) =>
        if err
          @sendErrorResponse(res, err)
        else
          res.send JSON.stringify {projectId: projectId, fileId:fileId, saved:true}

module.exports = FileController
