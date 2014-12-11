var cakewalk = require('./../cakewalk.js');

cakewalk.get('/token.html', function(req, res){
  this.render(res,'./views/token.html',{
    variable: 'Stuff'
  })
});

cakewalk.listen(8000);