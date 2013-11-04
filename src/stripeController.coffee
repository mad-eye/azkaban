{EventEmitter} = require 'events'
{StripeEvent} = require './models'

class StripeController extends EventEmitter
  constructor: ->

  sendErrorResponse: (res, err) ->
    @emit 'warn', err.message, err
    res.json 500, {error:err}

  receiveWebhook: (req, res) ->
    event = req.body
    @emit 'info', "Stripe event:", event
    unless event.livemode
      res.end()
    else
      #record it in db, alert someone?
      StripeEvent.create event, (err, savedEvent) ->
        if err
          return @sendErrorResponse(res, err)
        else
          res.end()

module.exports = StripeController
