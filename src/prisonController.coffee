{EventEmitter} = require 'events'
{exec} = require 'child_process'
_path = require 'path'
hat = require 'hat'
async = require 'async'
{Settings} = require 'madeye-common'
Logger = require 'pince'
child_process = require 'child_process'
exec = child_process.exec
hat = require 'hat'

randomString = -> hat 32, 16
log = new Logger 'prisonController'

class PrisonController extends EventEmitter
  constructor: ->

  sendErrorResponse: (res, err) ->
    log.warn err.message, err
    res.json 500, {error:err}

  registerPrisonKey: (req, res) ->
    key = req.body.publicKey?.trim()
    #TODO: Validate key; make sure it's not null and has other good properties
    log.debug "Registering public key\n", key
    entry = """command="echo" #{key}"""
    tmpFile = '/tmp/' + randomString()
    authKeyPath = '/home/prisoner/.ssh/authorized_keys'
    async.series [
      (cb) ->
        exec "echo '#{entry}' > #{tmpFile}", cb
    , (cb) ->
        exec "rsync #{tmpFile} ubuntu@#{Settings.tunnelHost}:#{tmpFile}", cb
    , (cb) ->
        exec "ssh ubuntu@#{Settings.tunnelHost} 'cat #{tmpFile} | sudo tee -a #{authKeyPath}'", cb
    ], (err, result) ->
      if err
        @sendErrorResponse res, err
      else
        res.end()


module.exports = PrisonController

###
command="echo''" ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQCijWGKAq/aLcT5JoevW2/ZDy5iTrqpZD7f4MhAByjFmDpyUFeOAI58izLS13lifd4FPFUgp3uyj7FLlbXJeqsp4SSy2sxxfCtNfLkBjbYpT8FtUi2/Ap0ZlsRtYjxGDUwC7csTAIPXz1a0W3JxAohYrbB/j+VVdNWjsd8kE2g5TKg0htd58ShfnbMsaB0apWRk2rdjogAXeIJ+BRdPL4fiVE+0E9P/JTGkn8FjIrYcE/lfRD7wnozPOlTILAe/uaGQGaK6f/HS2YGKabLS32RerMP2YbRU89vJdUjeF1RnreZldCTiTsjiApy+5DrCsXVSxz+ZuZtV+XxL3KONPwGX tunneling_key
###
