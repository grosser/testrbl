require 'testrbl/version'

module Testrbl
  PATTERNS = [
    /^(\s+)(should|test|it)\s+['"](.*)['"]\s+do\s*(?:#.*)?$/,
    /^(\s+)(context)\s+['"]?(.*?)['"]?\s+do\s*(?:#.*)?$/,
    /^(\s+)def\s+(test_)([a-z_\d]+)\s*(?:#.*)?$/
  ]

  OPTION_WITH_ARGUMENT = ["-I", "-r", "-n", "-e"]

  # copied from minitest
  MINITEST_NAME_RE = if RUBY_VERSION >= "1.9"
    Regexp.new("[^[[:word:]]]+")
  else
    /\W+/u
  end

  INTERPOLATION = /\\\#\\\{.*?\\\}/

  def self.run_from_cli(argv)
    files, options = partition_argv(argv)
    files = files.map { |f| localize(f) }
    load_options, options = partition_options(options)

    if files.size == 1 and files.first =~ /^(\S+):(\d+)$/
      file = $1
      line = $2
      run(ruby + load_options + [file, "-n", "/#{pattern_from_file(File.readlines(file), line)}/"] + options)
    else
      if files.all? { |f| File.file?(f) } and options.none? { |arg| arg =~ /^-n/ }
        run(ruby + load_options + files.map { |f| "-r#{f}" } + options + ["-e", ""])
      else # pass though
        # no bundle exec: projects with mini and unit-test do not run well via bundle exec testrb
        run ["testrb"] + argv
      end
    end
  end

  # usable via external tools like zeus
  def self.pattern_from_file(lines, line)
    possible_lines = lines[0..(line.to_i-1)].reverse

    last_spaces = " " * 100
    found = possible_lines.map { |line| test_pattern_from_line(line) }.compact

    # pattern and the groups it is nested under (like describe - describe - it)
    patterns = found.select do |spaces, name|
      last_spaces = spaces if spaces.size < last_spaces.size
    end.map(&:last)

    return filter_duplicate_final(patterns).reverse.join(".*") if found.size > 0

    raise "no test found before line #{line}"
  end

  # only keep 1 pattern that stops matching via $
  def self.filter_duplicate_final(patterns)
    found_final = 0
    patterns.reject { |p| p.end_with?("$") and (found_final += 1) > 1 }
  end

  private

  def self.partition_options(options)
    next_is_before = false
    options.partition do |option|
      if next_is_before
        next_is_before = false
        true
      else
        if option =~ /^-(r|I)/
          next_is_before = (option.size == 2)
          true
        else
          false
        end
      end
    end
  end

  # fix 1.9 not being able to load local files
  def self.localize(file)
    file =~ /^[-a-z\d_]/ ? "./#{file}" : file
  end

  def self.partition_argv(argv)
    next_is_option = false
    argv.partition do |arg|
      if next_is_option
        next_is_option = false
      else
        if arg =~ /^-.$/ or  arg =~ /^--/ # single letter option followed by argument like -I test or long options like --verbose
          next_is_option = true if OPTION_WITH_ARGUMENT.include?(arg)
          false
        elsif arg =~ /^-/ # multi letter option like -Itest
          false
        else
          true
        end
      end
    end
  end

  def self.ruby
    if File.file?("Gemfile")
      ["ruby", "-rbundler/setup"] # faster then bundle exec ruby
    else
      ["ruby"]
    end
  end

  def self.run(command)
    puts command.join(" ")
    STDOUT.flush # if exec fails horribly we at least see some output
    Kernel.exec *command
  end

  def self.test_pattern_from_line(line)
    PATTERNS.each do |r|
      next unless line =~ r
      whitespace, method, test_name = $1, $2, $3
      return [whitespace, test_pattern_from_match(method, test_name)]
    end
    nil
  end

  def self.test_pattern_from_match(method, test_name)
    regex = Regexp.escape(test_name).gsub("\\ "," ").gsub(INTERPOLATION, ".*")

    if method == "should"
      optional_test_name = "(?:\(.*\))?"
      regex = "#{method} #{regex}\. #{optional_test_name}$"
    elsif method == "test"
      # test "xxx -_ yyy"
      # test-unit:     "test: xxx -_ yyy"
      # activesupport: "test_xxx_-__yyy"
      regex = "^test(: |_)#{regex.gsub(" ", ".")}$"
    elsif method == "it"
      regex = "^test_\\d+_#{test_name}$"
    end

    regex.gsub("'", ".")
  end
end
