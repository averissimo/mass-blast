require_relative 'blast'
#
#
class Blastn < Blast
  #
  # blastn blast
  def blast(qfile, db, out_file, query_parent = nil, db_parent = nil)
    query_parent = @store.query.parent if query_parent.nil?
    db_parent    = @store.db.parent if db_parent.nil?
    #
    qfile = File.join(query_parent, qfile) \
      unless qfile.start_with?(query_parent)
    # create command for this call
    cmd = "blastn -query \"#{qfile}\"" \
          " -db \"#{File.join(db_parent, db)}\""                \
          " #{@store.opts}"                                     \
          " -out #{out_file}"                                   \
          " -outfmt \"#{@store.format.outfmt}"                  \
          " #{@store.format.specifiers.keys.join(' ')}\""
    cmd
  end
end
