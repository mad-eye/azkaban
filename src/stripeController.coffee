{EventEmitter} = require 'events'
  

class StripeController extends EventEmitter
  constructor: ->

  receiveWebhook: (req, res) ->
    @emit 'info', "Stripe event:", req.body
    res.end()

module.exports = StripeController
