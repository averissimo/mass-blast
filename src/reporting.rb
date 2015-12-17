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
  REDUNDANT_FILENAME = 'redundant.csv'
  DISCARDED_FILENAME = 'discarded.csv'
  #
  NUM_THREADS = 5
  #
  #
  # Generate a report from all the outputs
  def gen_report_from_output
    # find all output files
    outs = Dir[File.join(@store.output.dir, "*#{@store.output.extension}")]

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
      "'#{File.join(@store.output.dir, REPORT_FILENAME)}' from " +
      outs.size.to_s + ' files'
    logger.debug 'report was built from: ' + outs.join(', ')
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
                     nt_longest_orf_frame1 aa_longest_orf_frame1
                     nt_longest_orf_frame2 aa_longest_orf_frame2
                     nt_longest_orf_frame3 aa_longest_orf_frame3)
    aux_header.concat row.fields
    aux_header.concat ['means number of results for this contig ' \
      'with less identity',
                       'means nucleotide alignment from db',
                       'means aminoacid alignment from db',
                       'means longest nucleotide orf in read frame1 alignment',
                       'means longest aminoacid orf in read frame1 alignment',
                       'means longest nucleotide orf in read frame2 alignment',
                       'means longest aminoacid orf in read frame2 alignment',
                       'means longest nucleotide orf in read frame3 alignment',
                       'means longest aminoacid orf in read frame3 alignment']
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
    # save CSVs
    #
    #
    CSV.open(File.join(@store.output.dir, TRIMMED_FILENAME), 'wb') do |csv|
      # add header and second line explaining header to the csv
      csv << header
      csv << aux_header
      #
      process_db(db, csv)
    end
    logger.info "finished writing #{TRIMMED_FILENAME}"
    #
    CSV.open(File.join(@store.output.dir, DISCARDED_FILENAME), 'wb') do |csv|
      deleted.each { |row| csv << row }
    end
    #
    CSV.open(File.join(@store.output.dir, REDUNDANT_FILENAME), 'wb') do |csv|
      redundant.each { |row| csv << row }
    end
    logger.info "finished writing #{REDUNDANT_FILENAME}" \
      " and #{DISCARDED_FILENAME}"
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
          logger.info("item \##{el[:index]} being processed :)")
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
    result.each do |line|
      csv << line
    end
    csv
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
    orf = ORF.new(spliced, @store.orf.to_hash)
    #
    row['nt_longest_orf_frame1'] = orf.nt[:frame1]
    row['aa_longest_orf_frame1'] = orf.aa[:frame1]
    row['nt_longest_orf_frame2'] = orf.nt[:frame2]
    row['aa_longest_orf_frame2'] = orf.aa[:frame2]
    row['nt_longest_orf_frame3'] = orf.nt[:frame3]
    row['aa_longest_orf_frame3'] = orf.aa[:frame3]
    row
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