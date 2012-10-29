require 'testrbl/version'

module Testrbl
  PATTERNS = [
    /^(\s+)(should|test|it)\s+['"](.*)['"]\s+do\s*$/,
    /^(\s+)(context)\s+['"]?(.*?)['"]?\s+do\s*$/,
    /^(\s+)def\s+(test_)([a-z_\d]+)\s*$/
  ]

  # copied from minitest
  MINITEST_NAME_RE = if RUBY_VERSION >= "1.9"
    Regexp.new("[^[[:word:]]]+")
  else
    /\W+/u
  end

  INTERPOLATION = /\\\#\\\{.*?\\\}/

  def self.run_from_cli(argv)
    i_test, file, line = detect_usable(argv)
    if file and line
      file = localize(file)
      run "#{ruby} #{i_test}#{file} -n '/#{pattern_from_file(File.readlines(file), line)}/'"
    elsif file
      run "#{ruby} #{i_test}#{file}"
    elsif argv.all?{|f| File.file?(f) } # testrb has a lot of weird issues vs test-unit, so try to avoid it
      run "#{ruby} #{argv.map{|f| "-r #{localize(f)}" }.join(" ")} -e ''"
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
    argv = argv.dup # do not mess up args
    i_test = "-Itest " if ((argv.delete("-I") and argv.delete("test")) or argv.delete("-Itest"))

    return unless argv.size == 1

    if argv.first =~ /^(\S+):(\d+)$/
      [i_test, $1, $2]
    elsif File.file?(argv.first)
      [i_test, argv.first, false]
    end
  end

  def self.ruby
    if File.file?("Gemfile")
      "ruby -rbundler/setup" # faster then bundle exec ruby
    else
      "ruby"
    end
  end

  def self.run(command)
    command = [*command]
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
