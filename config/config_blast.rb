require 'configatron/core'

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
    #
    @store.config.user = File.expand_path(config_path)
    @store.configure_from_hash(YAML.load_file(File.expand_path(config_path)))
  end

  def reload_config(config_path = nil)
    config_path = @store.config.user if config_path.nil?
    # get configuration from default yml file
    logger.info("loads configuration from defaults: #{@store.config.default}")
    @store.configure_from_hash(YAML.load_file(@store.config.default))
    logger.info("loads configuration from user: #{config_path}")
    @store.configure_from_hash(YAML.load_file(File.expand_path(config_path)))
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
    @store.identity_threshold *= 100
    # convert paths to an absolutes
    @store.output.dir   = File.expand_path(@store.output.dir)
    @store.db.parent    = File.expand_path(@store.db.parent)
    @store.query.parent = File.expand_path(@store.query.parent)
    # create the output directory
    create_output_dir
    #
    logger.debug('query_parent: ' + @store.query.parent)
    logger.debug('db_parent: ' + @store.db.parent)
    #
    fail 'Database parent must be defined in config/user.yml.' \
      if @store.db.parent.nil?
    fail 'Folders must be defined in config/user.yml.' \
      if @store.query.folders.nil?
    # set existing dbs
    logger.info("loads databases (from directory '#{@store.db.parent}'): ")
    if @store.db.list.nil? || @store.db.list.empty?
      @store.db.list = []
      Dir[File.join(@store.db.parent, '*.nhr')].each do |filename|
        next unless File.file? filename
        no_ext = File.basename(filename, File.extname(filename))
        @store.db.list << no_ext.gsub(/\.[0-9]+$/, '')
      end
    end
    if @store.db.list.nil? || @store.db.list.empty?
      msg = "No blast dbs found in #{@store.db.parent}."
      logger.error msg
      puts "Error: #{msg}"
      exit
    end

    @store.db.list.each { |db| logger.info(" - #{db}") }
  end
end
