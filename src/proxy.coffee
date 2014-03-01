http = require 'http'
httpProxy = require 'http-proxy'
{Project} = require './models'

#Setup our server to proxy standard HTTP requests
proxy = new httpProxy.createProxyServer {ws: true}

proxyServer = http.createServer (req, res)->
  [reqUrl, projectId, path] = projectId = /\/([\w\d]+)(.*)/.exec(req.url)
  Project.findOne _id: projectId, (err, project)=>
    #TODO handle error
    port = project.tunnels.terminal.remotePort
    # target = "http://#{process.env.MADEYE_TUNNEL_HOST}:#{port}#{path}"
    target = "http://#{process.env.MADEYE_TUNNEL_HOST}:#{port}"
    # strip project ID from the URL
    req.url = path
    proxy.web req, res, {target: target}, (err, something)->
      console.error "ERROR", err
      console.log "SOMETHING", something

proxyServer.on "upgrade", (req, socket, head)->
  [reqUrl, projectId, path] = projectId = /\/([\w\d]+)(.*)/.exec(req.url)
  Project.findOne _id: projectId, (err, project)=>
    #TODO handle error
    port = project.tunnels.terminal.remotePort
    # target = "http://#{process.env.MADEYE_TUNNEL_HOST}:#{port}#{path}"
    target = "http://#{process.env.MADEYE_TUNNEL_HOST}:#{port}"
    # strip project ID from the URL
    req.url = path
    proxy.ws req, socket, head, target: {host: "tunnel-test.madeye.io", port}, (err) ->
      console.error "*ERROR*", err

proxyServer.listen 4159
