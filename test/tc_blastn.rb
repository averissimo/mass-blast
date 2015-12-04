require_relative '../blastn'

require 'logger'
require 'test/unit'

#
#
#
class TestBlast < Test::Unit::TestCase
  #
  TEST_CONFIG  = File.expand_path('./test/config.yml')
  TEST_RES_DIR = File.expand_path('test/result')
  REPORT_FILE  = 'report.csv'
  #
  def initialize(*args)
    super(*args)
    # create logger object
    @logger       = Logger.new(STDOUT)
    @logger.level = Logger::INFO
  end

  def test_blastn
    @logger.info('TEST_BLASTN --> Starting test on blastn')
    b = Blastn.new(TEST_CONFIG)
    b.blast_folders
    b.gen_report_from_output

    output_dir = b.out_dir

    @logger.info("TEST_BLASTN --> Output directory is: #{output_dir}")

    Dir.foreach(TEST_RES_DIR) do |item|
      test_file = TEST_RES_DIR + File::Separator + item
      next unless File.file?(test_file) # && File.extname(test_file) == '.out'
      res = FileUtils.cmp(test_file,
                          output_dir + File::Separator + item)
      @logger.info("TEST_BLASTN --> testing: #{item} (same file = #{res})")
      assert(res)
    end
    @logger.info('TEST_BLASTN --> Removing files created')
    b.cleanup
  end
  #
end
