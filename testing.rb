require 'rake'
require 'rdoc/task'
require 'rake/testtask'

require 'byebug'

app = Rake.application
app.init
app.load_rakefile
app['spec'].invoke
