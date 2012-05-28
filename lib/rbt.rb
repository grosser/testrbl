require 'rbt/version'

module RBT
  def self.run_from_cli(argv)
    pattern = nil
    tests = argv.map do |file|
      if file.include?(":")
        pattern = pattern_from_file(file)
        file.split(":").first
      elsif File.directory?(file)
        Dir["#{file.sub(/\/$/,"")}/**/*_test.rb"]
      else
        file
      end
    end.flatten

    if tests.size == 1 and pattern
      run "#{tests.first} #{pattern}"
    elsif pattern
      raise "Supported: files and folders OR 1 file with line number"
    else
      run_files(tests)
    end
  end

  def self.run(command)
    command = "bundle exec ruby #{command}"
    puts command
    exec command
  end

  private

  def self.pattern_from_file(file)
    file, line = file.split(':')
    content = File.readlines(file)
    search = content[0..(line.to_i-1)].reverse
    search.each do |line|
      rex = [
        /^\s+(?:should|context)\s+['"](.*)['"]\s+do\s*$/,
          /^\s+def\s+test_([a-z_\d]+)\s*$/
      ]
      rex.each do |r|
        return "-n '/#{Regexp.escape($1.gsub('\'',"."))}/'" if line =~ r
      end
    end

    raise "no test found before line #{line}"
  end

  def self.run_files(tests)
    require_list = tests.map { |filename| %{"./#{filename}"} }.join(",")
    run "-e '[#{require_list}].each {|f| require f }'" # TODO  -- #{options[:test_options]}
  end
end
