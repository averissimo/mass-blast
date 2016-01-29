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
    @identity  = (row[IDENTITY].nil? ? 0 : Float(row[IDENTITY]))
    @coverage  = (row[COVERAGE].nil? ? 0 : Float(row[COVERAGE]))
    @evalue    = (row[EVALUE].nil? ? 1 : Float(row[EVALUE]))
    @count     = 1

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
    # logger.debug "adding count (#{@count}) by #{val}"
    @count += val
  end
end

#
class ResultsDB
  #
  attr_accessor :db, :deleted, :redundant
  attr_accessor :header, :header_meaning, :threshold, :threshold_max

  attr_reader :logger

  #
  #
  def initialize(identity_min, identity_max, output_dir, logger = nil)
    @threshold = identity_min
    @threshold_max = identity_max
    @output_dir = output_dir
    # hash of DB instances
    initialize_db
    # list of deleted DB instances
    @deleted    = nil
    # list of redundant DB instances
    @redundant  = nil
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

  def write_deleted(row)
    if @deleted.nil?
      @deleted = open_2_write(@output_dir, Reporting::FILE_DISCARDED)
      write_headers(@deleted)
    end
    write(@deleted, row)
  end

  def write_headers(fid)
    fid.write header.join("\t")
    fid.write header_meaning.join("\t")
  end

  def write_redundant(row)
    if @redundant.nil?
      @redundant = open_2_write(@output_dir, Reporting::FILE_REDUNDANT)
      write_headers(@redundant)
    end
    write(@redundant, row)
  end

  def write(fid, row)
    fid.write row.values.join("\t")
  end

  def size
    db.size
  end

  #
  # add new item to the database of results
  def add(db_id, new_row)
    new_row = DB.new(new_row, logger) unless new_row.class == DB
    # preliminary check if the identity is above
    #  configured threshold or already
    if new_row.identity < threshold || new_row.identity > threshold_max
      write_deleted new_row
      return false
    end
    # set current row as existing one
    cur_row = db[db_id]
    # initialize best row as nil, to be assigned in the
    #  next if clause
    best_row = nil
    # check if there is a element in @db with the 'db_id'
    if cur_row
      # add to redundant array the worst element
      old_row = if new_row > cur_row
                  best_row = new_row
                  cur_row
                else
                  best_row = cur_row
                  new_row
                end
      write_redundant old_row
      # increment the count with the item that was sent
      #  to the redundant list (last element of that list)
      best_row.add_count(old_row.count)
    else
      # if there is not an element in the db then, the new
      #  row is the best one. duhh :)
      best_row = new_row
    end
    # force update the db entry to the best row
    db[db_id] = best_row
    db[db_id]
  end

  #
  # names of blast dbs contained in the results
  def blast_dbs
    db_list = {}
    db.values.each do |el|
      db_list[el.row['db']] = [] if db_list[el.row['db']].nil?
      db_list[el.row['db']] << el.row['sseqid']
    end

    db_list.keys.each do |k|
      db_list[k].uniq!
    end
    db_list
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

  def open_2_write(parent_path, filename)
    File.open(File.join(parent_path,  filename), 'wb')
  end

  def write(fid, db_item)
    fid.write(db_item.row.values.join("\t"))
  end

  def write_trimmed(parent_path, filename)
    write_csv(parent_path, filename, db.values)
  end

  def write_results(parent_path, filename, cols)
    CSV.open(File.join(parent_path, filename),
             'wb',
             col_sep: "\t") do |csv|
      csv << cols
      header_meaning_idx = header_meaning.each_index.select do |i|
        cols.include?(header[i])
      end
      csv << header_meaning.values_at(*header_meaning_idx)
      db.values.each do |row|
        new_row = row.row.reject { |k, _v| !cols.include?(k) }
        csv << new_row.map { |el| el[1] }
      end
    end
    logger.info "Finished writing #{filename}."
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
    logger.info "Finished writing #{filename}."
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
      list.each { |item| csv << item.row.values }
    end
  end

  # create a new database
  def initialize_db
    @db = {}
  end
end
