require 'logger'
#
class DB
  include Comparable

  IDENTITY = 'pident'
  COVERAGE = 'qcovs'
  EVALUE   = 'evalue'
  BLAST_DB = 'db'

  attr_accessor :row
  attr_accessor :count, :identity, :coverage, :evalue, :to_delete
  attr_reader :logger

  def initialize(row, logger = nil)
    @row       = row
    @identity  = Float(row[IDENTITY])
    @coverage  = Float(row[COVERAGE])
    @evalue    = Float(row[EVALUE])
    @count     = 1
    @to_delete = false

    unless logger.nil?
      @logger = logger.clone
      @logger.progname = 'DB'
    end
  end

  def row
    @row['contig_count'] = @count
    @row
  end

  def <=>(other)
    (identity <=> other.identity &&
     coverage <=> other.coverage &&
     evalue <=> other.evalue)
  end

  def [](key)
    row[key]
  end

  def []=(key, val)
    row[key] = val
  end

  def add_count(val = 1)
    #logger.debug "adding count (#{@count}) by #{val}"
    @count += val
  end
end

#
class ResultsDB
  #
  attr_accessor :db, :deleted, :redundant
  attr_accessor :header, :header_meaning, :threshold

  attr_reader :logger

  #
  #
  def initialize(identity_threshold, logger = nil)
    @threshold = identity_threshold
    # hash of DB instances
    initialize_db
    # list of deleted DB instances
    @deleted    = []
    # list of redundant DB instances
    @redundant  = []
    # list of string that makes the header
    @header     = []
    # list of strings with each of the headers meaning
    @header_meaning = []
    #
    @logger = (logger.nil? ? Logger.new(STDOUT) : logger.clone)
    @logger.level = Logger::INFO if logger.nil?
    @logger.progname = 'ResultDB'
  end

  def values
    @db.values.sort_by do |line|
      [line['file'], line['pident'], line['qcovs'], line['sseqid']]
    end
  end

  def size
    db.size
  end

  #
  # add new item to the database of results
  def add(db_id, new_row)
    logger.debug "\t class: #{new_row.class}"
    logger.debug "\t new row count: #{new_row.count}" if new_row.class == DB
    new_row = DB.new(new_row, logger) unless new_row.class == DB
    # preliminary check if the identity is above
    #  configured threshold or already
    if new_row.identity < threshold
      deleted << new_row
      return false
    end
    # set current row as existing one
    cur_row = db[db_id]
    # initialize best row as nil, to be assigned in the
    #  next if clause
    best_row = nil
    # check if there is a element in @db with the 'db_id'
    before = db[db_id].count if cur_row
    if cur_row
      # add to redundant array the worst element
      redundant << if new_row > cur_row
                     best_row = new_row
                     cur_row
                   else
                     best_row = cur_row
                     new_row
                   end
      # increment the count with the item that was sent
      #  to the redundant list (last element of that list)
      best_row.add_count(redundant.last.count)
    else
      # if there is not an element in the db then, the new
      #  row is the best one. duhh :)
      best_row = new_row
    end
    # force update the db entry to the best row
    db[db_id] = best_row
    logger.debug("\tcount before: #{before}") if cur_row
    logger.debug("\tcount after: #{db[db_id].count}") if cur_row
    db[db_id]
  end

  #
  # names of blast dbs contained in the results
  def blast_dbs
    db.values.collect { |el| el.row[BLAST_DB] }.uniq
  end

  #
  #
  def remove_identical(col_id)
    logger.level = Logger::DEBUG
    new_db = @db
    initialize_db
    new_db.values.each do |el|
      db_id = "#{el[col_id]}_#{el[DB::BLAST_DB]}"
      add(db_id, el)
    end
  end

  def write_redundant(parent_path, filename)
    write_csv(parent_path, filename, redundant)
  end

  def write_deleted(parent_path, filename)
    write_csv(parent_path, filename, deleted)
  end

  def write_trimmed(parent_path, filename)
    write_csv(parent_path, filename, db.values)
  end

  def write_results(parent_path, filename, cols)
    CSV.open(File.join(parent_path, filename),
             'wb',
             col_sep: "\t") do |csv|
      csv << header
      csv << header_meaning
      db.values.each do |row|
        csv << row.row.reject { |k, _v| !cols.include?(k) }
      end
    end
  end

  def write_fasta_files
    fasta_files = gather_fasta
    #
    fasta_files.keys.each do |fasta_db|
      write_fasta_each(fasta_db, :nt, FILE_FASTA_NT)
      write_fasta_each(fasta_db, :aa, FILE_FASTA_AA)
    end
  end

  protected

  #
  # write each fasta file method (will be called for nt and aa)
  def write_fasta_each(fasta_db, type, filename)
    File.open(File.join(@store.output.dir,
                        @store.output.fastas,
                        fasta_db.to_s + '_' + filename),
              'wb',
              col_sep: "\t") do |fid|
      fid.write fasta_files[fasta_db][type].join("\n")
    end
  end

  #
  # method that processes all rows in csv
  #  and does so in NUM_TREADS
  def gather_fasta
    #
    fasta_files = {}
    values.each do |line|
      #
      fasta_files[line['db']] = { nt: [], aa: [] } \
        if fasta_files[line['db']].nil?
      fasta_files[line['db']][:nt] << \
        ">#{line['sseqid']}-#{line['db']}-#{line['qseqid']}"
      fasta_files[line['db']][:aa] << fasta_files[line['db']][:nt].last
      fasta_files[line['db']][:nt] << line['nt_longest_orf']
      fasta_files[line['db']][:aa] << line['aa_longest_orf']
    end
    fasta_files
  end

  # write CSV list
  def write_csv(parent_path, filename, list)
    CSV.open(File.join(parent_path, filename),
             'wb',
             col_sep: "\t") do |csv|
      csv << header
      csv << header_meaning
      list.each { |row| csv << row.row }
    end
  end

  # create a new database
  def initialize_db
    @db = {}
  end
end
