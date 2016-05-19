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
    # highest identity wins!
    (identity <=> other.identity).nonzero? ||
      # highest coverage wins"
      (coverage <=> other.coverage).nonzero? ||
      # lowest evalue wins!
      (other.evalue <=> evalue).nonzero? ||
      # else they are equal!
      0
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
  def initialize(identity_min,
                 identity_max,
                 output_dir,
                 fasta_dir,
                 keep_worst = false,
                 logger = nil)
    @threshold     = identity_min
    @threshold_max = identity_max
    @output_dir    = output_dir
    @fasta_dir     = fasta_dir
    @keep_worst    = keep_worst
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

  def [](key)
    db[key]
  end

  def values
    @db.values.sort_by do |line|
      [line['file'], line['pident'], line['qcovs'], line['sseqid']]
    end
  end

  def add_info(keys, values, new_col_key, new_col_val, file_origin = nil)
    header.concat new_col_key
    file_origin = [new_col_key] if file_origin.nil?
    header_meaning.concat file_origin
    db.values.each do |el|
      new_col_key.each_with_index do |col_key, ix|
        if el[keys[:one]] == values[:one] && el[keys[:two]] == values[:two]
          el[col_key] = new_col_val[ix]
        elsif el[col_key].nil?
          el[col_key] = ''
        end
      end
    end
  end

  def write_deleted(row = nil)
    if @deleted.nil?
      @deleted = open_2_write(@output_dir, Reporting::FILE_DISCARDED)
      write_headers(@deleted)
    end
    write(@deleted, row) unless row.nil?
  end

  def write_headers(fid)
    fid.write header.join("\t")
    fid.write header_meaning.join("\t")
  end

  def write_redundant(row = nil)
    if @redundant.nil?
      @redundant = open_2_write(@output_dir, Reporting::FILE_REDUNDANT)
      write_headers(@redundant)
    end
    write(@redundant, row) unless row.nil?
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
    db_id = size + 1 if db_id.nil?
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
      # switch best and old if the worst is to be kept!
      if @keep_worst
        temp_row = best_row
        best_row = old_row
        old_row  = temp_row
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
    uniq_count = 0
    logger.level = Logger::DEBUG
    new_db = @db
    initialize_db
    new_db.values.each do |el|
      if el[col_id].nil? || el[col_id].empty?
        db_id = "#{uniq_count}_#{el[DB::BLAST_DB]}"
        uniq_count += 1
      else
        db_id = "#{el[col_id]}_#{el[DB::BLAST_DB]}"
      end
      add(db_id, el)
    end
  end

  def open_2_write(parent_path, filename)
    File.open(File.join(parent_path, filename), 'wb')
  end

  def write(fid, db_item)
    fid.write(db_item.row.values.join("\t"))
  end

  def write_trimmed(parent_path, filename)
    write_csv(parent_path, filename, db.values)
  end

  def write_results(parent_path, filename, cols)
    # write empty files if necessary
    write_redundant
    write_deleted
    #
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
        csv << new_row.map { |el| (el[1].nil? ? '' : el[1]) }
      end
    end
    logger.info "Finished writing #{filename}."
  end

  def write_fasta_files
    fasta_files = gather_fasta
    #
    fasta_files.keys.each do |fasta_db|
      write_fasta_each(fasta_db, :nt, :aligned, Reporting::FILE_FASTA_NT, fasta_files)
      write_fasta_each(fasta_db, :aa, :aligned, Reporting::FILE_FASTA_AA, fasta_files)
      #
      write_fasta_each(fasta_db, :nt, :db, Reporting::FILE_FASTA_NT, fasta_files)
      write_fasta_each(fasta_db, :aa, :db, Reporting::FILE_FASTA_AA, fasta_files)
    end
  end

  protected

  #
  # write each fasta file method (will be called for nt and aa)
  def write_fasta_each(fasta_db, type, origin, filename, fasta_files)
    File.open(File.join(@fasta_dir,
                        origin.to_s + '_' + fasta_db.to_s + '_' + filename),
              'wb',
              col_sep: "\t") do |fid|
      fid.write fasta_files[fasta_db][type][origin].join('')
    end
    logger.info "Finished writing #{origin}-#{filename}."
  end

  #
  # method that processes all rows in csv
  #  and does so in NUM_TREADS
  def gather_fasta
    #
    fasta_files = {}
    values.each do |line|
      #
      fasta_files[line['db']] = \
        { nt: { aligned: [], db: [] }, aa: { aligned: [], db: [] } } \
        if fasta_files[line['db']].nil?
      #
      #
      #
      seqid = "#{line['sseqid']}-#{line['db']}-#{line['qseqid']}"
      #
      #
      nt_a_l = line['nt_aligned_longest_orf']
      fasta_files[line['db']][:nt][:aligned] << \
        Bio::Sequence.auto(nt_a_l)
          .output(:fasta, header: seqid) if nt_a_l.length > 0
      #
      aa_a_l = line['aa_aligned_longest_orf']
      fasta_files[line['db']][:aa][:aligned] << \
        Bio::Sequence.auto(aa_a_l)
          .output(:fasta, header: seqid) if aa_a_l.length > 0
      #
      #
      nt_d_l = line['nt_db_longest_orf']
      fasta_files[line['db']][:nt][:db] << \
        Bio::Sequence.auto(nt_d_l)
          .output(:fasta, header: seqid) if nt_d_l.length > 0
      #
      aa_d_l = line['aa_db_longest_orf']
      fasta_files[line['db']][:aa][:db] << \
        Bio::Sequence.auto(aa_d_l)
          .output(:fasta, header: seqid) if aa_d_l.length > 0
      #
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
