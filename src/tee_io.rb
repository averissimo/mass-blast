#
class TeeIO < IO
  #
  def initialize(orig, file)
    @orig = orig
    @file = Logger::LogDevice.new(file)
  end

  def write(string)
    @file.write string
    @orig.write string
  end
end
