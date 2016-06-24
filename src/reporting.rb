require 'csv'
require 'bio'
require 'orf'
require_relative 'results_db'

#
#
#
module Reporting
  #
  FILE_REPORT    = 'report.csv'
  FILE_TRIMMED   = 'trimmed.csv'
  FILE_RESULTS   = 'results.csv'
  FILE_REDUNDANT = 'redundant.csv'
  FILE_DISCARDED = 'discarded.csv'
  #
  FILE_FASTA_NT  = 'nt_longest_orfs.fasta'
  FILE_FASTA_AA  = 'aa_longest_orfs.fasta'
  #
  RESULTS_HEADERS = %w(engine folder file_name db
                       qseqid evalue pident qcovs
                       sseqid
                       contig_count
                       nt_aligned_seq aa_aligned_seq
                       nt_db_seq aa_db_seq
                       nt_db_longest_orf nt_db_longest_orf_len
                       aa_db_longest_orf aa_db_longest_orf_len)
                       #
                       # ORF calculated from aligned sequence is not kept in results
                       # aa_aligned_longest_orf aa_aligned_longest_orf_len
                       # nt_aligned_longest_orf nt_aligned_longest_orf_len
  #
  attr_accessor :db
  #
  def initialize(config_path)
    @db = ResultsDB.new @store.identity.min,
                        @store.identity.max,
                        File.join(@store.output.dir,
                                  @store.output.intermediate),
                        File.join(@store.output.dir,
                                  @store.output.fastas),
                        @store.prune_identical.key?('use_worst') \
                          && @store.prune_identical.use_worst,
                        logger
    @results_headers = RESULTS_HEADERS
    super()
  end

  #                _     _ _
  #               | |   | (_)
  #    _ __  _   _| |__ | |_  ___
  #   | '_ \| | | | '_ \| | |/ __|
  #   | |_) | |_| | |_) | | | (__
  #   | .__/ \__,_|_.__/|_|_|\___|
  #   | |
  #   |_|

  #
  #
  # Generate a report from all the files from the Blast calls
  def gen_report_from_output
    # find all output files
    outs = Dir[File.join(@store.output.dir,
                         @store.output.blast_results,
                         "*#{@store.output.extension}")]

    # open report.csv to write
    File.open File.join(@store.output.dir, FILE_REPORT), 'w' do |fw|
      # get header columns and surounded by \"
      header = ['file', 'engine', 'folder', 'file_name', 'db',
                @store.format.specifiers.keys]
               .flatten.map { |el| "\"#{el}\"" }
      #
      detail = ['means the file origin of this line']
      detail << 'means the engine used'
      detail << 'means the folder of origin from the query'
      detail << 'means the query filename'
      detail << 'means the database of the result'
      detail << @store.format.specifiers.values
      detail = detail.flatten.map { |el| "\"#{el}\"" }

      fw.puts header.join "\t" # adds header columns
      fw.puts detail.join "\t" # adds explanation of header columns

      # for each output, add one or more lines
      outs.each do |file|
        prepend_name_in_file(file, fw)
      end
    end
    logger.info 'Generated ' \
      "'#{File.join(@store.output.dir.gsub(FileUtils.pwd + File::Separator, ''),
                    FILE_REPORT)}'" \
        ' from ' + outs.size.to_s + ' BLAST output files'
    logger.debug 'Report was built from: '
    outs.each do |el|
      logger.debug "  - #{el}"
    end
  rescue StandardError => e
    logger.progname = logger.progname + ' - Error'
    logger.fatal e.message
    @fatal_logger.fatal e
    exit
  end

  #
  #
  # From all results start filtering according to the options
  #  given by the user, i.e. remove all:
  #  - Rows that have an identity below the threshold
  #  - Identical lines that have the same pair of column and database
  def prune_results
    #
    read_csv

    logger.info "Processing results from '#{FILE_REPORT}' file"
    #
    # build from report csv the database of results
    build_db
    #
    # remove rows that share the same information
    if @store.key?('prune_identical') &&
       @store.prune_identical.key?('list') &&
       @store.prune_identical.list.size > 0
      #
      @store.prune_identical.list.each do |prune_col|
        db.remove_identical(prune_col)
      end
    end
    #
    # add annotation_dir
    merge_annotation
    #
    # save CSVs
    #
    # write trimmed file
    db.write_trimmed(@store.output.dir, FILE_TRIMMED)
    logger.info "finished writing #{FILE_TRIMMED}"
    #
    db.write_results(@store.output.dir, FILE_RESULTS, @results_headers)
  rescue StandardError => e
    logger.progname = logger.progname + ' - Error'
    logger.fatal e.message
    @fatal_logger.fatal e
    exit
  end

  def write_fasta
    db.write_fasta_files
  end

  def merge_annotation
    annot_files = Dir[File.join(@store.annotation_dir, '*.csv')]
    annot_files.each_with_index do |file, index|
      merge_csv file, index
    end
  end

  #               _            _
  #              (_)          | |
  #    _ __  _ __ ___   ____ _| |_ ___
  #   | '_ \| '__| \ \ / / _` | __/ _ \
  #   | |_) | |  | |\ V / (_| | ||  __/
  #   | .__/|_|  |_| \_/ \__,_|\__\___|
  #   | |
  #   |_|

  #
  # each row of the csv file, and get some information:
  #  - number of identical rows detected in process
  #  - aligned nucleotide and amino-acid sequence
  #  - longest orf overall and for each reading frame
  def process_item(item)
    row = item.row
    new_seq = get_nt_seq_from_blastdb(row['sseqid'],
                                      row['db'],
                                      row['sstart'],
                                      row['send'],
                                      row['sframe'])
    #
    spliced = new_seq[:spliced]
    db_seq  = Bio::Sequence.auto(new_seq[:seq])
    seq = Bio::Sequence.auto(spliced)
    if seq.moltype == Bio::Sequence::AA && seq.size > 0
      row['nt_aligned_seq'] = ''
      row['aa_aligned_seq'] = spliced.to_s
      row['nt_db_seq'] = ''
      row['aa_db_seq'] = db_seq.to_s
      # [:start_codon, :stop_codon].each do |type_codon|
      #   codon_table[type_codon] = codon_table[type_codon].collect do |el|
      #     Bio::Sequence::NA.new(el).translate(1, @store.codon_table)
      #   end.uniq
      # end
      return row
    end
    #
    row['nt_aligned_seq'] = spliced.to_s
    row['aa_aligned_seq'] = spliced.translate.to_s
    row['nt_db_seq']      = db_seq.to_s
    row['aa_db_seq']      = db_seq.translate.to_s
    #
    { aligned: spliced.to_s, db: db_seq.to_s }.each do |key, orf_to_search|
      orf = ORFFinder.new(orf_to_search, @store.codon_table, @store.orf.to_hash,
                          logger)
      #
      add_row_proc = proc do |frame|
        direction  = (frame > 0 ? :direct : :reverse)
        common_str = "#{key}_longest_orf_frame#{frame}"
        frame_sym  = "frame#{frame.abs}".to_sym
        row["nt_#{common_str}"]     = orf.nt[direction][frame_sym]
        row["nt_#{common_str}_len"] = row["nt_#{common_str}"].size
        row["aa_#{common_str}"]     = orf.aa[direction][frame_sym]
        row["aa_#{common_str}_len"] = row["aa_#{common_str}"].size
        #
        row["nt_#{common_str}"].size
      end
      #
      frames = [+1, +2, +3, -1, -2, -3]
      arr = frames.collect { |el| add_row_proc.call(el) }
      max_idx = arr.rindex(arr.max)
      row["nt_#{key}_longest_orf"]     = row["nt_#{key}_longest_orf_frame#{frames[max_idx]}"]
      row["nt_#{key}_longest_orf_len"] = row["nt_#{key}_longest_orf"].size
      row["aa_#{key}_longest_orf"]     = (if row["nt_#{key}_longest_orf"].empty?
                                            ''
                                          else
                                            row["nt_#{key}_longest_orf"].translate
                                          end)
      row["aa_#{key}_longest_orf_len"] = row["aa_#{key}_longest_orf"].size
    end
    row
  end

  def merge_csv(file, index)
    added = false
    my_headers = []
    CSV.foreach(file, headers: true, col_sep: "\t") do |row|
      unless added
        my_headers = (row.headers[2..(row.headers.size)]).collect do |str|
          str + "_annot_#{index}"
        end
        @results_headers.concat my_headers
      end
      added = true
      @db.add_info({ one: row.headers[0], two: row.headers[1] },
                   { one: row[0], two: row[1] },
                   my_headers,
                   row.values_at[2..(row.headers.size)],
                   my_headers.collect { file })
    end
  end
  #
  #
  # Add calculated headers from Blast results
  def add_headers
    #
    verbose_explanation = proc do |type, frame, is_len|
      "means #{is_len ? 'length of ' : ''}longest #{type} " \
        "on read frame#{frame} alignment"
    end
    #
    db.header.concat \
      %w(contig_count)
    db.header_meaning.concat \
      ['means number of results for this contig with less identity']
    #
    db.header.concat %w(nt_aligned_seq aa_aligned_seq nt_db_seq aa_db_seq)
    #
    db.header_meaning.concat \
      ['means nucleotide alignment from db',
       'means amino-acid alignment from db',
       'means nucleotide full sequence from db',
       'means amino-acid full sequence from db']
    #
    %w(aligned db).each do |str|
      db.header.concat \
        ["nt_#{str}_longest_orf_frame+1", "nt_#{str}_longest_orf_frame+1_len",
         "aa_#{str}_longest_orf_frame+1", "aa_#{str}_longest_orf_frame+1_len",
         "nt_#{str}_longest_orf_frame+2", "nt_#{str}_longest_orf_frame+2_len",
         "aa_#{str}_longest_orf_frame+2", "aa_#{str}_longest_orf_frame+2_len",
         "nt_#{str}_longest_orf_frame+3", "nt_#{str}_longest_orf_frame+3_len",
         "aa_#{str}_longest_orf_frame+3", "aa_#{str}_longest_orf_frame+3_len",
         "nt_#{str}_longest_orf_frame-1", "nt_#{str}_longest_orf_frame-1_len",
         "aa_#{str}_longest_orf_frame-1", "aa_#{str}_longest_orf_frame-1_len",
         "nt_#{str}_longest_orf_frame-2", "nt_#{str}_longest_orf_frame-2_len",
         "aa_#{str}_longest_orf_frame-2", "aa_#{str}_longest_orf_frame-2_len",
         "nt_#{str}_longest_orf_frame-3", "nt_#{str}_longest_orf_frame-3_len",
         "aa_#{str}_longest_orf_frame-3", "aa_#{str}_longest_orf_frame-3_len",
         "nt_#{str}_longest_orf",         "nt_#{str}_longest_orf_len",
         "aa_#{str}_longest_orf",         "aa_#{str}_longest_orf_len"]
    end
    #
    %w(aligned db).each do |str|
      [+1, +2, +3, -1, -2, -3].each do |el|
        db.header_meaning.concat \
          [verbose_explanation.call("nucleotide from #{str}", el, false),
           verbose_explanation.call("nucleotide from #{str}", el, true),
           verbose_explanation.call("amino-acid from #{str}", el, false),
           verbose_explanation.call("amino-acid from #{str}", el, true)]
      end
      db.header_meaning.concat \
        ["means longest nucleotide orf from #{str} in alignment",
         "means length of longest nucleotide orf from #{str} in alignment",
         "means longest amino-acid orf from #{str} in alignment",
         "means length of longest amino-acid orf from #{str} in alignment"]
    end
  end

  #
  # read report file
  def read_csv
    # read csv
    logger.info 'Loading report to memory...'
    csv_filename = File.join(@store.output.dir, FILE_REPORT)
    # skip second line of csv, as it has the meanings
    count = 0 # counter for number of lines being processed
    # parse the report results and generate
    #
    col_id = @store.prune_identical.first # removes the first and uses
                                          #  it as col_id
    #
    File.open(csv_filename).each do |line|
      row = line.gsub(/"|\n/, '').split("\t")
      if db.header.empty?
        db.header = row
        next
      elsif db.header_meaning.empty?
        db.header_meaning = row
        next
      end
      #
      new_item = Hash[db.header.zip row]
      # remove duplicate by: sseqid
      count += 1 unless new_item['pident'].nil?
      db.add("#{new_item[col_id]}_#{new_item[DB::BLAST_DB]}", new_item)
    end
    GC.start
    logger.info '  rows in report file:' \
      " #{count}"
  end

  #
  #
  # from the csv file of the report, it builds the database of results
  #  for prunnig (/filtering)
  def build_db
    #
    GC.start # remove csv_text from memory
    #
    db.blast_dbs.each do |k, v|
      load_blastdb_item(k, v.uniq)
      GC.start # remove csv_text from memory
    end
    #
    db.values.each do |item|
      process_item(item)
    end
    #
    add_headers
  end

  #
  # prepend to the csv file the filename of the query
  #  that originated the line, breaking down by '#' character
  def prepend_name_in_file(file, fw)
    filename = File.basename(file)
    str = filename.gsub(/#/, "\t").gsub(/\.out/, '')
    File.open file, 'r' do |f|
      data = f.read
      if data.empty? # in case the blast has no hits
        fw.puts file if @store.verbose_out
      else
        # other wise replace the beggining of the line with
        #  the output file name to identify each output
        fw.puts data.gsub(/^(.|\n|\r)/, "#{filename}\t#{str}\t\\1")
      end
    end
  end
end
