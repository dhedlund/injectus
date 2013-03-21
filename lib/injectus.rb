require 'injectus/dl'
require 'injectus/yarv_sequence'

module Injectus
  DEBUG = true
  YARV_DEBUG = false #= 'cache.yaml'

  YARV_CACHE = 'cache.yarv'

  REQ_STR, FEATURES, DEPS = 0, 1, 2

  def self.capture_dep_tree
    require_stack = [[nil, nil, []]]
    depth = 0
    orig_count = $LOADED_FEATURES.count

    Kernel.class_eval do
      alias_method :__injectus_orig_require, :gem_original_require

      define_method(:gem_original_require) do |path|
        puts "#{'  '*depth}#{path}"

        current = [path, nil, []]
        require_stack[depth][DEPS] << current
        require_stack.push(current)
        depth += 1

        if (sneaky_devils = $LOADED_FEATURES.slice(orig_count..-1)).any?
          # these are most likely `autoload`s, nothing we can do about 'em
          #sneaky_devils.each {|f| puts "FEATURE_SNUCK_IN: #{f}" }
          orig_count = $LOADED_FEATURES.count
        end

        loaded = __injectus_orig_require(path)

        if (new_features = $LOADED_FEATURES.slice(orig_count..-1)).any?
          new_features.each {|f| puts "#{'  '*depth}-> #{f}" }
          orig_count = $LOADED_FEATURES.count
        end

        current[FEATURES] = new_features.reverse

        require_stack.pop
        depth -= 1

        loaded
      end
    end

    yield

    Kernel.class_eval do
      alias_method :gem_original_require, :__injectus_orig_require
      remove_method :__injectus_orig_require
    end

    require_stack[0]
  end

  def self.compile_dep_tree(dep_tree, acc = [])
    features = (dep_tree[FEATURES]||[]).select {|f| f =~ /\.rb$/}.map do |path|
      [path, RubyVM::InstructionSequence.compile_file(path).to_a]
    end

    acc.push [dep_tree[REQ_STR], features] if features.any?

    dep_tree[DEPS].select {|d| d[REQ_STR] !~ /\.so$/}.each {|d| compile_dep_tree(d, acc)}

    acc
  end

  def self.humanify_stack(dep_tree)
    {
      'name'         => dep_tree[REQ_STR],
      'features'     => dep_tree[FEATURES],
      'dependencies' => dep_tree[DEPS].map {|d| humanify_stack(d)}
    }
  end

  def self.capture(&block)
    puts "STARTING WITH: #{$LOADED_FEATURES.count}" if DEBUG

    return inject(block) if File.exist?(YARV_CACHE)

    dep_tree = capture_dep_tree do; yield; end
    ordered = compile_dep_tree(dep_tree)
    ordered.shift
    File.open(YARV_CACHE, 'wb') {|f| f.write Marshal.dump(ordered) }

    if YARV_DEBUG
      require 'yaml'
      dep_tree = humanify_stack(dep_tree)
      File.open(YARV_DEBUG, 'wb') {|f| f.write YAML.dump(dep_tree) }
    end

    puts "COMPLETED AT: #{$LOADED_FEATURES.count}" if DEBUG

    return YARV_CACHE
  end

  def self.inject(block)
    requires = File.open(YARV_CACHE, 'rb') {|f| Marshal.load(f) }
    req_name, features = requires.shift

    Kernel.class_eval do
      alias_method :__injectus_orig_require, :gem_original_require

      define_method(:gem_original_require) do |path|
        if path == req_name
          orig_features = features
          req_name, features = requires.shift
          orig_features.each do |fpath,seq_a|
            RubyVM::InstructionSequence.load_a(seq_a).eval
            $LOADED_FEATURES << fpath
          end
          false
        else
          if loaded = __injectus_orig_require(path)
          end
        end
      end
    end

    block.call

#   Kernel.class_eval do
#     alias_method :gem_original_require, :__injectus_orig_require
#     remove_method :__injectus_orig_require
#   end

    puts "COMPLETED AT: #{$LOADED_FEATURES.count}" if DEBUG
  end

end
