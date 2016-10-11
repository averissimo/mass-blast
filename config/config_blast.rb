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
    logger.info('Loads default configuration: ')
    logger.info("  #{@store.config.default.gsub(FileUtils.pwd + File::Separator, '')}")
    @store.configure_from_hash(YAML.load_file(@store.config.default))
    #
    @store.config.user = File.expand_path(config_path)
    logger.info 'Loads user configuration:'
    logger.info "  #{config_path}"
    @store.configure_from_hash(YAML.load_file(@store.config.user))
    # process the configuration to adjust paths and values
    process_config
    logger.info('Validating configuration...')
    validate_config
    logger.debug('Finished loading configuration.')
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

  # Validate YAML configuration with required options
  def validate_config
    #
    # flag shows if there has been an error
    flag = false
    # function to be called for numbers
    check_numeric = proc do |my_key,
                             full_key,
                             spaces = 0,
                             min = nil,
                             max = Float::INFINITY,
                             base = @store,
                             example,
                             reduce_by|
      #
      min = -Float::INFINITY if min.nil?
      #
      if !base.key?(my_key) ||
         !(base[my_key].is_a?(Numeric)) ||
         !(base[my_key] / reduce_by >= min && base[my_key] / reduce_by <= max)
        msg = "Config Error: \'#{full_key}\' option is not properly set in" \
         ' user.yml\'. Please check if it is a number' \
         " (between #{min} and #{max}) and has"
        if spaces == 0
          msg += ' no spaces before.'
        else
          msg += " #{spaces} spaces before. It should be something like: \n"
          full_key.split('.').each_with_index do |part, k|
            msg += k.times.collect { '(space)(space)' }.join('') + part
            if (k < full_key.split('.').length - 1)
              msg += "\n"
            end
          end
          msg += ": #{example}"
        end
        logger.error msg
        flag = true
      end
    end
    log_required = proc do |key, optional = ''|
      msg = "Config Error: Must set \'#{key}\' option in \'user.yml\'," \
        " check documentation for an example. #{optional}"
      logger.error msg
      flag = true
    end
    #
    log_required_sub = proc do |_key, full_path, sample, optional = ''|
      msg = "Config Error: Must set a \'#{full_path}\' option in \'user.yml\',"\
            " check documentation for an example. #{optional}\n"
      splited = full_path.split('.')
      splited.each_with_index do |str, k|
        msg += k.times.collect { '(space)(space)' }.join('') + str + ': '
        msg += if k == splited.length - 1
                 "#{sample}"
               else
                 "\n"
               end
      end
      logger.error(msg)
      flag = true
    end
    #
    log_required_sub_type = proc do |config, key, partial_path,
                                   sample, my_type, optional = ""|
      if !config.key?(key) || !config.dir.is_a?(my_type)
        log_required_sub(key, partial_path + ".#{key}", sample, optional)
      end
    end
    #
    #  check engine
    engines = %w(tblastn blastn tblastx)
    if !@store.key?(:engine) ||
       !engines.include?(@store.engine)
      log_required.call('engine', 'Available engines: ' + engines.join(', '))
    end
    #
    #  check separate_db
    if !@store.key?(:separate_db) ||
       !([true, false].include?(@store.separate_db))
      log_required.call('separate_db', 'Must be true/false')
    end
    #
    #  check use_threads
    check_numeric.call('use_threads', 'use_threads', 0, 1, Float::INFINITY,
                       @store, 4, 1)
    #
    # check debug file
    if !@store.key?(:debug) || !@store.debug.key?(:file) ||
       !@store.debug.file.is_a?(String)
      log_required_sub('file', 'debug.file', 'output/logger.txt')
    end
    #
    # check opts
    if !@store.key?(:opts) || !@store.opts.is_a?(String)
      log_required('opts')
    end
    #
    # check identity
    check_numeric.call('min', 'identity.min', 2, 0, 1,
                       @store.identity, 0.1, 100)

    check_numeric.call('max', 'identity.max', 2, 0, 1,
                       @store.identity, 1.0, 100)
    #
    # check prune_identical
    if !@store.key?(:prune_identical)
      log_required.call('prune_identical')
    else
      if !@store.prune_identical.key?('use_worst') ||
         !([true, false].include?(@store.prune_identical.use_worst))
        log_required_sub.call('use_worst', 'prune_identical.use_worst',
                              'true/false')
      end

      if !@store.prune_identical.key?('first') ||
         @store.prune_identical.first.nil? ||
         @store.prune_identical.first.empty?
        log_required_sub.call('first', 'prune_identical.first',
                              '(some blast column name)')
      end
      #
      if !@store.prune_identical.key?('list') ||
         !@store.prune_identical.list.is_a?(Array)
        log_required_sub.call('list', 'prune_identical.list',
                              '\n    - (some blast column name)')
      end
    end
    #
    # chekc output
    if !@store.key?(:output)
      log_required.call('output')
    else
      log_required_sub_type.call(@store.output, 'dir', 'output', 'output',
                                 String, 'Should be the output directory')
      log_required_sub_type.call(@store.output, 'extension', 'output', '.out',
                                 String, 'Should be the extension of the Blast'\
                                 ' results')
      log_required_sub_type.call(@store.output, 'intermediate', 'output',
                                 'intermediate',
                                 String, 'Should be the name of intermediate' \
                                 ' folder')
      log_required_sub_type.call(@store.output, 'blast_results', 'output',
                                 'blast_results',
                                 String, 'Should be the name of blast results' \
                                 ' folder')
      log_required_sub_type.call(@store.output, 'fastas', 'output',
                                 'fasta_files',
                                 String, 'Should be the name of fasta output' \
                                 ' folder')
    end
    #
    # check annotation_dir => not required!
    #

    #
    # check db
    if !@store.key?(:db)
      log_required.call('db')
    else
      log_required_sub_type.call(@store.db, 'parent', 'db', 'db_and_queries/db',
                                 String, 'Should be the databases directory')
    end
    #
    # check query
    if !@store.key?(:query)
      log_required.call('query')
    else
      log_required_sub_type.call(@store.query, 'parent', 'query',
                                 'db_and_queries', String,
                                 'Should be the query parent directory')
      if !@store.query.key?('folders') || !@store.query.folders.is_a?(Array)
        log_required_sub.call('folders', 'query.list', '\n    - (folder name)')
      end
    end
    #
    # check ORF
    if !@store.key?(:orf)
      log_required.call('orf')
    else
      if !@store.orf.key?('stop_codon') || !@store.orf.stop_codon.is_a?(Array)
        log_required_sub.call('stop_codon', 'orf.stop_codon', '\n    - (codon)')
      end
      if !@store.orf.key?('start_codon') || !@store.orf.stop_codon.is_a?(Array)
        log_required_sub.call('start_codon', 'orf.start_codon', '\n    - (codon)')
      end
      unless [true, false].include?(@store.orf.reverse)
        log_required_sub.call('reverse', 'orf.reverse', 'true/false')
      end
      unless [true, false].include?(@store.orf.direct)
        log_required_sub.call('direct', 'orf.direct', 'true/false')
      end
      check_numeric.call('min', 'orf.min', 2, 0, Float::INFINITY, @store.orf, '120', 1)
    end
    #
    #
    #
    return nil unless flag
    #
    fail('Some errors with the configuration, please check the log for more' \
      ' information and correct\'user.yaml\'')
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
    @store.debug.file     = File.expand_path(@store.debug.file, base_dir)
    #
    if @store.key?('annotation_dir') &&
       !@store.annotation_dir.nil? &&
       @store.annotation_dir != 'nil'
      @store.annotation_dir = File.expand_path(@store.annotation_dir, base_dir)
    end
    #

    # check if they exist
    did_it_fail = false
    { output_dir: @store.output.dir,
      db_parent: @store.db.parent,
      query_parent: @store.query.parent,
      annotation_dir: @store.annotation_dir }.each do |key, dir|
      next if key.to_s == 'annotation_dir' && (dir.nil? || dir == 'nil')
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
    logger.debug 'Query_parent: '
    logger.debug "  #{@store.query.parent}"
    logger.debug 'DB_parent: '
    logger.debug "  #{@store.db.parent}"
    #
    fail 'Database parent must be defined in user.yml.' \
      if @store.db.parent.nil?
    fail 'Folders must be defined in user.yml.' \
      if @store.query.folders.nil?
    # set existing dbs
    logger.info('Databases: ')
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

    @store.db.list.each { |db| logger.info("  - #{db}") }
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
