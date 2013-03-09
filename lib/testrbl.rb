require 'testrbl/version'

module Testrbl
  PATTERNS = [
    /^(\s+)(should|test|it)\s+['"](.*)['"]\s+do\s*(?:#.*)?$/,
    /^(\s+)(context)\s+['"]?(.*?)['"]?\s+do\s*(?:#.*)?$/,
    /^(\s+)def\s+(test_)([a-z_\d]+)\s*(?:#.*)?$/
  ]

  # copied from minitest
  MINITEST_NAME_RE = if RUBY_VERSION >= "1.9"
    Regexp.new("[^[[:word:]]]+")
  else
    /\W+/u
  end

  INTERPOLATION = /\\\#\\\{.*?\\\}/

  def self.run_from_cli(argv)
    options, file, line = detect_usable(argv)

    if file and line
      file = localize(file)
      run(ruby + options + [file, "-n", "/#{pattern_from_file(File.readlines(file), line)}/"])

    elsif file
      run(ruby + [file] + options)

    # TODO use parse
    elsif argv.all? { |f| File.file?(f) } # multiple files without arguments
      run(ruby + argv.map { |f| "-r#{localize(f)}" } + ["-e", ""])

    else # pass though
      # no bundle exec: projects with mini and unit-test do not run well via bundle exec testrb
      run ["testrb"] + argv
    end
  end

  # useable e.g. via zeus
  def self.pattern_from_file(lines, line)
    search = lines[0..(line.to_i-1)].reverse

    last_spaces = " " * 100
    found = search.map{|line| pattern_from_line(line) }.compact
    patterns = found.select do |spaces, name|
      last_spaces = spaces if spaces.size < last_spaces.size
    end.map(&:last)

    use = []
    found_final = false
    patterns.each do |pattern|
      is_final = pattern.end_with?("$")
      next if is_final && found_final
      found_final = is_final
      use << pattern
    end

    return use.reverse.join(".*") if found.size > 0

    raise "no test found before line #{line}"
  end

  private

  # fix 1.9 not being able to load local files
  def self.localize(file)
    file =~ /^[-a-z\d_]/ ? "./#{file}" : file
  end

  def self.detect_usable(argv)
    files, options = partition_argv(argv)

    return unless files.size == 1

    if files.first =~ /^(\S+):(\d+)$/
      [options, $1, $2]
    elsif File.file?(files.first)
      [options, files.first, false]
    end
  end

  def self.partition_argv(argv)
    next_is_option = false
    argv.partition do |arg|
      if next_is_option
        next_is_option = false
      else
        if arg =~ /^-.$/ or  arg =~ /^--/ # single letter option followed by argument like -I test or long options like --verbose
          next_is_option = true if ["-I", "-r", "-n"].include?(arg)
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

  def self.pattern_from_line(line)
    PATTERNS.each do |r|
      next unless line =~ r
      whitespace, method, test_name = $1, $2, $3
      return [whitespace, pattern_from_match(method, test_name)]
    end
    nil
  end

  def self.pattern_from_match(method, test_name)
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
