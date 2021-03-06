require 'logger'
require 'net/ftp'
require 'net/http'

require 'rubygems'
require 'rubygems/package'
require 'zlib'
require 'fileutils'

module Util
  #
  module Tar
    # un-gzips the given IO, returning the
    # decompressed version as a StringIO
    def self.ungzip(tarfile)
      z = (if tarfile.class == String
             Zlib::GzipReader.open(tarfile)
           else
             Zlib::GzipReader.new(tarfile)
           end)
      unzipped = StringIO.new(z.read)
      z.close
      unzipped
    end

    # untars the given IO into the specified
    # directory
    def self.untar(io, destination)
      Gem::Package::TarReader.new io do |tar|
        tar.each do |tarfile|
          destination_file = File.join destination, tarfile.full_name

          if tarfile.directory?
            FileUtils.mkdir_p destination_file
          else
            destination_directory = File.dirname(destination_file)
            FileUtils.mkdir_p destination_directory \
              unless File.directory?(destination_directory)
            File.open destination_file, 'wb' do |f|
              f.print tarfile.read
            end
          end
        end
      end
    end
  end
end

#
class ExternalData
  #
  TAR_FILE    = 'taxdb.tar.gz'
  TEST_DB_URI  = 'http://sels.tecnico.ulisboa.pt/software-archive/data/blackberry_db.tar.gz'
  SPEC_PARENT = 'test/db'
  attr_reader :logger
  TIMEOUT = 600

  def self.download_test_db(parent_path, logger)
    #
    uri = URI TEST_DB_URI
    #
    Net::HTTP.start(uri.host, uri.port, read_timeout: TIMEOUT) do |http|
      request = Net::HTTP::Get.new uri.path
      #
      logger.info "  downloading #{uri} ..."
      #
      response = http.request request #
      logger.info '  ungzipping...'
      io = Util::Tar.ungzip(StringIO.new(response.body))
      logger.info '  untarring...'
      Util::Tar.untar(io, SPEC_PARENT)
    end
  end

  def self.download(parent_path = 'db_and_queries/db', only_working_dir = false)
    logger = Logger.new(STDOUT)
    logger.progname = 'Download'
    logger.info('----- Download missing data necessary for mass blast ----')
    #
    run = proc do |files, parent, fun|
      #
      files.each do |el|
        file_path = File.join(parent, el)
        #
        str = "Checking if '#{file_path}' exists..."
        if File.exist?(file_path)
          str += ' yes!'
          logger.info str
        else
          str += ' no!'
          logger.info str
          send(fun, parent_path, logger)
        end
      end
    end
    # download if database does not exist
    run.call(['taxdb.btd', 'taxdb.bti'], parent_path, :download_taxdb)
    #
    unless only_working_dir
      run.call(['taxdb.btd', 'taxdb.bti'], SPEC_PARENT, :download_taxdb)
      #
      run.call(['blackberry_loch_ness.nhr',
                'blackberry_loch_ness.nin',
                'blackberry_loch_ness.nsq'], SPEC_PARENT, :download_test_db)
    end

    logger.info('----- Finish downloading --------------------------------')
  rescue StandardError => e
    msg = \
      case e
      #
      when Net::ReadTimeout
        'Took too long to retrieve file, please retry again' \
          " and hope for a better internet connection (#{e.message})."
      when SocketError
        "No internet connection, please try later (#{e.message})."
      else
        e.message
      end
    logger.progname = logger.progname + ' - Error'
    logger.fatal msg
    exit
  end

  def self.download_taxdb(parent_path, logger)
    #
    tar_path = File.join(parent_path, TAR_FILE)
    #
    logger.info "File downloading to #{tar_path}..."
    #
    Net::FTP.open('ftp.ncbi.nlm.nih.gov') do |ftp|
      ftp.read_timeout = TIMEOUT
      ftp.passive = true
      logger.info '  logging in to ftp...'
      ftp.login
      logger.info '  going to \'blast/db\'...'
      ftp.chdir 'blast/db'
      logger.info '  retrieving file...'
      ftp.getbinaryfile('taxdb.tar.gz', tar_path, 1024)
      logger.info '  file has been retrieved!'
    end
    #
    #
    logger.info 'Ungzipping...'
    io = Util::Tar.ungzip(tar_path)
    logger.info 'Untaring...'
    Util::Tar.untar(io, parent_path)
    logger.info 'Copying db to spec...'
    Dir[File.join(parent_path, 'taxdb.bt*')].each do |f|
      logger.info "  copying #{f}"
      FileUtils.cp f, SPEC_PARENT
    end
    logger.info 'Removing temporary tar file'
    FileUtils.rm(tar_path)
    logger.info 'Done!'
    true
  end
end
