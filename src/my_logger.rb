require 'logger'

#
class MyLogger < Logger

  def add(*args)
    super
    puts format_message(format_severity(args[0]),
                        Time.now,
                        progname,
                        args[2]) if @logdev.dev != STDOUT &&
                                    level <= args[0]
  end
end
