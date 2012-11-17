assert = require 'assert'
uuid = require 'node-uuid'
{SocketConnection} = require '../../connectors/SocketConnection'
{MockSocket} = require '../mock/MockSocket'

describe 'SocketConnection', ->
  describe 'confirmationMessage', ->
    origMessage = confMessage = null
    before ->
      socketConnection = new SocketConnection()
      origMessage = {
        uuid : uuid.v4(),
      }
      confMessage = socketConnection.confirmationMessage origMessage
    it 'should not be null', ->
      assert.ok confMessage
    it 'should have action "confirm"', ->
      assert.equal confMessage.action, 'confirm'
    it 'should have receivedId equal to send messages id', ->
      assert.equal confMessage.receivedId, origMessage.uuid

  describe 'attachSocket', ->
    socketConnection = socket = projectId = null
    before ->
      socketConnection = new SocketConnection()
      projectId = uuid.v4()
      socket = new MockSocket()
      socketConnection.attachSocket socket, projectId
    it 'should store sockets by both socket.id and projectId', ->
      assert.equal socket, socketConnection.liveSockets[projectId]
    it 'should be cleaned out by @detachSocket', ->
      socketConnection.detachSocket socket
      assert.equal socketConnection.liveSockets[projectId], null

  describe 'handshake', ->
    socketConnection = socket = message = null
    before ->
      message =
        uuid : uuid.v4()
        projectId : uuid.v4()
        action : 'handshake'

      socketConnection = new SocketConnection()
      socket = new MockSocket()
      socketConnection.connect socket
      socket.receive message
    it 'should store socket via projectId', ->
      assert.equal socket, socketConnection.liveSockets[message.projectId]
