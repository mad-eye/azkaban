assert = require 'assert'
uuid = require 'node-uuid'
{SocketConnection} = require '../../connectors/SocketConnection'

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

