require 'rake'
require 'rdoc/task'
require 'rake/testtask'

app = Rake.application
app.init
app.load_rakefile
app['spec'].invoke
