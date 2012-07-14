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
    command = argv.join(" ")
    if command =~ /^\S+:\d+$/
      file, line = argv.first.split(':')
      file = "./#{file}" if file =~ /^[a-z]/ # fix 1.9 not being able to load local files
      run "#{bundle_exec}ruby #{file} -n '/#{pattern_from_file(File.readlines(file), line)}/'"
    elsif File.file?(command)
      run "#{bundle_exec}ruby #{command}"
    else # pass though
      # no bundle exec: projects with mini and unit-test do not run well via bundle exec testrb
      run "testrb #{argv.map{|a| a.include?(' ') ? "'#{a}'" : a }.join(' ')}"
    end
  end

  private

  def self.bundle_exec
    "bundle exec " if File.file?("Gemfile")
  end

  def self.run(command)
    puts command
    exec command
  end

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

  def self.pattern_from_line(line)
    PATTERNS.each do |r|
      if line =~ r
        whitespace, method, test_name = $1, $2, $3
        regex = Regexp.escape(test_name).gsub("'",".").gsub("\\ "," ").gsub(INTERPOLATION, ".*")

        if method == "should"
          optional_test_name = "(?:\(.*\))?"
          regex = "#{method} #{regex}\. #{optional_test_name}$"
        elsif method == "test"
          # test "xxx -_ yyy"
          # test-unit:     "test: xxx -_ yyy"
          # activesupport: "test_xxx_-__yyy"
          regex = "^test(: |_)#{regex.gsub(" ", ".")}$"
        elsif method == "it"
          regex = "\\d+_#{test_name.gsub(MINITEST_NAME_RE, '_').downcase}$"
        end

        return [
          whitespace,
          regex
        ]
      end
    end
    nil
  end
end
