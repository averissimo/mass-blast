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
                      min: 6 }
  #

  def self.find_idx(seq, idx, option_name, cmp_sign, fallback_value, options)
    option_name = option_name.to_sym
    # if start option does not exist, then should
    #  treat start of sequence as the start
    if options[option_name] && !options[option_name].empty?
      # iterate over all start codons to see which
      #  is best
      options[option_name].each do |codon|
        # must add +1 to index, as splice method
        #  takes position [1, end] instead of [0, end]
        #  as ruby string methods
        temp_idx = seq.index(codon)
        next if temp_idx.nil?
        temp_idx += 1 # due to difference in indexes
        # only take new idx if it is really better
        if cmp_sign == '<'
          idx = temp_idx if temp_idx < idx
        elsif cmp_sign == '>'
          idx = temp_idx if temp_idx > idx
        end
      end
    else
      # default position if no start option is the beggining
      idx = fallback_value
    end
    idx
  end

  def self.lookup_codons_idx(seq, option_name, options)
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
  def self.find2(sequence, options)
    sequence = Bio::Sequence::NA.new(sequence) if sequence.class == String
    return sequence if sequence.nil? || sequence.size == 0
    # string should be more efficient
    seq = sequence.to_s
    #
    options[:seq] = seq
    #
    start_idx = lookup_codons_idx(seq, :start, options)
    stop_idx  = lookup_codons_idx(seq, :stop, options)
    puts "start codons idx: #{start_idx}"
    puts "stop codons idx: #{stop_idx}"
    res = get_longest(start_idx, stop_idx, [0, 1, 2], seq.size, options)
    puts res
    res.each do |frame|
      frame.each do |range|
        str = ''
        str += "#{seq[range[:start]..range[:stop]]}" + '#'
        str += '#:#' \
          "size=#{seq[range[:start]..range[:stop]].size}"
        puts str
      end
    end
    res
  end

  def self.get_frame_idxs(idxs, frame, start = true)
    idxs.collect do |i|
      if start && (i - frame) % 3 == 0
        i
      elsif !start && (i + 1 - frame) % 3 == 0
        i
      end
    end.compact
  end

  def self.decide_longest(start_idxs, stop_idxs, frame, seq_size, options)
    #
    seq_size -= (seq_size - frame) % 3
    start = start_idxs.clone
    stop  = stop_idxs.clone
    stop << seq_size - 1 if stop_idxs.empty?
    start << frame if start_idxs.empty?
    #
    puts "frame: #{frame}"
    puts "  start: #{start} | stop :#{stop}"
    puts "  seq size: #{seq_size}"
    puts "  #{options[:seq]}"
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
        puts "  adding #{fallback.last} as fallback #{frame}..#{pos_stop}"
        # ignore if size of orf is smaller than minimum
        next if (pos_stop - pos_start) < options[:min]
        # if all conditions hold add as valid orf
        if !start_idxs.empty? || !stop_idxs.empty?
          valid << { start: pos_start, stop:  pos_stop }
        end
        puts "  adding #{valid.last} as valid"
      end
      fallback << { start: pos_start, stop: seq_size - 1, fallback: true } \
        if (seq_size - 1 - pos_start) >= options[:min]
      puts "  adding #{fallback.last} as fallback \#2 #{pos_start}..#{seq_size - 1}"
    end
    valid = fallback.uniq if valid.empty?
    valid
  end

  def self.get_longest(start_idx, stop_idx,
                       read_frame = [0, 1, 2], seq_size,
                       options)
    #
    start = [[], [], []]
    stop  = [[], [], []]
    valid = []
    read_frame.each do |frame|
      start[frame] = get_frame_idxs(start_idx, frame, true)
      stop[frame]  = get_frame_idxs(stop_idx, frame,  false)
      valid << decide_longest(start[frame], stop[frame],
                              frame, seq_size, options)
    end
    #
    valid
  end

  #
  def self.find(sequence, options)
    return sequence if sequence.nil? || sequence.size == 0
    # string should be more efficient
    seq = sequence.to_s
    # initialize best_start_idx to be at the end of
    #  sequence
    best_start_idx = sequence.size + 1
    best_start_idx = find_idx(seq, best_start_idx, :start, '<', 1, options)
    #
    # necessary if start codon is not found
    best_start_idx = 1 if best_start_idx == sequence.size + 1
    # after start is found, trim the sequence to remove the
    #  prefix and the start codon
    seq = seq[(best_start_idx + 2)..(seq.size - 1)]
    # best is before the first index
    best_end_idx = 0
    #
    best_end_idx = find_idx(seq,
                            best_end_idx,
                            :stop,
                            '>',
                            seq.size,
                            options) + best_start_idx + 3
    #
    if best_end_idx == 0
      best_end_idx = sequence.size
    else
      best_end_idx += 1 unless best_end_idx + 2 > sequence.size
    end
    orf_seq = sequence.splice "#{best_start_idx}..#{best_end_idx}"
    return '' if orf_seq.nil? || orf_seq.size < options[:min]
    orf_seq
  end

  # find longest orf according to options
  #  in config file
  # sequence is a Bio::Sequence::NT class
  def self.find_longest(sequence, options = DEFAULT_OPTIONS)
    sequence = Bio::Sequence::NA.new(sequence) if sequence.class == String
    #
    result = {}
    result[:nt] = find(sequence, options) if options[:direct]
    if options[:reverse]
      temp_orf = find(sequence.reverse, options)
      result[:nt].size if temp_orf.size > result[:nt].size
    end
    result[:aa] = if result[:nt] == ''
                    ''
                  else
                    result[:nt].translate
                  end
    result
  end
end
