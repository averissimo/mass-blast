require 'logger'
require 'yaml'
require 'byebug'
#
require_relative 'blast_interface'
require_relative 'reporting'
require_relative 'config_blast'
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
  attr_reader :logger, :store

  #
  #
  # initialize class with all necessary data
  def initialize(config_path = nil)
    super(config_path)
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
      @store.db.list.each do |db|
        logger.debug "using db: #{db}"
        new_item = {}
        new_item[:qfile]        = query_file
        new_item[:db]           = db
        new_item[:out_file]     = gen_filename(query, query_file, db)
        new_item[:query_parent] = '' # empty, because it will
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
    list << @store.task
    list << prefix unless prefix.nil?
    list << name
    list << db
    File.join(@store.output.dir, list.join('#') + @store.output.extension)
  end
end # end of class
