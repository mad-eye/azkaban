{EventEmitter} = require 'events'
nodemailer = require "nodemailer"

class MailService extends EventEmitter
  constructor: (options) ->
    # create reusable transport method (opens pool of SMTP connections)
    @smtpTransport = nodemailer.createTransport "SMTP",
      service: "Gmail",
      auth:
        user: options.emailAddress
        pass: options.emailPassword

  #mailOptions:
  #  from: "Fred Foo <foo@blurdybloop.com>",
  #  to: "bar@blurdybloop.com, baz@blurdybloop.com",
  #  subject: "Hello",
  #  text: "Hello world",
  #  html: "<b>Hello world</b>"
  sendMail: (mailOptions) ->
    # send mail with defined transport object
    @smtpTransport.sendMail mailOptions, (error, response) =>
      if error
        @emit 'warn', "Email #{mailOptions.subject} send failed:", error
      else
        @emit 'debug', "Email #{mailOptions.subject} sent."

module.exports = MailService
