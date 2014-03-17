http = require 'http'
httpProxy = require 'http-proxy'
{Project} = require './models'

#Setup our server to proxy standard HTTP requests
proxy = new httpProxy.createProxyServer {ws: true}

proxyServer = http.createServer (req, res)->
  findTunnel req, res, (err, port)->
    return if err
    target = "http://#{process.env.MADEYE_TUNNEL_HOST}:#{port}"
    proxy.web req, res, {target: target}, (err)->
      console.error "PROXY ERROR", err if err

proxyServer.on "upgrade", (req, socket, head)->
  findTunnel req, null, (err,port)->
    return if err
    proxy.ws req, socket, head, target: {host: process.env.MADEYE_TUNNEL_HOST, port}, (err) ->
      console.error "*ERROR*", err if err

findTunnel = (req, res, callback)->
  [reqUrl, projectId, path] = /\/([\w\d]+)(.*)/.exec(req.url)
  Project.findOne _id: projectId, (err, project)=>
    unless project
      res.statusCode = 400 if res
      error = "PROJECT NOT FOUND"
    unless project.tunnels and project.tunnels.terminal
      res.statusCode = 500 if res
      error = "PROJECT HAS NO TERMINAL TUNNEL"
    if error
      res.end error if res
      callback error
    else
      port = project.tunnels.terminal.remotePort
      # strip project ID from the URL
      req.url = path
      callback null, port

proxyServer.listen process.env.MADEYE_PROXY_PORT
