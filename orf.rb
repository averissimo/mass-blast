require 'logger'
require 'bio'
#
#
#
class ORF
  #
  DEFAULT_OPTIONS = { start: %w(atg),
                      stop:  %w(tag taa tga),
                      reverse: true,
                      direct: true,
                      min: 6,
                      default_to_seq: false,
                      debug: false }

  attr_reader :logger, :options, :seq, :sequence
  attr_writer :options

  def longest
    find if @orf.nil?
    res = { frame1: nil, frame2: nil, frame3: nil }
    @orf.each do |key, val|
      res[key] = get_range(val[:longest])
    end
    res
  end

  def aa
    find if @orf.nil?
    res = longest
    res.each do |key, val|
      res[key] = val.translate
    end
    res
  end

  def nt
    find if @orf.nil?
    longest
  end

  def initialize(sequence, options = {})
    sequence = Bio::Sequence::NA.new(sequence) if sequence.class == String
    @sequence = sequence
    @seq = @sequence.to_s
    #
    self.options = DEFAULT_OPTIONS.merge(options.nil? ? {} : options)
    @logger      = Logger.new(STDOUT)
    if options[:debug]
      logger.level = Logger::INFO
    else
      logger.level = Logger::UNKNOWN
    end
  end
  #
  # For a given sequence, find longest ORF
  #

  def self.find(sequence, options = {})
    # merge options with default
    orf = ORF.new(sequence, options)
    @result = orf.find
    #
  end

  #
  #
  #
  def find
    return sequence if sequence.nil? || sequence.size == 0
    #
    start_idx = lookup_codons_idx(:start)
    stop_idx  = lookup_codons_idx(:stop)
    res = get_longest(start_idx, stop_idx, seq.size, [0, 1, 2])
    logger.info "start codons idx: #{start_idx}"
    logger.info "stop codons idx: #{stop_idx}"
    logger.info res
    @orf = { frame1: {}, frame2: {}, frame3: {} }
    # iterate over each frame and range to return the
    #  longest above the minimum sequence length
    # these are the preferences:
    #  1: range that has start and stop codons
    #  2: range that only has start/stop
    #  3: full sequence
    res.each_with_index do |frame, index|
      frame_val = []
      frame_fal = []
      frame.each do |range|
        if range[:fallback]
          frame_fal << range
        else
          frame_val << range
        end
      end
      hash_name = "frame#{index + 1}".to_sym
      @orf[hash_name][:orfs] = (frame_val.empty? ? frame_fal : frame_val)
      longest = { len: nil, range: nil }
      @orf[hash_name][:orfs].each do |range|
        len = range[:stop] - range[:stop] + 1
        if longest[:range].nil? || len > longest[:len]
          longest[:len]   = len
          longest[:range] = range
        end
      end
      @orf[hash_name][:longest] = longest[:range]
    end
    #
    if options[:debug]
      @orf.each do |key, frame|
        frame[:orfs].each do |range|
          print_range(key, range)
        end
      end
    end
    #
    @orf
  end

  private

  def get_range(arg1, arg2 = nil)
    if arg2.nil?
      start = arg1[:start]
      stop = arg1[:stop]
    else
      start = arg1
      stop = arg2
    end
    Bio::Sequence::NA.new(get_range_str(start, stop))
  end

  def get_range_str(start, stop)
    seq[start..stop]
  end

  #
  # auxiliary method that prints range
  #
  def print_range(key, range)
    # simple proc to add spaces, works as auxiliary
    #  method to print range
    add_spaces = proc do |str|
      str.gsub(/(.{1})/, '\1 ').strip
    end

    orf = add_spaces.call(get_range_str(range[:start], range[:stop]))
    pre = if range[:start] == 0
            ''
          else
            add_spaces.call(get_range_str(0, range[:start] - 1))
          end
    suf = if range[:end] == seq.size - 1
            ''
          else
            add_spaces.call(get_range_str(range[:stop] + 1, seq.size - 1))
          end
    #
    sep = '|'
    str = "#{key}: #{pre}#{sep}#{orf}#{sep}#{suf}"
    str += ' : ' \
      "size=#{seq[range[:start]..range[:stop]].size}"
    str += ' (fallback)' if range[:fallback]
    logger.info str
  end

  #
  # Find all indexes for valid codons (either for :start
  #  or :stop)
  def lookup_codons_idx(option_name)
    idxs = []
    option_name = option_name.to_sym
    # if start option does not exist, then should
    #  treat start of sequence as the start
    if options[option_name] && !options[option_name].empty?
      # iterate over all start codons to see which
      #  is best
      options[option_name].each do |codon|
        temp_idxs = []
        until (new_idx = \
          seq.index(codon,
                    (temp_idxs.empty? ? 0 : temp_idxs.last + 1))).nil?
          temp_idxs << new_idx
        end
        idxs << temp_idxs
      end
    end
    idxs.flatten.sort.collect do |idx|
      if option_name == :start
        idx + 3
      elsif option_name == :stop
        idx - 1
      end
    end
  end

  #
  # get indexes only from a given frame
  # because of a bug the start flag must be given
  #  indicating if it is looking for start or stop
  #  codons in frame
  def get_frame_idxs(idxs, frame, start = true)
    idxs.collect do |i|
      if start && (i - frame) % 3 == 0
        i
      elsif !start && (i + 1 - frame) % 3 == 0
        i
      end
    end.compact
  end

  #
  # from the combination of start and stop indexes, find
  #  the longest one
  def decide_longest(start_idxs, stop_idxs, frame, seq_size)
    #
    seq_size -= (seq_size - frame) % 3
    start = start_idxs.clone
    stop  = stop_idxs.clone
    stop << seq_size - 1 if stop_idxs.empty?
    start << frame if start_idxs.empty?
    #
    if options[:debug]
      logger.info "frame: #{frame}"
      logger.info "  start: #{start} | stop :#{stop}"
      logger.info "  seq size: #{seq_size}"
      logger.info "  #{seq[frame..seq_size]}"
    end
    #
    valid = []
    fallback = []
    # iterate on each start codon
    start.each do |pos_start|
      # iterate on each stop codon
      stop.each do |pos_stop|
        # ignore if start is bigger than stop index
        next if pos_start >= pos_stop
        # add a fall back where starts from begining
        fallback << { start: frame, stop: pos_stop, fallback: true } \
          if (pos_stop - frame) >= options[:min]
        # ignore if size of orf is smaller than minimum
        next if (pos_stop - pos_start + 1) < options[:min]
        # if all conditions hold add as valid orf
        if !start_idxs.empty? || !stop_idxs.empty?
          valid << { start: pos_start, stop:  pos_stop, fallback: false }
        end
      end
      fallback << { start: pos_start, stop: seq_size - 1, fallback: true } \
        if (seq_size - 1 - pos_start) >= options[:min]
    end
    valid = fallback.uniq if valid.empty?
    logger.info 'no ORF with start and stop codons,' \
      ' defaulting to fallback' if valid.empty?
    valid
  end

  def get_longest(start_idx, stop_idx, seq_size, read_frame = [0, 1, 2])
    #
    start = [[], [], []]
    stop  = [[], [], []]
    valid = []
    read_frame.each do |frame|
      start[frame] = get_frame_idxs(start_idx, frame, true)
      stop[frame]  = get_frame_idxs(stop_idx, frame,  false)
      valid << decide_longest(start[frame], stop[frame],
                              frame, seq_size)
    end
    #
    valid
  end
end
