require_relative 'blast'
#
#
class TBlastn < Blast
  #
  # blastn blast
  def blast(qfile, db, out_file, query_parent = nil, db_parent = nil)
    query_parent = @store.query.parent if query_parent.nil?
    db_parent    = @store.db.parent if db_parent.nil?
    # create command for this call
    cmd = "tblastn -query \"#{File.join(query_parent, qfile)}\" -db \"#{db}\""
    cmd += " #{@store.opts} -out #{out_file}"
    cmd += " -outfmt \"#{@store.format.outfmt}"
    cmd += " #{@store.format.specifiers.keys.join(' ')}\""
    logger.info "running '#{qfile}' with database '#{db}' that will \
      store in '#{out_file}'"
    logger.debug cmd
    output = `BLASTDB="#{db_parent}" #{cmd}` # actual call to blast
    logger.debug output
  end

  #
end
