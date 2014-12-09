var cakewalk = require('./../cakewalk.js');
//var test = require('./lib/test_endpoint.js')(cakewalk);

cakewalk.static('./images/');

cakewalk.on('/', function(req, res){
  this.send(res,'Hello World');
});

cakewalk.on('/page', function(req, res){
  this.render(res,'./views/main.html');
});

cakewalk.listen(8000)