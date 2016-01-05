#
class TeeIO < IO
  #
  def initialize(orig, file)
    @orig = orig
    @file = File.new(file,'wb')
  end

  def write(string)
    @file.write string
    @orig.write string
  end
end
