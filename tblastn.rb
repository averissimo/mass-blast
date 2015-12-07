require_relative 'blast'
#
#
class TBlastn < Blast
  # extend Blast main class
  DEF_OPTIONS = '-dust no -max_target_seqs 500 -evalue 1E-100'
  DEF_FORMAT  = '6'
  DEF_TASK    = 'tblastn'

  def initialize(*args)
    super(*args)
    @opts    = get_config(@config['opts'], DEF_OPTIONS)
    @task    = get_config(@config['task'], DEF_TASK)
    @outfmt  = get_config(@config['format']['outfmt'], DEF_FORMAT)
  end

  #
  # blastn blast
  def blast(qfile, db, out_file, query_parent = nil, db_parent = nil)
    query_parent = @query_parent if query_parent.nil?
    db_parent    = @db_parent if db_parent.nil?
    # create command for this call
    cmd = "tblastn -query \"#{File.join(query_parent, qfile)}\" -db \"#{db}\""
    cmd += " #{@opts} -out #{out_file}"
    cmd += " -outfmt \"#{@outfmt} #{@outfmt_spec.join(' ')}\""
    logger.info "running '#{qfile}' with database '#{db}' that will \
      store in '#{out_file}'"
    logger.debug cmd
    output = `BLASTDB="#{db_parent}" #{cmd}` # actual call to blast
    logger.debug output
  end

  #
end
