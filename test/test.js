var cakewalk = require('./../cakewalk.js'),
test = require('./lib/test_endpoint.js')(cakewalk);

cakewalk.on('/', function(req, res){
  this.send(res,'Hello World');
});

cakewalk.listen(8000)