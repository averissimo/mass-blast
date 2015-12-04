#
#
#
module Reporting
  #
  #
  # Generate a report from all the outputs
  def gen_report_from_output
    # find all output files
    outs = Dir[File.join(@out_dir, "*#{@out_ext}")]

    # open report.csv to write
    File.open File.join(@out_dir, 'report.csv'), 'w' do |fw|
      # get header columns and surounded by \"
      header = ['file', @outfmt_spec].flatten.map { |el| "\"#{el}\"" }
      detail = ['means the file origin of this line', @outfmt_details]
               .flatten.map { |el| "\"#{el}\"" }

      fw.puts header.join "\t" # adds header columns
      fw.puts detail.join "\t" # adds explanation of header columns

      log.info "written header lines to report (#{header.size} columns)"

      # for each output, add one or more lines
      outs.each do |file|
        prepend_name_in_file(file, fw)
      end
    end
    log.info "generated '#{File.join(@out_dir, 'report.csv')}' from " +
      outs.size.to_s + ' files'
    log.debug 'report was built from: ' + outs.join(', ')
  end

  #
  # prepend name of file in each line
  def prepend_name_in_file(file, fw)
    File.open file, 'r' do |f|
      data = f.read
      if data.empty? # in case the blast has no hits
        fw.puts file if @verbose_out
      else
        # other wise replace the beggining of the line with
        #  the output file name to identify each output
        fw.puts data.gsub(/^(.|\n|\r)/, "#{file}\t\\1")
      end
    end
  end
end
