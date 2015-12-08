require 'logger'
require 'yaml'
require 'byebug'
#
require_relative 'blast_interface'
require_relative 'reporting'
#
#
#
class Blast
  #
  include BlastInterface
  #
  needs_implementation :blast
  #
  DEF_OUTPUT_DIR  = 'output'
  DEF_OUTPUT_EXT  = '.out'
  DEF_CONFIG_PATH = './config.yml'

  attr_reader :logger, :out_dir
  attr_writer :out_dir, :dbs, :folders

  #
  #
  # initialize class with all necessary data
  def initialize(config_path = DEF_CONFIG_PATH)
    # create logger object
    @logger      = Logger.new(STDOUT)
    logger.level = Logger::INFO
    # load config file
    reload_config(config_path)
  end

  #
  #
  def blast_folders(folders      = nil,
                    query_parent = nil,
                    db_parent    = nil)
    query_parent = @query_parent if query_parent.nil?
    folders      = @folders if folders.nil?
    # create new queue to add all operations
    call_queue = Queue.new
    list = []
    # run through each directory
    folders.each do |query|
      list = blast_folders_each(query, query_parent, db_parent, call_queue)
    end

    # logging messages
    logger.info 'Going to run queries: ' + list.flatten.join(', ')
    logger.info 'Calling blastn...'

    until call_queue.empty?
      el = call_queue.pop
      blast(el[:qfile],
            el[:db],
            el[:out_file],
            el[:query_parent],
            el[:db_parent])
    end

    logger.info 'Success!!'
  end

  #
  #
  #
  def blast_folders_each(query, query_parent, db_parent, call_queue)
    list = []
    # go through all queries in each directory
    list << Dir[File.join(query_parent, query, '*.query')]
      .each do |query_file|
      #
      logger.debug "going to blast with query: '#{query_file}'"
      # run query against all databases
      @dbs.each do |db|
        logger.debug "using db: #{db}"
        new_item = {}
        new_item[:qfile]    = query_file
        new_item[:db]       = db
        new_item[:out_file] = gen_filename(query, query_file, db)
        new_item[:query_parent] = '' # empty, because it will
        #                             already have the prefix
        new_item[:db_parent] = db_parent
        call_queue << new_item
      end
    end
    list
  end

  def cleanup
    logger.info("removing #{@out_dir}")
    FileUtils.remove_dir(@out_dir)
  end

  def db_parent=(new_db_parent)
    @db_parent    = File.expand_path(new_db_parent)
  end

  def query_parent=(new_query_parent)
    @query_parent = File.expand_path(new_query_parent)
  end

  def reload_config(config_path = 'config.yml')
    @config = YAML.load_file(config_path)
    logger.debug(@config.inspect)
    set_config
    logger.debug('loaded config.yml file')
  end
  #             _            _
  #            (_)          | |
  #  _ __  _ __ ___   ____ _| |_ ___
  # | '_ \| '__| \ \ / / _` | __/ _ \
  # | |_) | |  | |\ V / (_| | ||  __/
  # | .__/|_|  |_| \_/ \__,_|\__\___|
  # | |
  # |_|

  private

  include Reporting
  #
  def get_nt_seq_from_blastdb(seq_id, db, qstart, qend)
    cmd = "blastdbcmd -db #{db} \
                      -dbtype 'nucl' \
                      -entry all \
                      -outfmt \"%s %t\" \
           | awk '{ if( $2 == \"#{seq_id}\" ) { print $1 } }'"
    output = `#{cmd}`
    seq = Bio::Sequence::NA.new output
    spliced = seq.splice("#{qstart}..#{qend}")
    spliced
  end
  #
  #
  # Generate filenames for each of the query's output
  def gen_filename(prefix, query, db)
    name = query.gsub(%r{[\S]+\/}, '').gsub(/[\.]query/, '').gsub(/[ ]/, '_')
    list = []
    list << @task
    list << prefix unless prefix.nil?
    list << name
    list << db
    File.join(@out_dir, list.join('#') + @out_ext)
  end

  #
  #
  # Set config variables
  def set_config
    # parent directories for query and blast db
    self.query_parent = get_config(@config['query_parent'], Dir.pwd)
    #
    self.db_parent    = get_config(@config['db_parent'], Dir.pwd)
    # optional arguments
    self.dbs     = @config['dbs']
    self.folders = @config['query_folders']
    @opts        = @config['opts']
    @task        = @config['task']
    @outfmt      = @config['format']['outfmt']
    #
    @identity_threshold = @config['identity_threshold']
    @identity_threshold *= 100
    #
    # orf options
    @orf = {}
    @orf[:stop]    = @config['orf']['stop_codon']
    @orf[:start]   = @config['orf']['start_codon']
    @orf[:reverse] = @config['orf']['reverse']
    @orf[:direct]  = @config['orf']['direct']
    @orf[:min]     = @config['orf']['min']
    #
    @verbose_out = !get_config(@config['clean_output'], false)
    #
    @out_dir = get_config(@config['output']['dir'],    DEF_OUTPUT_DIR)
    @out_ext = get_config(@config['output']['ext'],    DEF_OUTPUT_EXT)

    @out_dir = File.expand_path(@out_dir)
    create_out_dir
    #
    #
    logger.debug('query_parent: ' + @query_parent)
    logger.debug('db_parent: ' + @db_parent)
    #
    fail 'Databases must be defined in config.yml.' if @dbs.nil?
    fail 'Folders must be defined in config.yml.'   if @folders.nil?
    # set existing dbs
    logger.info("loads databases (from directory '#{@query_parent}'): " +
      @dbs.join(', '))

    # outfmt specifiers for the blast query (we choose all)
    @outfmt_spec    = @config['format']['specifiers'].keys
    # outfmt specifiers details to add to the report's second line
    @outfmt_details = @config['format']['specifiers'].values
  end

  def create_out_dir
    # create output dir if does not exist
    begin
      Dir.mkdir @out_dir unless Dir.exist?(@out_dir)
    rescue
      logger.error(msg = 'Could not create output directory')
      raise msg
    end
    # create output dir with timestamp
    begin
      if @config['force_folder'].nil?
        @out_dir = @out_dir +
                   File::Separator +
                   Time.now.strftime('%Y_%m_%d-%H_%M_%S') +
                   '-' + srand.to_s[3..6]
        Dir.mkdir @out_dir
      else
        @out_dir = @out_dir + File::Separator + @config['force_folder']
        Dir.mkdir(@out_dir) unless Dir.exist?(@out_dir)
      end
    rescue
      logger.error(msg = 'Could not create output directory')
      raise msg
    end
  end

  #
  #
  # get default value
  def get_config(yml_var, default)
    yml_var.nil? ? default : yml_var
  end
end # end of class
