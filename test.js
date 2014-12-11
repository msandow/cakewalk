var spawn = require('child_process').spawn,
path = require('path'),
tester = spawn('./../node_modules/.bin/mocha', ['.', '--compilers', 'coffee:coffee-script/register'], {
  cwd: path.resolve(process.cwd(), __dirname+'/test/')+'/'
});

tester.stdout.on('data', function(data){
  var str = data.toString();
  if(str.length > 1){
    console.log(str.substr(0,str.length-1));
  }
});

tester.stderr.on('data', function(data){
  console.error(data.toString());
});

tester.on('error', function(err){
  console.error(err);
  process.exit(1);
});

tester.on('close', function(){
  process.exit(1);
});