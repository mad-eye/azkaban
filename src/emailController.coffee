async = require 'async'
_ = require 'underscore'
{NewsletterEmail, wrapDbError} = require './models'

log = new Logger 'emailController'

class EmailController
  constructor: ->

  sendErrorResponse: (res, err) ->
    log.warn err.message, err
    res.json 500, {error:err}

  submitEmail: (req, res) ->
    res.header 'Access-Control-Allow-Origin', '*'
    email = req.body.email
    NewsletterEmail.create {email}, (err) ->
      if err
        @sendErrorResponse(res, err)
      else
        res.json {email}

module.exports = EmailController
