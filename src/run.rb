require_relative 'blastn'
require_relative 'tblastn'
require_relative 'tblastx'
require_relative 'blastp'
require_relative 'download'

require 'configatron'
require 'benchmark'
#
#
def run_user_config(my_config, benchmark = nil, run_blast = true, run_after_blast = true)
  # configuration
  config_path   = File.expand_path(my_config)
  config_parent = File.dirname(config_path)
  config        = YAML.load_file(config_path)
  #
  list_ary = []
  list_db = Queue.new
  #
  if config['separate_db']
    if config['db']['list'].nil? || config['db']['list'].empty?
      #
      db_parent = File.expand_path(config['db']['parent'], config_parent)
      #
      # run command blsatdbcmd to search for BLAST databases
      #  in directory
      Open3.popen3("blastdbcmd -list #{db_parent}") do |_i, o, _e, _t|
        o.each_line("\n") do |line|
          pair = line.split(/ (Nucleotide|Protein)\n/)
          list_ary << File.basename(pair[0]).gsub(/\.[0-9]+$/, '')
        end
      end
      list_ary = list_ary.uniq
    else
      config['db']['list'].each do |el|
        list_ary << el
      end
    end
    list_ary.each do |el|
      list_db << el
    end
    # needs to make directories relative to tmp folder
    relative_dir = proc do |path|
      File.expand_path(File.join(path), config_parent)
    end
    config['output']['dir']   = relative_dir.call(config['output']['dir'])
    config['db']['parent']    = relative_dir.call(config['db']['parent'])
    config['debug']['file']   = relative_dir.call(config['debug']['file'])
    config['query']['parent'] = relative_dir.call(config['query']['parent'])
    config['annotation_dir']  = relative_dir.call(config['annotation_dir'])
  else
    list_db << -1
  end
  #
  # if separte folder then use same time for all
  base_time = Time.now.strftime('%Y_%m_%d-%H_%M_%S')
  # array to store threads id
  threads = []
  # must be at least one thread
  config['use_threads'] = 1 \
    if config['use_threads'].nil? || config['use_threads'] < 1
  #
  config['use_threads'].times do
    threads << Thread.new do
      loop do
        # stop if list_db is empty
        Thread.exit if list_db.empty?
        #
        item = list_db.pop
        #
        if item == -1
          new_config_file = ARGV[0]
        else
          # create a temporary older named tmp that holds the
          #  individual config files generated
          tmp_path = File.expand_path('tmp', config_parent)
          Dir.mkdir(tmp_path) unless Dir.exist? tmp_path
          # deep copy of hash
          new_config = Marshal.load(Marshal.dump(config))
          # output folder will be named with database as suffix
          if new_config['force_folder'].nil? ||
             new_config['force_folder'].strip == ''
            output_folder = base_time +
                            '-' + srand.to_s[3..6]
          else
            output_folder = new_config['force_folder']
          end
          # set output folder for this db
          output_folder += '_' + item
          # add .yml to config name
          new_config_file = File.join tmp_path, "#{output_folder}.config.yml"
          # write change configuration to file, forcing only a single db
          File.open(new_config_file, 'wb') do |fw|
            new_config['db']['list']      = [item]
            new_config['force_folder']    = output_folder

            if new_config['use_threads'] > 1
              new_config['debug']['file'] = \
                new_config['debug']['file'].gsub(/[.]txt/, '') + \
                '.thread.' + item + '.txt'
            end
            fw.write YAML.dump(new_config)
          end
        end
        #
        begin
          run_blast(new_config_file, new_config['engine'], benchmark,
                    run_blast, run_after_blast)
        rescue StandardError => e
          puts e.to_s
        end
        # remove temporary file
        File.delete(new_config_file) unless item == -1
      end
    end
  end
  # wait for all threads to finish
  threads.map(&:join)
end

def run_blast(new_config, engine, benchmark = nil, run_blast = true, run_after_blast = true)
  #
  case engine
  when 'tblastn'
    b = TBlastn.new new_config
  when 'blastn'
    b = Blastn.new new_config
  when 'tblastx'
    b = TBlastx.new new_config
  when 'blastp'
    b = Blastp.new new_config
  else
    fail "Cannot recognize engine: #{engine}. Please check" \
        ' documentation for implemented engines'
  end
  #
  # download taxdb from ncbi
  ExternalData.download(b.store.db.parent, TRUE)
  # either run a normal run or with benchmarks
  if benchmark.nil?
    # blast folders
    b.blast_folders if run_blast
    #
    if run_after_blast
      # generate report.csv
      b.gen_report_from_output
      # prune results
      b.prune_results
      #
      b.write_fasta
    end
  else
    logger = Logger.new \
      "#{b.store.output.dir}/log.benchmark.txt"
    #
    logger.info 'Starting Benchmark'
    #
    bm = Benchmark.bm(benchmark, 'total:', 'average:') do |x|
      if run_blast
        tb = x.report('blast:') { b.blast_folders } # blast folders
      else
        tb = 0
      end
      #
      if run_after_blast
        tp = x.report('proc.:') do
          b.gen_report_from_output # generate report.csv
          b.prune_results          # find redundand and unecessary results
          b.write_fasta            # write fasta files
        end
      else
        tp = 0
      end
      [tb + tp, (tb + tp) / 2]
    end
    db_info = b.db_information
    query_info = b.query_information
    db_bases = 0
    db_seqs  = 0
    db_info.each do |db_el|
      db_bases += db_el[:bases]
      db_seqs += db_el[:sequences]
    end
    logger.info "         bases in DBs: #{db_bases}"
    logger.info "     sequences in DBs: #{db_seqs}"
    logger.info "     bases in queries: #{query_info[:base]}"
    logger.info " sequences in queries: #{query_info[:sequences]}"
    logger.info '                   user     system      total        real'
    bm.each do |bm_el|
      logger.info "  #{bm_el.label} #{bm_el.format}".gsub(/\n|\r/, '')
    end
  end
end
