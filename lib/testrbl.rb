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
  PATTERN = /^(\S+):(\d+)$/

  def self.run_from_cli(argv)
    file, line = extract_file_and_line!(argv)
    if file && line
      pattern = pattern_from_file(File.readlines(file), line)
      argv << file
      argv << "-n"
      argv << "/#{pattern}/"
    end

    run_tests(argv)
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

  def self.extract_file_and_line!(argv)
    argv.each_with_index do |arg, i|
      if arg =~ PATTERN && File.file?($1)
        argv.delete_at(i)
        return $1, $2
      end
    end
    nil
  end

  def self.run_tests(argv)
    require "bundler/setup" if File.file?("Gemfile")
    require "test/unit"

    runner = Test::Unit::AutoRunner.new(true)
    if runner.process_args(argv)
      exit runner.run
    else
      abort runner.options.banner + " tests..."
    end
  end

  # fix 1.9 not being able to load local files
  def self.localize(file)
    file =~ /^[-a-z\d_]/ ? "./#{file}" : file
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
