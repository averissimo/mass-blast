require 'logger'
require 'yaml'

class Blast

  DEFAULT_OPTIONS = "-dust no -max_target_seqs 500 -evalue 1E-100"
  DEFAULT_FORMAT  = "6"
  DEFAULT_TASK    = "blastn"
  DEFAULT_OUTPUT_DIR = "out"
  DEFAULT_OUTPUT_EXT   = ".out"

  #
  #
  # logger getter
  def log() @logger end

  #
  #
  # initialize class with all necessary data
  def initialize(dbs, db_parent=nil, query_parent=nil, task=nil, opts=nil, outfmt=nil, out_dir=nil)
    # create logger object
    @logger = Logger.new(STDOUT)
    @logger.level = Logger::INFO

    # load config file
    @config = YAML.load_file('config.yml')
    log.debug("loaded config.yml file")
    log.debug( @config.inspect )

    # parent directories for query and blast db
    @query_parent = get_config( query_parent, @config["query_parent"], Dir.pwd )
    @db_parent    = get_config( db_parent,    @config["db_parent"],    Dir.pwd )

    # set existing dbs
    @dbs = dbs
    log.info("loads databases (from directory '#{query_parent}'): " + @dbs.join(", "))

    # optional arguments
    @opts    = get_config( opts,    @config["opts"],             DEFAULT_OPTIONS )
    @task    = get_config( task,    @config["task"],             DEFAULT_TASK )
    @outfmt  = get_config( outfmt,  @config["format"]["outfmt"], DEFAULT_FORMAT )
    @out_dir = get_config( out_dir, @config["output"]["dir"],    DEFAULT_OUTPUT_DIR )
    @out_ext = get_config( out_dir, @config["output"]["ext"],    DEFAULT_OUTPUT_EXT )

    # create output dir if does not exist
    begin
      Dir.mkdir @out_dir unless Dir.exists? (@out_dir)
    rescue
      log.error( msg = "Could not create output directory" )
      error msg
    end

    # outfmt specifiers for the blast query (we choose all)
    @outfmt_spec    = @config["format"]["specifiers"].keys
    # outfmt specifiers details to add to the report's second line
    @outfmt_details = @config["format"]["specifiers"].values

  end

  #
  #
  # run individual query file
  def blastn(qfile, db, out_file, query_parent=nil, db_parent=nil)
    query_parent = @query_parent if query_parent.nil?
    db_parent    = @db_parent if db_parent.nil?

    # create command for this call
    cmd = "blastn -query \"#{File.join(query_parent,qfile)}\" -db \"#{db}\" #{@opts} -out #{out_file} -outfmt \"#{@outfmt} #{@outfmt_spec.join(" ")}\""
    log.info "running '#{qfile}' with database '#{db}' that will store in '#{out_file}'"
    log.debug cmd
    output = `BLASTDB="#{db_parent}" #{cmd}` # actual call to blast
    log.debug output
  end

  #
  #
  def blastn_folders( folders, query_parent=nil, db_parent=nil )
    query_parent = @query_parent if query_parent.nil?
    # create new queue to add all operations
    call_queue = Queue.new
    list = []

    # run through each directory
    folders.each do |query|
      # go through all queries in each directory
      list << Dir[ File.join(query_parent, query, "*.query") ].each do |query_file|

        # run query against all databases
        @dbs.each do |db|
          new_item = {}
          new_item[:qfile]    = query_file
          new_item[:db]       = db
          new_item[:out_file] = gen_filename( query, query_file, db )
          new_item[:query_parent] = "" # empty, because it will already have the prefix
          new_item[:db_parent] = db_parent
          call_queue << new_item
        end

      end
    end

    # logging messages
    log.info "Going to run queries: " + list.flatten.join(", ")
    log.info "Calling blastn..."

    until call_queue.empty?
      el = call_queue.pop
      blastn( el[:qfile], el[:db], el[:out_file], el[:query_parent], el[:db_parent] )
    end

    log.info "Success!!"

  end

  #
  #
  # Generate filenames for each of the query's output
  def gen_filename(prefix, query, db)
    name = query.gsub(/[\S]+\//, "").gsub(/[\.]query/,"").gsub( /[ ]/, "_" )
    list = []
    list << @task
    list << prefix unless prefix.nil?
    list << name
    list << db
    File.join( @out_dir, list.join("-") + @out_ext )
  end

  #
  #
  # Generate a report from all the outputs
  def gen_report_from_output
    # find all output files
    outs = Dir[File.join( @out_dir, "*#{@out_ext}" )]

    # open report.csv to write
    File.open File.join( @out_dir, "report.csv" ), 'w' do |fw|
      # get header columns and surounded by \"
      header = ["file", @outfmt_spec].flatten.map{|el| "\"#{el}\""}
      detail = ["means the file origin of this line", @outfmt_details].flatten.map{|el| "\"#{el}\""}

      fw.puts header.join "\t" # adds header columns
      fw.puts detail.join "\t" # adds explanation of header columns

      log.info "written header lines to report (#{header.size} columns)"

      # for each output, add one or more lines
      outs.each do |file|
        File.open file, "r" do |f|
          data = f.read
          if data.empty? # in case the blast has no hits
            fw.puts file
          else
            # other wise replace the beggining of the line with
            #  the output file name to identify each output
            fw.puts data.gsub(/^(.|\n|\r)/, "#{file}\t\\1")
          end
        end
      end
    end
    log.info "generated '#{File.join(@out_dir,"report.csv")}' from " + outs.size.to_s + " files"
    log.debug "report was built from: " + outs.join(", ")

  end


 #             _            _
 #            (_)          | |
 #  _ __  _ __ ___   ____ _| |_ ___
 # | '_ \| '__| \ \ / / _` | __/ _ \
 # | |_) | |  | |\ V / (_| | ||  __/
 # | .__/|_|  |_| \_/ \__,_|\__\___|
 # | |
 # |_|

  private

  #
  #
  # get default value
  def get_config(user_var, yml_var, default)
    if user_var.nil?
      yml_var.nil? ? default : yml_var
    else
      user_var
    end
  end

end # end of class
