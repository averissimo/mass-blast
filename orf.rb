require 'bio'
#
#
#
class ORF
  #
  DEFAULT_OPTIONS = { start: %w(atg),
                      stop:  %w(tag, taa, tga),
                      reverse: true,
                      direct: true,
                      min: 0 }
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

  #
  def self.find(sequence, options)
    return sequence if sequence.size == 0
    # string should be more efficient
    seq = sequence.to_s
    # initi best_start_idx to be at the end of
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
