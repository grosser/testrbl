require 'testrbl/version'

module Testrbl
  PATTERNS = [
    /^(\s+)(should|test)\s+['"](.*)['"]\s+do\s*$/,
    /^(\s+)(context)\s+['"]?(.*?)['"]?\s+do\s*$/,
    /^(\s+)def\s+(test_)([a-z_\d]+)\s*$/
  ]

  def self.run_from_cli(argv)
    command = argv.join(" ")
    if command =~ /^\S+:\d+$/
      file, line = argv.first.split(':')
      file = "./#{file}" if file =~ /^[a-z]/ # fix 1.9 not being able to load local files
      run "#{bundle_exec}ruby #{file} -n '/#{pattern_from_file(file, line)}/'"
    elsif File.file?(command)
      run "#{bundle_exec}ruby #{file}"
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

  def self.pattern_from_file(file, line)
    content = File.readlines(file)
    search = content[0..(line.to_i-1)].reverse

    last_spaces = " " * 100
    found = search.map{|line| pattern_from_line(line) }.compact
    found = found.select do |spaces, name|
      last_spaces = spaces if spaces.size < last_spaces.size
    end

    return found.reverse.map(&:last).join(".*") if found.size > 0

    raise "no test found before line #{line}"
  end

  def self.pattern_from_line(line)
    PATTERNS.each do |r|
      if line =~ r
        whitespace, method, test_name = $1, $2, $3
        regex = Regexp.escape(test_name).gsub("'",".").gsub("\\ "," ")

        if method == "should"
          regex = "#{method} #{regex}\. $"
        elsif method == "test"
          regex = "^#{method}: #{regex}$"
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
