module Vendor::NexusParser
  # Raises on error
  def self.document_id_to_nexus(doc_id)
    nexus_doc = Document.find(doc_id)
    document_to_nexus(nexus_doc)
  end

  # Raises on error
  def self.document_to_nexus(doc)
    f = File.read(doc.document_file.path)
    nf = parse_nexus_file(f)

    assign_gap_names(nf)

    validate_character_states(nf.characters)

    nf
  end

  def self.validate_character_states(characters)
    characters.each_with_index do |c, i|
      # It shouldn't be possible to have duplicate state labels (right?) since
      # they're assigned sequentially, but nexus_parser does allow duplicate
      # state names, which TW does not.
      state_names = c.states.map { |k, v| v.name }
      dup_names = find_duplicates(state_names)
      if dup_names.present?
        dups = dup_names.join(', ')
        raise TaxonWorks::Error, "TaxonWorks character names must be unique for a given descriptor - duplicate name(s): '#{dups}' detected for character #{i + 1}: '#{c.name}'"

        return false
      end
    end

    true
  end

  # Assign a name to all gap states - nexus_parser outputs gap states that have
  # no name, but TW requires a name.
  def self.assign_gap_names(nf)
    gap_label = nf&.vars[:gap]
    if gap_label.nil?
      return nf
    end

    nf.characters.each do |c|
      if c.state_labels.include? gap_label
        c.states[gap_label].name = gap_name_for_states(c.states)
      end
    end

    nf
  end

  def self.gap_name_for_states(states)
    # TW state names must be unique (for a given descriptor) - since we're
    # arbitrarily assigning the gap name, it's on us to make sure it's unique.
    state_names = states.map { |k, v| v.name }
    if !state_names.include?('gap')
      return 'gap'
    else
      i = 1
      while i < 1000 && state_names.include?("gap_#{i}")
        i = i + 1
      end
      return "gap#{i}"
    end
  end

  def self.find_duplicates(arr)
    # https://stackoverflow.com/a/786976
    s = Set.new
    dups = Set.new
    arr.each { |o| dups.add(o) unless s.add?(o) }

    dups.to_a
  end

end
