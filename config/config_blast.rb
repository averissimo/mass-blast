require 'configatron/core'
require 'rbconfig'

require 'yaml'

#
#
#
module ConfigBlast
  #
  def initialize(config_path = nil)
    # setup config defaults
    @store = Configatron::RootStore.new
    @store.config.default = File.expand_path('config/default.yml')
    @store.configure_from_hash(YAML.load_file(@store.config.default))
    #
    config_path = @store.config.user if config_path.nil?
    config_path = File.expand_path(config_path)
    #
    @store.config.user = config_path
    @store.configure_from_hash(YAML.load_file(@store.config.user))
    #
    @store.debug.file = File.expand_path(@store.debug.file, File.dirname(config_path))
    #
    set_os
    #
    # create logger object
    if @store.debug.file.nil?
      @logger = Logger.new(STDOUT)
    elsif @store.debug.show_stdout_if_file
      @logger = Logger.new(TeeIO.new(STDOUT, @store.debug.file))
    else
      puts "All output messages are in the log file: #{@store.debug.file}"
      @logger = Logger.new(@store.debug.file)
    end
    #
    @fatal_logger = Logger.new('output/log.exceptions.txt')
    @fatal_logger.progname = 'Blast'
    #
    if @store.debug.level == 'info'
      logger.level = Logger::INFO
    elsif @store.debug.level == 'debug'
      logger.level = Logger::DEBUG
    else
      logger.level = Logger::INFO
    end
    #
    logger.progname = 'Blast'
    #
    logger.info "Log level: #{@store.debug.level}"
    #
    reload_config(config_path)
    super
  end

  def reload_config(config_path = nil)
    config_path = @store.config.user if config_path.nil?
    # get configuration from default yml file
    logger.info('loads configuration from defaults: ' \
      "#{@store.config.default.gsub(FileUtils.pwd + File::Separator, '')}")
    @store.configure_from_hash(YAML.load_file(@store.config.default))
    #
    @store.config.user = File.expand_path(config_path)
    logger.info("loads configuration from user: #{config_path}")
    @store.configure_from_hash(YAML.load_file(@store.config.user))
    # process the configuration to adjust paths and values
    process_config
    logger.debug('loaded and processed configuration files')
  end

  private

  # create output dir if does not exist
  def create_output_dir
    make_dir(@store.output.dir)
    # create output dir with timestamp
    begin
      if !@store.key?(:force_folder)
        @store.output.dir += File::Separator +
                             Time.now.strftime('%Y_%m_%d-%H_%M_%S') +
                             '-' + srand.to_s[3..6]
        Dir.mkdir @store.output.dir
      else
        @store.output.dir += File::Separator + @store.force_folder
        # remove older directory if ex
        if Dir.exist?(@store.output.dir) && @store.force_remove
          FileUtils.rm_rf(@store.output.dir)
        end
        Dir.mkdir(@store.output.dir) unless Dir.exist?(@store.output.dir)
      end
    rescue StandardError => e
      logger.error msg = "Could not create output directory (why: #{e.message})"
      raise msg
    end
    #
    # Create output directory inner structure
    make_dir(File.join(@store.output.dir, @store.output.intermediate))
    make_dir(File.join(@store.output.dir, @store.output.blast_results))
    make_dir(File.join(@store.output.dir, @store.output.fastas))
  end

  def make_dir(dirpath)
    Dir.mkdir dirpath unless Dir.exist?(dirpath)
  rescue
    logger.error(msg = "Could not create '#{dirpath}' directory")
    raise msg
  end

  #
  #
  # Set config variables
  def process_config
    # optional arguments
    @store.identity.min *= 100
    @store.identity.max *= 100
    # convert paths to an absolutes
    #  using config_path as the base directory
    base_dir = File.dirname(@store.config.user)
    #
    @store.output.dir     = File.expand_path(@store.output.dir, base_dir)
    @store.db.parent      = File.expand_path(@store.db.parent, base_dir)
    @store.query.parent   = File.expand_path(@store.query.parent, base_dir)
    @store.annotation_dir = File.expand_path(@store.annotation_dir, base_dir)
    #
    @store.debug.file     = File.expand_path(@store.debug.file, base_dir)

    # check if they exist
    did_it_fail = false
    { output_dir: @store.output.dir,
      db_parent: @store.db.parent,
      query_parent: @store.query.parent,
      annotation_dir: @store.annotation_dir }.each do |key, dir|
      next if Dir.exist? dir
      logger.error "Error: Directory for '#{key}' does not exist, please" \
            ' create it, or change configuration, before running mass blast' \
            ' again.'
      logger.error "  #{key}: #{dir}"
      did_it_fail = true
    end
    exit if did_it_fail
    #
    # create the output directory
    create_output_dir
    #
    logger.debug('query_parent: ' + @store.query.parent)
    logger.debug('db_parent: ' + @store.db.parent)
    #
    fail 'Database parent must be defined in user.yml.' \
      if @store.db.parent.nil?
    fail 'Folders must be defined in user.yml.' \
      if @store.query.folders.nil?
    # set existing dbs
    logger.info("loads databases (from directory '#{@store.db.parent}'): ")
    if @store.db.list.nil? || @store.db.list.empty?
      list_ary = []
      Open3.popen3("blastdbcmd -list #{@store.db.parent}") do |_i, o, _e, _t|
        o.each_line("\n") do |line|
          pair = line.split(/ (Nucleotide|Protein)\n/)
          list_ary << File.basename(pair[0]).gsub(/\.[0-9]+$/, '')
        end
      end
      @store.db.list = list_ary.uniq
    end
    if @store.db.list.nil? || @store.db.list.empty?
      msg = "No blast dbs found in #{@store.db.parent}."
      logger.error msg
      puts "Error: #{msg}"
      exit
    end

    @store.db.list.each { |db| logger.info(" - #{db}") }
  end

  def set_os
    @store.os = (
      host_os = RbConfig::CONFIG['host_os']
      case host_os
      when /mswin|msys|mingw|cygwin|bccwin|wince|emc/
        :windows
      when /darwin|mac os/
        :macosx
      when /linux/
        :linux
      when /solaris|bsd/
        :unix
      else
        :unknown
      end
    )
  end
end
