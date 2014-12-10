var cakewalk = require('./../cakewalk.js');
//var test = require('./lib/test_endpoint.js')(cakewalk);

cakewalk.static('./images/');
cakewalk.static('./scripts/',{
  'coffee': function(req, res, next){
  
  }
});

cakewalk.on('/', function(req, res, next){
  this.send(res,'Hello World');
  next()
});

cakewalk.on('/page', function(req, res, next){
  this.render(res,'./views/body.html', next);
});

cakewalk.listen(8000)