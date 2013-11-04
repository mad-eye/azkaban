_ = require 'underscore'
hat = require 'hat'
{assert} = require 'chai'
StripeController = require '../../src/stripeController'
{StripeEvent} = require '../../src/models'
{MockResponse} = require 'madeye-common'

randomString = -> hat 32, 16

randomEvent = (info) ->
  event =
    id: randomString()
    created: Date.now()
    livemode: false
    type: 'invoice.created'
    data:
      object:
        id: randomString()
    object: 'event'
    pending_webhooks: 1
    request: randomString()
  return _.extend event, info

describe 'StripeController', ->
  stripeController = new StripeController
  res = null
  beforeEach ->
    res = new MockResponse

  it 'should respond with a 200', (done) ->
    event = randomEvent()
    req = body: event
    res.onEnd = ->
      assert.equal res.statusCode, 200
      done()
    stripeController.receiveWebhook req, res

  it 'should write to db when livemode == true', (done) ->
    event = randomEvent livemode:true
    req = body: event
    res.onEnd = ->
      assert.equal res.statusCode, 200
      StripeEvent.findOne id:event.id, (err, savedEvent) ->
        assert.ok !err, "There should be no error"
        assert.ok savedEvent, "There should be an event written to db."
        assert.equal savedEvent.id, event.id
        assert.equal savedEvent.type, event.type
        done()
    stripeController.receiveWebhook req, res


  it 'should not write to db when livemode == false', (done) ->
    event = randomEvent livemode:false
    req = body: event
    res.onEnd = ->
      assert.equal res.statusCode, 200
      StripeEvent.findOne id:event.id, (err, savedEvent) ->
        assert.ok !err, "There should be no error"
        assert.ok !savedEvent, "There should be no event written to db."
        done()
    stripeController.receiveWebhook req, res

