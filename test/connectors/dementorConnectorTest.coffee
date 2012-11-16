assert = require 'assert'
uuid = require 'node-uuid'
{MockSocket} = require '../mock/MockSocket'
{SocketConnection, DementorRoutes} = require '../../connectors/SocketConnection'

#
# Messages are of the form:
# {
#   action: eg addFiles, removeFiles, etc
#   id: uuid of message
#   timestamp: Date timestamp of sending
#   data: JSON object, case specific data
# }
describe "SocketConnection", ->
  describe "on receiving message", ->
    it "should add data", () ->
      sentMessages = []
      socket = new MockSocket(
        onsend: (message) ->
          sentMessages.push message
      )
      message =
        id: uuid.v4(),
        timestamp: new Date().getTime(),
        action: 'addFiles',
        projectId: uuid.v4(),
        data:
          files: [
            {path:'foo/bar/file1', isDir:false },
            {path:'foo/bar/dir1', isDir:true },
            {path:'foo/bar/dir1/file2', isDir:false }
          ]

      dementorConnection = new SocketConnection(new DementorRoutes())
      dementorConnection.startup socket
      socket.receive message




          


