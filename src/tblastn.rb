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
    cmd = "BLASTDB=\"#{db_parent}\""                              \
          " tblastn -query \"#{File.join(query_parent, qfile)}\"" \
          " -db \"#{db}\""                                        \
          " #{@store.opts}"                                       \
          " -out #{out_file}"                                     \
          " -outfmt \"#{@store.format.outfmt}"                    \
          " #{@store.format.specifiers.keys.join(' ')}\""
    cmd
  end

  #
end
