require 'csv'
require 'bio'
require_relative 'orf'
#
#
#
module Reporting
  #
  REPORT_FILENAME    = 'report.csv'
  TRIMMED_FILENAME   = 'trimmed.csv'
  RESULTS_FILENAME   = 'results.csv'
  REDUNDANT_FILENAME = 'redundant.csv'
  DISCARDED_FILENAME = 'discarded.csv'
  FASTA_NT_FILENAME  = 'nt_longest_orfs.fasta'
  FASTA_AA_FILENAME  = 'aa_longest_orfs.fasta'
  #
  NUM_THREADS = 5
  #
  #
  # Generate a report from all the outputs
  def gen_report_from_output
    # find all output files
    outs = Dir[File.join(@store.output.dir,
                         @store.output.blast_results,
                         "*#{@store.output.extension}")]

    # open report.csv to write
    File.open File.join(@store.output.dir, REPORT_FILENAME), 'w' do |fw|
      # get header columns and surounded by \"
      header = ['file', 'task', 'folder', 'file_name', 'db',
                @store.format.specifiers.keys]
               .flatten.map { |el| "\"#{el}\"" }
      #
      detail = ['means the file origin of this line']
      detail << 'means the task used'
      detail << 'means the folder of origin from the query'
      detail << 'means the query filename'
      detail << 'means the database of the result'
      detail << @store.format.specifiers.values
      detail = detail.flatten.map { |el| "\"#{el}\"" }

      fw.puts header.join "\t" # adds header columns
      fw.puts detail.join "\t" # adds explanation of header columns

      logger.info "written header lines to report (#{header.size} columns)"

      # for each output, add one or more lines
      outs.each do |file|
        prepend_name_in_file(file, fw)
      end
    end
    logger.info 'generated ' \
      "'#{File.join(@store.output.dir.gsub(FileUtils.pwd + File::Separator, ''),
                    REPORT_FILENAME)}'" \
        ' from ' +
      outs.size.to_s + ' files'
    logger.debug 'report was built from: ' + outs.join(', ')
  rescue StandardError => e
    logger.progname = logger.progname + ' - Error'
    logger.fatal e.message
    exit
  end

  #
  # prepend name of file in each line
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

  def generate_headers(row, header, aux_header)
    header.concat row.headers
    header.concat %w(contig_count nt_aligned_seq aa_aligned_seq
                     nt_orf_frame1  nt_orf_frame1_len
                     aa_orf_frame1  aa_orf_frame1_len
                     nt_orf_frame2  nt_orf_frame2_len
                     aa_orf_frame2  aa_orf_frame2_len
                     nt_orf_frame3  nt_orf_frame3_len
                     aa_orf_frame3  aa_orf_frame3_len
                     nt_orf_frame-1 nt_orf_frame-1_len
                     aa_orf_frame-1 aa_orf_frame-1_len
                     nt_orf_frame-2 nt_orf_frame-2_len
                     aa_orf_frame-2 aa_orf_frame-2_len
                     nt_orf_frame-3 nt_orf_frame-3_len
                     aa_orf_frame-3 aa_orf_frame-3_len
                     nt_longest_orf nt_longest_orf_len
                     aa_longest_orf aa_longest_orf_len)
    aux_header.concat row.fields
    verbose_explanation = proc do |type, frame, is_len|
      "means #{is_len ? 'length of ' : ''}longest #{type} " \
        "on read frame#{frame} alignment"
    end
    aux_header.concat \
      [
        'means number of results for this contig with less identity',
        'means nucleotide alignment from db',
        'means amino-acid alignment from db'
      ]
    #
    [1, 2, 3, -1, -2, -3].each do |el|
      aux_header.concat [verbose_explanation.call('nucleotide', el, false),
                         verbose_explanation.call('nucleotide', el, true),
                         verbose_explanation.call('amino-acid', el, false),
                         verbose_explanation.call('amino-acid', el, true)]
    end
    aux_header.concat ['means longest nucleotide orf in alignment',
                       'means length of longest nucleotide orf in alignment',
                       'means longest amino-acid orf in alignment',
                       'means length of longest amino-acid orf in alignment']
  end

  #
  #
  def prune_results
    filepath = File.join(@store.output.dir, REPORT_FILENAME)
    csv_text = File.read filepath
    #
    db = {}
    redundant  = []
    deleted    = []
    skip_first = true
    header     = []
    aux_header = []
    CSV.parse(csv_text, headers: true, col_sep: "\t") do |row|
      # skip also second line
      if skip_first
        skip_first = false
        generate_headers(row, header, aux_header)
      else
        # remove duplicate by: sseqid
        process_row(row, 'sseqid', db, redundant, deleted)
      end
    end
    #
    if @store.key?('prune_identical') && @store.prune_identical.size > 0
      @store.prune_identical.each do |prune_col|
        db = posterior_filter(prune_col, db, redundant)
      end
    end
    # save CSVs
    #
    #
    fasta_files = nil
    CSV.open(File.join(@store.output.dir, TRIMMED_FILENAME),
             'wb',
             col_sep: "\t") do |csv|
      # add header and second line explaining header to the csv
      csv << header
      csv << aux_header
      #
      fasta_files = process_db(db, csv)
    end
    logger.info "finished writing #{TRIMMED_FILENAME}"
    include_headers = %w(task folder file_name db
                         qseqid evalue pident qcovs
                         sseqid
                         contig_count
                         nt_aligned_seq aa_aligned_seq
                         nt_longest_orf nt_longest_orf_len
                         aa_longest_orf aa_longest_orf_len)
    csv_r = CSV.read(File.join(@store.output.dir, TRIMMED_FILENAME),
                     'rb',
                     headers: true,
                     col_sep: "\t")
    csv_r.headers.each do |col_name|
      csv_r.delete col_name unless include_headers.include?(col_name)
    end
    CSV.open(File.join(@store.output.dir, RESULTS_FILENAME),
             'wb',
             col_sep: "\t") do |csv|
      csv << csv_r.headers
      csv_r.each do |row|
        csv << row
      end
    end
    #
    fasta_files.keys.each do |fasta_db|
      File.open(File.join(@store.output.dir,
                          @store.output.fastas,
                          fasta_db.to_s + '_' + FASTA_NT_FILENAME),
                'wb',
                col_sep: "\t") do |fid|
        fid.write fasta_files[fasta_db][:nt].join("\n")
      end
      #
      File.open(File.join(@store.output.dir,
                          @store.output.fastas,
                          fasta_db.to_s + '_' + FASTA_AA_FILENAME),
                'wb',
                col_sep: "\t") do |fid|
        fid.write fasta_files[fasta_db][:aa].join("\n")
      end
    end
    #
    CSV.open(File.join(@store.output.dir,
                       @store.output.intermediate,
                       DISCARDED_FILENAME),
             'wb',
             col_sep: "\t") do |csv|
      csv << header
      csv << aux_header
      deleted.each { |row| csv << row }
    end
    #
    CSV.open(File.join(@store.output.dir,
                       @store.output.intermediate,
                       REDUNDANT_FILENAME),
             'wb',
             col_sep: "\t") do |csv|
      csv << header
      csv << aux_header
      redundant.each { |row| csv << row }
    end
    logger.info "finished writing #{REDUNDANT_FILENAME}" \
      " and #{DISCARDED_FILENAME}"
  rescue StandardError => e
    logger.progname = logger.progname + ' - Error'
    logger.fatal e.message
    exit
  end

  #
  # method that processes all rows in csv
  #  and does so in NUM_TREADS
  def process_db(db, csv)
    logger.info "processing through #{db.values.size} rows"
    # create syncronized queue with all items
    queue = Queue.new
    db.values.each_with_index do |item, i|
      queue << { item: item, index: i }
    end
    # spreads the work in NUM_THREADS
    threads = []
    NUM_THREADS.times.each do
      threads << Thread.new do
        result = []
        until queue.size == 0
          el = queue.pop
          logger.debug("item \##{el[:index]} being processed :)")
          result << process_item(el[:item])
        end
        result
      end
    end
    # joins all threads, waiting for all to be finished
    result = []
    threads.each do |thr|
      # add the result of each tread to the csv document
      thr.value.each do |el|
        result << el
      end
    end
    result.sort_by! do |line|
      [line['file'], line['pident'], line['qcovs'], line['sseqid']]
    end
    fasta_files = {}
    result.each do |line|
      csv << line
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

  #
  # process all information for a row
  def process_item(item)
    row = item[:row]
    spliced = get_nt_seq_from_blastdb(row['sseqid'],
                                      row['db'],
                                      row['sstart'],
                                      row['send'],
                                      row['sframe'])
    row['contig_count']   = item[:count]
    row['nt_aligned_seq'] = spliced.to_s
    row['aa_aligned_seq'] = spliced.translate.to_s
    #
    orf = ORFFinder.new(spliced, @store.orf.to_hash, logger)
    #
    add_row_proc = proc do |frame|
      direction  = (frame > 0 ? :direct : :reverse)
      common_str = "longest_orf_frame#{frame}"
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
    arr = frames.collect do |el|
      add_row_proc.call(el)
    end
    max_idx = arr.rindex(arr.max)
    row['nt_longest_orf']     = row["nt_longest_orf_frame#{frames[max_idx]}"]
    row['nt_longest_orf_len'] = row['nt_longest_orf'].size
    row['aa_longest_orf']     = (if row['nt_longest_orf'].empty?
                                   ''
                                 else
                                   row['nt_longest_orf'].translate
                                 end)
    row['aa_longest_orf_len'] = row['aa_longest_orf'].size
    row
  end

  def posterior_filter(col_id, db, redundant)
    new_db = {}
    db.values.each do |val|
      posterior_filter_each(col_id, val[:row], val[:count], redundant, new_db)
    end
    new_db
  end

  # TODO: be integrated with pident search
  #
  def posterior_filter_each(col_id, row, count, redundant, new_db)
    #
    db_id = "#{row[col_id]}_#{row['db']}"
    new_pident = Float(row['pident'])
    #
    cur_pident = \
      new_db[db_id].nil? ? nil : Float(new_db[db_id][:row]['pident'])
    # if row has valid identity
    if cur_pident
      # add to redudant array the previous row or the current
      redundant << (new_pident > cur_pident ? new_db[db_id][:row] : row)
      # increases count by one
      new_db[db_id][:count] += new_db[db_id][:count]
      # does not replace row if identity is not bigger than current one
      return false if new_pident <= cur_pident
    end
    # start the count if it is the first contig
    new_db[db_id] = { count: count } if new_db[db_id].nil?
    # if it reaches here, then the row has a better identity
    #  than the previous (or there were no contigs before in db)
    new_db[db_id][:row] = row
    true
  end

  #
  # Checks:
  #  - if identity is above the configuration threshold
  #  - only keeps the highest identity for each contig/database
  #     pair
  #   - counts same contigs/database pairs
  def process_row(row, col_id, db, redundant, deleted)
    # failsafe if row is nil
    return false if row[col_id].nil? ||
                    row[col_id].empty? ||
                    row[col_id] == 'nil'
    # uniqueness is made of a pair contig/database
    db_id = row[col_id] + '_' + row['db']
    new_pident = Float(row['pident'])
    # if it does not pass the threshold, it will be added
    #  to deleted file, and discard any further processing
    if new_pident < @store.identity_threshold
      deleted << row
      return false
    end
    cur_pident = db[db_id].nil? ? nil : Float(db[db_id][:row]['pident'])
    # if row has valid identity
    if cur_pident
      # add to redudant array the previous row or the current
      redundant << (new_pident > cur_pident ? db[db_id][:row] : row)
      # increases count by one
      db[db_id][:count] += 1
      # does not replace row if identity is not bigger than current one
      return false if new_pident <= cur_pident
    end
    # start the count if it is the first contig
    db[db_id] = { count: 1 } if db[db_id].nil?
    # if it reaches here, then the row has a better identity
    #  than the previous (or there were no contigs before in db)
    db[db_id][:row] = row
    # lazy load to memory blastdb only db that are necessary
    load_blastdb_item(row['db'])
    true
  end
end
