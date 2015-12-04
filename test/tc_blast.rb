require_relative '../blastn'

require 'logger'
require 'test/unit'

#
#
#
class TestBlast < Test::Unit::TestCase
  #
  REPORT_FILE = 'report.csv'

  def test_config(type)
    File.expand_path("test/#{type}/config.yml")
  end

  def test_res_dir(type)
    File.expand_path("test/#{type}/result")
  end

  #
  def initialize(*args)
    super(*args)
    # create logger object
    @logger       = Logger.new(STDOUT)
    @logger.level = Logger::INFO
  end

  #
  # test blastn class
  def test_blastn
    type = 'blastn'
    @logger.info('TEST_BLASTN --> Starting test on blastn')
    b = Blastn.new(test_config(type))
    b.blast_folders
    b.gen_report_from_output

    output_dir = b.out_dir

    @logger.info("TEST_BLASTN --> Output directory is: #{output_dir}")

    test_results(type, output_dir)
    @logger.info('TEST_BLASTN --> Removing files created')
    b.cleanup
  end

  private

  #
  # test every file in the results directory
  #  against the predicted files
  def test_results(type, output_dir)
    Dir.foreach(test_res_dir(type)) do |item|
      test_file = test_res_dir(type) + File::Separator + item
      next unless File.file?(test_file)
      res = FileUtils.cmp(test_file,
                          output_dir + File::Separator + item)
      @logger.info("TEST_BLASTN --> testing: #{item} (same file = #{res})")
      assert(res)
    end
  end
  #
end
