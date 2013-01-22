messageMaker = require("madeye-common").messageMaker

class FileController
  constructor: ->
    @dementorChannel = require('../ServiceKeeper').ServiceKeeper.instance().getDementorChannel()
    @Settings = require('madeye-common').Settings
    @request = require "request"

  sendErrorResponse: (res, err) ->
    console.log "Sending error ", err
    resObject = {error:err}
    res.statusCode = 500
    res.send JSON.stringify(resObject)

  #TODO: Check for permissions
  getFile: (req, res) =>
    res.header 'Access-Control-Allow-Origin', '*'
    fileId = req.params['fileId']
    projectId = req.params['projectId']
    @dementorChannel.getFileContents projectId, fileId, (err, contents) =>
      if err
        @sendErrorResponse(res, err)
      else
        url = "http://#{@Settings.bolideHost}:#{@Settings.bolidePort}/doc/#{fileId}"
        #TODO handle error cases, test, abstract this into a class that can be mocked
        @request.put url, {body: '{"type": "text"}'}, (error, response, body)->
          res.send JSON.stringify projectId: projectId, fileId:fileId, body:contents

  saveFile : (req, res) ->
    res.header 'Access-Control-Allow-Origin', '*'
    fileId = req.params['fileId']
    projectId = req.params['projectId']
    contents = req.body.contents
    @dementorChannel.saveFile projectId, fileId, contents, (err) =>
      if err
        @sendErrorResponse(res, err)
      else
        res.send JSON.stringify {projectId: projectId, fileId:fileId, saved:true}

module.exports = FileController
