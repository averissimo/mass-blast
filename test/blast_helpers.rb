require 'fileutils'
#
#
require 'byebug'
module BlastHelpers
  #
  # test every file in the results directory
  #  against the predicted files
  def test_results(type, output_dir)
    files = []
    Dir.glob(test_res_dir(type) + "/**/*") do |test_file|
      #test_file = test_res_dir(type) + File::Separator + item
      item = test_file.gsub(test_res_dir(type), '')
      item = item.gsub( /^\//, '')
      next unless File.file?(test_file)
      file2 = output_dir + File::Separator + item
      files << { output: file2, expected: test_file }
    end
    #
    files
  end

  def test_config(type)
    File.expand_path("test/#{type}/config.yml")
  end

  def test_res_dir(type)
    File.expand_path("test/#{type}/result")
  end
end
