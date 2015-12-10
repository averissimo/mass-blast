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
  #
  # Generate a report from all the outputs
  def gen_report_from_output
    # find all output files
    outs = Dir[File.join(@out_dir, "*#{@out_ext}")]

    # open report.csv to write
    File.open File.join(@out_dir, REPORT_FILENAME), 'w' do |fw|
      # get header columns and surounded by \"
      header = ['file', 'task', 'folder', 'file_name', 'db', @outfmt_spec]
               .flatten.map { |el| "\"#{el}\"" }
      #
      detail = ['means the file origin of this line']
      detail << 'means the task used'
      detail << 'means the folder of origin from the query'
      detail << 'means the query filename'
      detail << 'means the database of the result'
      detail << @outfmt_details
      detail = detail.flatten.map { |el| "\"#{el}\"" }

      fw.puts header.join "\t" # adds header columns
      fw.puts detail.join "\t" # adds explanation of header columns

      logger.info "written header lines to report (#{header.size} columns)"

      # for each output, add one or more lines
      outs.each do |file|
        prepend_name_in_file(file, fw)
      end
    end
    logger.info "generated '#{File.join(@out_dir, REPORT_FILENAME)}' from " +
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
        fw.puts file if @verbose_out
      else
        # other wise replace the beggining of the line with
        #  the output file name to identify each output
        fw.puts data.gsub(/^(.|\n|\r)/, "#{filename}\t#{str}\t\\1")
      end
    end
  end

  #
  #
  def prune_results
    filepath = File.join(@out_dir, REPORT_FILENAME)
    csv_text = File.read filepath
    #
    db = {}
    redundant = []
    deleted   = []
    skip_first = 1
    header = nil
    aux_header = nil
    CSV.parse(csv_text, headers: true, col_sep: "\t") do |row|
      # skip also second line
      if skip_first > 0
        skip_first -= 1
        header = row.headers
        header << 'contig_count'
        header << 'nt_aligned_seq'
        header << 'aa_aligned_seq'
        header << 'nt_longest_orf'
        header << 'aa_longest_orf'
        header << 'peptide'
        aux_header = row.fields
        aux_header << 'means number of results for this contig with less identity'
        aux_header << 'means nucleotide alignment from db'
        aux_header << 'means aminoacid alignment from db'
        aux_header << 'means longest nucleotide orf in alignment'
        aux_header << 'means longest aminoacid orf in alignment'
        aux_header << 'means peptide alignment'
        next
      end
      # remove duplicate by: sseqid
      process_row(row, 'sseqid', db, redundant, deleted)
    end
    # save CSVs
    CSV.open(File.join(@out_dir, TRIMMED_FILENAME), 'wb') do |csv|
      csv << header
      csv << aux_header
      #
      db.values.each do |item|
        row = item[:row]
        spliced = get_nt_seq_from_blastdb(row['sseqid'],
                                          row['db'],
                                          row['sstart'],
                                          row['send'])
        row['contig_count']   = item[:count]
        row['nt_aligned_seq'] = spliced.to_s
        row['aa_aligned_seq'] = spliced.translate.to_s
        # orf = find_longest_orf(row['sseq'])
        orf = ORF.find_longest(spliced, @orf)
        row['nt_longest_orf'] = orf[:nt]
        row['a_longest_orf']  = orf[:aa]
        csv << row
      end
    end
    #
    CSV.open(File.join(@out_dir, DISCARDED_FILENAME), 'wb') do |csv|
      deleted.each { |row| csv << row }
    end
    #
    CSV.open(File.join(@out_dir, REDUNDANT_FILENAME), 'wb') do |csv|
      redundant.each { |row| csv << row }
    end
  end

  def process_row(row, col_id, db, redundant, deleted)
    db_id = row[col_id] + '_' + row['db']
    new_pident = Float(row['pident'])
    # does not pass the threshold to be added to db
    if new_pident < @identity_threshold
      deleted << row
      return false
    end
    cur_pident = db[db_id].nil? ? nil : Float(db[db_id][:row]['pident'])
    # if identy is bigger than
    if cur_pident
      redundant << (new_pident > cur_pident ? db[db_id][:row] : row)
      db[db_id][:count] += 1
      return false if new_pident <= cur_pident
    end
    db[db_id] = { count: 1 } if db[db_id].nil?
    db[db_id][:row] = row # change to new line
    true
  end


end
