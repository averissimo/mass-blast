require 'logger'
require 'yaml'
#
require_relative 'blast_interface'
require_relative 'reporting'
require_relative '../config/config_blast'
require_relative 'tee_io'
#
#
#
class Blast
  #
  include BlastInterface
  include ConfigBlast
  #
  needs_implementation :blast
  #
  attr_reader :logger, :store, :blastdb_cache

  #
  #
  # initialize class with all necessary data
  def initialize(config_path = nil)
    super(config_path)
    # load config file
    reload_config(config_path)
    #
    @blastdb_cache = {}
  end

  #
  #
  def blast_folders(folders      = nil,
                    query_parent = nil,
                    db_parent    = nil)
    db_parent     = @store.db.parent if db_parent.nil?
    query_parent  = @store.query.parent if query_parent.nil?
    query_folders = @store.query.folders if folders.nil?
    # create new queue to add all operations
    call_queue = Queue.new
    list = []
    # run through each directory
    query_folders.each do |query|
      list = blast_folders_each(query, query_parent, db_parent, call_queue)
    end

    # logging messages
    logger.info 'Going to run queries: ' + list.flatten
      .collect { |i| i.gsub(FileUtils.pwd + File::Separator, '') }.join(', ')
    logger.info 'Blasting...'

    logger.debug 'Setting BLASTDB environment variable:'
    logger.debug "  -> #{db_parent}"
    ENV['BLASTDB'] = db_parent

    until call_queue.empty?
      el = call_queue.pop
      cmd = blast(el[:qfile],
                  el[:db],
                  el[:out_file],
                  el[:query_parent])
      #
      logger.info 'running '\
        "'#{el[:qfile].gsub(FileUtils.pwd + File::Separator, '')}'"
      logger.info "  with database '#{el[:db]}' that will store in:"
      logger.info \
        "  '#{el[:out_file].gsub(FileUtils.pwd + File::Separator, '')}'"
      logger.debug cmd
      #
      output = `#{cmd}` # actual call to blast
      #
      logger.debug '  ' + output
    end
  rescue StandardError => e
    logger.progname = logger.progname + ' - Error'
    logger.fatal e.message
    @fatal_logger.fatal e
    exit
  end

  #
  #
  #
  def blast_folders_each(query, query_parent, db_parent, call_queue)
    list = []
    # go through all queries in each directory
    list << Dir[File.join(query_parent, query, '*.fas'),
                File.join(query_parent, query, '*.fna'),
                File.join(query_parent, query, '*.fasta'),
                File.join(query_parent, query, '*.query')]
      .each do |query_file|
      #
      logger.debug "going to blast with query: '#{query_file}'"
      # run query against all databases
      @store.db.list.each do |db|
        logger.debug "using db: #{db}"
        new_item = {}
        new_item[:qfile]        = query_file
        new_item[:db]           = db
        new_item[:out_file]     = gen_filename(query, query_file, db)
        new_item[:query_parent] = nil # empty, because it will
        #                             already have the prefix
        new_item[:db_parent] = db_parent
        call_queue << new_item
      end
    end
    list
  end

  def cleanup
    logger.info("removing #{@store.output.dir}")
    FileUtils.remove_dir(@store.output.dir)
  end

  #
  def load_all_blastdb
    @store.db.list.each do |db_item|
      load_blastdb_item(db_item)
    end
  end

  #
  def load_blastdb_item(db, items = nil)
    #
    return true if !@blastdb_cache.nil? && !@blastdb_cache[db].nil?
    #
    ENV['BLASTDB'] = @store.db.parent
    cmd = "blastdbcmd -db #{db}" \
      ' -dbtype nucl' \
      ' -entry all' \
      " -outfmt \"%s %t\""
    # cannot use the same logic in windows.. strange!!
    if [:linux, :unix, :macosx].include?(@store.os)
      cmd += " | grep '#{items.join('\|')}'"
    #
    logger.info "getting cache for blastdb for: #{db}"
    logger.info "  for #{items.size} query results"
    logger.debug "Cmd for blastdbcmd: BLASTDB=\"#{@store.db.parent}\" #{cmd}\""
    if @store.os == :windows
      output = `#{cmd} | find \"#{items.join(' ')}\""`
    else
      output = `#{cmd}`
    @blastdb_cache[db] = {}
    output.split("\n").each do |line|
      pair = line.split(' ')
      @blastdb_cache[db][pair[1]] = pair[0] if items.nil? ||
                                               items.include?(pair[1])
    end
    true
  end

  def get_nt_seq_from_blastdb(seq_id, db, start_idx, end_idx, frame)
    output = ''
    start_idx = Integer(start_idx)
    end_idx   = Integer(end_idx)
    frame     = Integer(frame)
    begin
      load_blastdb_item(db)
      output = @blastdb_cache[db][seq_id]
    rescue StandardError => e
      logger.unknown "failed on getting from blastdb: #{e.message}"
      return 'Failed on getting sequence from database,' \
        ' see log for more information'
    end
    seq = Bio::Sequence::NA.new(output)
    # check if should use complement sequence
    #  i.e. sframe column is negative
    if frame < 0
      seq = seq.complement
      start_idx = seq.size - start_idx + 1
      end_idx   = seq.size - end_idx + 1
    end
    spliced = seq.subseq(start_idx, end_idx)
    spliced
  end

  #             _            _
  #            (_)          | |
  #  _ __  _ __ ___   ____ _| |_ ___
  # | '_ \| '__| \ \ / / _` | __/ _ \
  # | |_) | |  | |\ V / (_| | ||  __/
  # | .__/|_|  |_| \_/ \__,_|\__\___|
  # | |
  # |_|
  #
  #

  private

  include Reporting
  #
  #
  # Generate filenames for each of the query's output
  def gen_filename(prefix, query, db)
    name = query.gsub(%r{[\S]+\/}, '').gsub(/[\.]query/, '').gsub(/[ ]/, '_')
    list = []
    list << (@store.key?('task') ? @store.task : 'no-task')
    list << prefix unless prefix.nil?
    list << name
    list << db
    File.join(@store.output.dir,
              @store.output.blast_results,
              list.join('#') + @store.output.extension)
  end
end # end of class
