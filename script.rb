require_relative 'src/blastn'
require_relative 'src/tblastn'
require_relative 'src/tblastx'
require_relative 'src/blastp'
require_relative 'src/download'

require 'configatron'
#
#
def run_user_config
  # configuration
  config_path = File.expand_path((ARGV.empty? ? 'user.yml' : ARGV[0]))
  config = YAML.load_file(config_path)
  #
  b = nil
  #
  if config['separate_db']
    if config['db']['list'].nil? || config['db']['list'].empty?
      list_db = []
      #
      Dir[File.expand_path(File.join(config['db']['parent'], '*.nhr'),
                           config_path),
          File.expand_path(File.join(config['db']['parent'], '*.phr'),
                           config_path)].each do |item|
        no_ext = File.basename(item, File.extname(item))
        list_db << no_ext.gsub(/\.[0-9]+$/, '')
      end
    else
      list_db = config['db']['list']
    end
    # needs to make directories relative to tmp folder
    config['output']['dir']   = File.join('..', config['output']['dir'])
    config['db']['parent']    = File.join('..', config['db']['parent'])
    config['debug']['file']   = File.join('..', config['debug']['file'])
    config['query']['parent'] = File.join('..', config['query']['parent'])
    config['annotation_dir']  = File.join('..', config['annotation_dir'])
  else
    list_db = [-1]
  end
  #
  #
  list_db.each do |item|
    if item == -1
      new_config = ARGV[0]
    else
      # create a temporary older named tmp that holds the
      #  individual config files generated
      tmp_path = File.expand_path('tmp', File.dirname(config_path))
      Dir.mkdir(tmp_path) unless Dir.exist? tmp_path
      # output folder will be named with database as suffix
      if config['force_folder'].nil? || config['force_folder'].strip == ''
        output_folder = Time.now.strftime('%Y_%m_%d-%H_%M_%S') +
                        '-' + srand.to_s[3..6]
      else
        output_folder = config['force_folder']
      end
      # keep original to reset it, otherwise it will concatenate all
      output_folder_original = config['force_folder']
      # set output folder for this db
      output_folder += '-' + item
      # add .yml to config name
      new_config = File.join(tmp_path, output_folder + '.config.yml')
      # write change configuration to file, forcing only a single db
      File.open(new_config, 'wb') do |fw|
        config['db']['list']      = [item]
        config['force_folder']    = output_folder
        fw.write YAML.dump(config)
      end
      # reset name of folder to original
      config['force_folder'] = output_folder_original
    end
    #
    case config['engine']
    when 'tblastn'
      b = TBlastn.new(new_config)
    when 'blastn'
      b = Blastn.new new_config
    when 'tblastx'
      b = TBlastx.new new_config
    when 'blastp'
      b = Blastp.new new_config
    else
      fail "Cannot recognize engine: #{config['engine']}. Please check" \
          ' documentation for implemented engines'
    end
    # download taxdb from ncbi
    ExternalData.download(b.store.db.parent, TRUE)
    # blast folders
    b.blast_folders
    # generate report.csv
    b.gen_report_from_output
    # prune results
    b.prune_results
    #
    b.write_fasta
    # remove temporary file
    File.delete(new_config) unless item == -1
  end
end
#
run_user_config
