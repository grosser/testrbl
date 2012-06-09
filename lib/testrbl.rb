require 'testrbl/version'

module Testrbl
  PATTERNS = [
    /^(\s+)(should|test)\s+['"](.*)['"]\s+do\s*$/,
    /^(\s+)(context)\s+['"]?(.*?)['"]?\s+do\s*$/,
    /^(\s+)def\s+(test_)([a-z_\d]+)\s*$/
  ]

  def self.run_from_cli(argv)
    # we only work with 1 file with line-number, everything else gets passed thourgh
    if argv.join(" ") !~ /^\S+:\d+$/
      run "testrb #{argv.map{|a| a.include?(' ') ? "'#{a}'" : a }.join(' ')}"
    end

    file, line = argv.first.split(':')
    file = "./#{file}" if file =~ /^[a-z]/ # fix 1.9 not being able to load local files
    run "testrb #{file} -n '/#{pattern_from_file(file, line)}/'"
  end

  def self.run(command)
    safe_to_bundle_exec = (File.exist?('Gemfile.lock') and File.read('Gemfile.lock').include?(" test-unit "))
    command = "#{"bundle exec " if safe_to_bundle_exec}#{command} --use-color"
    puts command
    exec command
  end

  private

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
