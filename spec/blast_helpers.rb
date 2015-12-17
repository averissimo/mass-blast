require 'fileutils'
#
#
module BlastHelpers
  #
  # test every file in the results directory
  #  against the predicted files
  def test_results(type, output_dir)
    files = []
    Dir.foreach(test_res_dir(type)) do |item|
      test_file = test_res_dir(type) + File::Separator + item
      next unless File.file?(test_file)
      file2 = output_dir + File::Separator + item
      files << { output: file2, expected: test_file }
    end
    #
    files
  end

  def test_config(type)
    File.expand_path("spec/#{type}/config.yml")
  end

  def test_res_dir(type)
    File.expand_path("spec/#{type}/result")
  end
end
