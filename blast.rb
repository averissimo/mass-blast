require 'logger'
require 'yaml'
require './blast_interface'

#
#
#
class Blast
  #
  include BlastInterface
  #
  needs_implementation :blast_me
  #
  DEF_OUTPUT_DIR = 'output'
  DEF_OUTPUT_EXT = '.out'
  #
  #
  # logger getter
  def log
    @logger
  end

  #
  #
  # initialize class with all necessary data
  def initialize
    # create logger object
    @logger       = Logger.new(STDOUT)
    @logger.level = Logger::INFO
    # load config file
    @config = YAML.load_file('config.yml')
    log.debug(@config.inspect)
    log.debug('loaded config.yml file')
    # parent directories for query and blast db
    @query_parent = File.expand_path(get_config(@config['query_parent'],
                                                Dir.pwd))
    #
    @db_parent    = File.expand_path(get_config(@config['db_parent'],
                                                Dir.pwd))
    #
    log.debug('query_parent: ' + @query_parent)
    log.debug('db_parent: ' + @db_parent)
    # optional arguments
    @dbs     = @config['dbs']
    @folders = @config['query_folders']
    @opts    = @config['opts']
    @task    = @config['task']
    @outfmt  = @config['format']['outfmt']
    #
    @out_dir = get_config(@config['output']['dir'],    DEF_OUTPUT_DIR)
    @out_ext = get_config(@config['output']['ext'],    DEF_OUTPUT_EXT)
    #
    fail 'Databases must be defined in config.yml.' if @dbs.nil?
    fail 'Folders must be defined in config.yml.'   if @folders.nil?
    # set existing dbs
    log.info("loads databases (from directory '#{@query_parent}'): " +
      @dbs.join(', '))
    # create output dir if does not exist
    begin
      Dir.mkdir @out_dir unless Dir.exist?(@out_dir)
    rescue
      log.error(msg = 'Could not create output directory')
      raise msg
    end
    # create output dir with timestamp
    begin
      @out_dir = @out_dir +
                 File::Separator +
                 Time.now.strftime('%Y_%m_%d-%H_%M_%S') +
                 '-' + srand.to_s[3..6]
      Dir.mkdir @out_dir unless Dir.exist?(@out_dir)
    rescue
      log.error(msg = 'Could not create output directory')
      raise msg
    end

    # outfmt specifiers for the blast query (we choose all)
    @outfmt_spec    = @config['format']['specifiers'].keys
    # outfmt specifiers details to add to the report's second line
    @outfmt_details = @config['format']['specifiers'].values
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
      # go through all queries in each directory
      list << Dir[File.join(query_parent, query, '*.query')]
        .each do |query_file|
        #
        log.debug "going to blast with query: '#{query_file}'"
        # run query against all databases
        @dbs.each do |db|
          log.debug "using db: #{db}"
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
    end

    # logging messages
    log.info 'Going to run queries: ' + list.flatten.join(', ')
    log.info 'Calling blastn...'

    until call_queue.empty?
      el = call_queue.pop
      blast_me(el[:qfile],
               el[:db],
               el[:out_file],
               el[:query_parent],
               el[:db_parent])
    end

    log.info 'Success!!'
  end

  #
  #
  # Generate a report from all the outputs
  def gen_report_from_output
    # find all output files
    outs = Dir[File.join(@out_dir, "*#{@out_ext}")]

    # open report.csv to write
    File.open File.join(@out_dir, 'report.csv'), 'w' do |fw|
      # get header columns and surounded by \"
      header = ['file', @outfmt_spec].flatten.map { |el| "\"#{el}\"" }
      detail = ['means the file origin of this line', @outfmt_details]
               .flatten.map { |el| "\"#{el}\"" }

      fw.puts header.join "\t" # adds header columns
      fw.puts detail.join "\t" # adds explanation of header columns

      log.info "written header lines to report (#{header.size} columns)"

      # for each output, add one or more lines
      outs.each do |file|
        File.open file, 'r' do |f|
          data = f.read
          if data.empty? # in case the blast has no hits
            fw.puts file
          else
            # other wise replace the beggining of the line with
            #  the output file name to identify each output
            fw.puts data.gsub(/^(.|\n|\r)/, "#{file}\t\\1")
          end
        end
      end
    end
    log.info "generated '#{File.join(@out_dir, 'report.csv')}' from " +
      outs.size.to_s + ' files'
    log.debug 'report was built from: ' + outs.join(', ')
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
  # get default value
  def get_config(yml_var, default)
    yml_var.nil? ? default : yml_var
  end
end # end of class
