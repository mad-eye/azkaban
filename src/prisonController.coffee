{EventEmitter} = require 'events'
{exec} = require 'child_process'
_path = require 'path'
hat = require 'hat'
async = require 'async'
{Settings} = require 'madeye-common'
Logger = require 'pince'
child_process = require 'child_process'

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
    authKeyPath = '/home/prisoner/.ssh/authorized_keys'
    command = @_command key, authKeyPath
    sshCommand = """ssh ubuntu@#{Settings.tunnelHost} "#{command}" """
    log.trace "Running (as uid #{process.getuid()})", sshCommand
    child_process.exec sshCommand, (err, stdout, stderr) =>
      log.trace "Returning from adding public key to prisoner."
      log.trace '[stdout]', stdout if stdout
      log.info '[stderr]', stderr if stderr
      if err
        @sendErrorResponse res, err
      else
        res.end()

  _command: (key, authKeyPath) ->
    """echo command=\"echo''\" #{key} | sudo tee -a #{authKeyPath}"""

module.exports = PrisonController

###
command="echo''" ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQCijWGKAq/aLcT5JoevW2/ZDy5iTrqpZD7f4MhAByjFmDpyUFeOAI58izLS13lifd4FPFUgp3uyj7FLlbXJeqsp4SSy2sxxfCtNfLkBjbYpT8FtUi2/Ap0ZlsRtYjxGDUwC7csTAIPXz1a0W3JxAohYrbB/j+VVdNWjsd8kE2g5TKg0htd58ShfnbMsaB0apWRk2rdjogAXeIJ+BRdPL4fiVE+0E9P/JTGkn8FjIrYcE/lfRD7wnozPOlTILAe/uaGQGaK6f/HS2YGKabLS32RerMP2YbRU89vJdUjeF1RnreZldCTiTsjiApy+5DrCsXVSxz+ZuZtV+XxL3KONPwGX tunneling_key
###
