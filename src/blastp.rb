require_relative 'blast'
#
#
class Blastp < Blast
  #
  def my_type
    'prot'
  end

  # blastn blast
  def blast(qfile, db, out_file, query_parent = nil)
    query_parent = @store.query.parent if query_parent.nil?
    #
    qfile = File.join(query_parent, qfile) \
      unless qfile.start_with?(query_parent)
    # create command for this call
    cmd = "blastp -query \"#{qfile}\"" \
          " -db \"#{db}\""                \
          " #{@store.opts}"                                     \
          " -out #{out_file}"                                   \
          " -outfmt \"#{@store.format.outfmt}"                  \
          " #{@store.format.specifiers.keys.join(' ')}\""
    cmd
  end
end
