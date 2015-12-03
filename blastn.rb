require './blast'
#
#
class Blastn < Blast
  #
  DEF_OPTIONS = '-dust no -max_target_seqs 500 -evalue 1E-100'
  DEF_FORMAT  = '6'
  DEF_TASK    = 'blastn'
  #
  def blast_me(*args)
    blastn(*args)
  end
  #

  def initialize
    super
    @opts    = get_config(@config['opts'], DEF_OPTIONS)
    @task    = get_config(@config['task'], DEF_TASK)
    @outfmt  = get_config(@config['format']['outfmt'], DEF_FORMAT)
  end

  private

  #
  # run individual query file
  def blastn(qfile, db, out_file, query_parent = nil, db_parent = nil)
    query_parent = @query_parent if query_parent.nil?
    db_parent    = @db_parent if db_parent.nil?
    # create command for this call
    cmd = "blastn -query \"#{File.join(query_parent, qfile)}\" -db \"#{db}\""
    cmd += " #{@opts} -out #{out_file}"
    cmd += " -outfmt \"#{@outfmt} #{@outfmt_spec.join(' ')}\""
    log.info "running '#{qfile}' with database '#{db}' that will \
      store in '#{out_file}'"
    log.debug cmd
    output = `BLASTDB="#{db_parent}" #{cmd}` # actual call to blast
    log.debug output
  end
end
