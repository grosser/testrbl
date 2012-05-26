require 'spec_helper'

describe RunTest do
  around do |example|
    run "rm -rf tmp && mkdir tmp"
    Dir.chdir "tmp" do
      example.call
    end
    run "rm -rf tmp"
  end

  def run(cmd, options={})
    result = `#{cmd} 2>&1`
    raise "FAILED #{cmd} --> #{result}" if $?.success? != !options[:fail]
    result
  end

  def write(file, content)
    folder = File.dirname(file)
    run "mkdir -p #{folder}" unless File.exist?(folder)
    File.open(file, 'w'){|f| f.write content }
  end

  it "has a VERSION" do
    RunTest::VERSION.should =~ /^[\.\da-z]+$/
  end

  context "with a simple setup" do
    before do
      write "a_test.rb", <<-RUBY
        require 'test/unit'

        class Xxx < Test::Unit::TestCase
          def test_xxx
            puts 'ABC'
          end

          def test_yyy
            puts 'BCD'
          end
        end
      RUBY
    end

    it "runs by exact line" do
      result = run "../../bin/rtest a_test.rb:4"
      result.should include "ABC\n"
      result.should_not include "BCD"
    end

    it "runs by above a line" do
      result = run "../../bin/rtest a_test.rb:5"
      result.should include "ABC\n"
      result.should_not include "BCD"
    end

    it "does not run when line is before test" do
      result = run "../../bin/rtest a_test.rb:3", :fail => true
      result.should include "no test found before line 3\n"
      result.should_not include "ABC"
    end

    it "runs whole file without number" do
      result = run "../../bin/rtest a_test.rb"
      result.should include "ABC\n"
      result.should include "BCD"
    end
  end

  context "shoulda" do
    before do
      write "a_test.rb", <<-RUBY
        require 'test/unit'
        require 'shoulda'

        class Xxx < Test::Unit::TestCase
          should "a" do
            puts 'ABC'
          end

          should "b" do
            puts 'BCD'
          end

          context "c" do
            should "d" do
              puts 'CDE'
            end

            should "e" do
              puts 'DEF'
            end
          end
        end
      RUBY
    end

    it "runs should" do
      result = run "../../bin/rtest a_test.rb:9"
      result.should_not include "ABC\n"
      result.should include "BCD\n"
      result.should_not include "CDE\n"
    end

    it "runs context" do
      result = run "../../bin/rtest a_test.rb:13"
      result.should_not include "ABC\n"
      result.should_not include "BCD\n"
      result.should include "CDE\n"
      result.should include "DEF\n"
    end
  end

  context "multiple files / folders" do
    before do
      write "a_test.rb", <<-RUBY
        require 'test/unit'

        class Xxx1 < Test::Unit::TestCase
          def test_xxx
            puts 'ABC'
          end
        end
      RUBY

      write "a/a_test.rb", <<-RUBY
        require 'test/unit'

        class Xxx2 < Test::Unit::TestCase
          def test_xxx
            puts 'BCD'
          end
        end
      RUBY

      write "a/b/c_test.rb", <<-RUBY
        require 'test/unit'

        class Xxx3 < Test::Unit::TestCase
          def test_xxx
            puts 'CDE'
          end
        end
      RUBY

      write "a/c/c_test.rb", <<-RUBY
        require 'test/unit'

        class Xxx4 < Test::Unit::TestCase
          def test_xxx
            puts 'DEF'
          end
        end
      RUBY
    end

    it "runs a folder with subfolders" do
      result = run "../../bin/rtest a"
      result.should_not include "ABC\n"
      result.should include "BCD\n"
      result.should include "CDE\n"
    end

    it "runs files and folders" do
      result = run "../../bin/rtest a/b a/c/c_test.rb"
      result.should_not include "ABC\n"
      result.should_not include "BCD\n"
      result.should include "CDE\n"
      result.should include "DEF\n"
    end

    it "runs multiple files" do
      result = run "../../bin/rtest a/b/c_test.rb a/c/c_test.rb"
      result.should_not include "ABC\n"
      result.should_not include "BCD\n"
      result.should include "CDE\n"
      result.should include "DEF\n"
    end

    it "fails with multiple files with lines" do
      run "../../bin/rtest a/b/c_test.rb:4 a/c/c_test.rb", :fail => true
    end
  end
end
