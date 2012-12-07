assert = require 'assert'
uuid = require 'node-uuid'
{MockSocket, SocketServer, messageMaker} = require 'madeye-common'
{DementorChannel} = require '../../src/dementorChannel'

#
# Messages are of the form:
# {
#   action: eg addFiles, removeFiles, etc
#   id: uuid of message
#   timestamp: Date timestamp of sending
#   data: JSON object, case specific data
# }
describe "DementorChannel", ->
  describe "on receiving message", ->
    it "should add data", () ->
      sentMessages = []
      socket = new MockSocket(
        onsend: (message) ->
          sentMessages.push message
      )
      message = messageMaker.addFilesMessage [
        {path:'foo/bar/file1', isDir:false },
        {path:'foo/bar/dir1', isDir:true },
        {path:'foo/bar/dir1/file2', isDir:false }
      ]

      message.projectId = uuid.v4()
      dementorConnection = new SocketServer(new DementorChannel())
      dementorConnection.connect socket
      socket.receive message




          


