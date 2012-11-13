require('coffee-script');

/**
 * Module dependencies.
 */

var express = require('express')
  , http = require('http')
  , path = require('path');

var app = module.exports = express();

var routes = require('./routes')
  , user = require('./routes/user')
  , dementor = require('./routes/dementor');

app.configure(function(){
  app.set('port', process.env.PORT || 4000);
  app.use(express.favicon());
  app.use(express.logger('dev'));
  app.use(express.bodyParser());
  app.use(express.methodOverride());
  app.use(app.router);
  app.use(express.static(path.join(__dirname, 'public')));
  app.set('mongo.hostname', 'mongo.madeye.io');
  app.set('mongo.port', 1234); //FIXME
  app.set('apogee.hostname', 'apogee.madeye.io');
});

app.configure('development', function(){
  app.use(express.errorHandler());
  app.set('mongo.hostname', 'mongo.madeye.io'); //FIXME
  app.set('mongo.port', 1234); //FIXME
  app.set('apogee.hostname', 'apogee.madeye.io');
});

app.configure('test', function(){
  app.set('port', 4001)
  app.use(express.errorHandler());
  app.set('mongo.hostname', 'mongo.madeye.io'); //FIXME
  app.set('mongo.port', 1234); //FIXME
  app.set('apogee.hostname', 'apogee.madeye.io');
});

app.get('/', routes.index);
app.get('/users', user.list);
app.get('/init', dementor.init);

http.createServer(app).listen(app.get('port'), function(){
  console.log("Express server listening on port " + app.get('port'));
});
