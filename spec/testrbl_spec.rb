require 'spec_helper'

describe Testrbl do
  around do |example|
    run "rm -rf tmp && mkdir tmp"
    Dir.chdir "tmp" do
      example.call
    end
    #run "rm -rf tmp"
  end

  def run(cmd, options={})
    result = `#{cmd} 2>&1`
    raise "FAILED #{cmd} --> #{result}" if $?.success? != !options[:fail]
    result
  end

  def testrbl(command, options={})
    run "#{File.expand_path("../../bin/testrbl", __FILE__)} #{command}", options
  end

  def write(file, content)
    folder = File.dirname(file)
    run "mkdir -p #{folder}" unless File.exist?(folder)
    File.open(file, 'w'){|f| f.write content }
  end

  def read(file)
    File.read(file)
  end

  it "has a VERSION" do
    Testrbl::VERSION.should =~ /^[\.\da-z]+$/
  end

  context "-Itest" do
    before do
      write "a_test.rb", <<-RUBY
        require 'test/unit'
        require 'xxx'

        class Xxx < Test::Unit::TestCase
          def test_xxx
            puts 'ABC'
          end

          def test_yyy
            puts 'BCD'
          end
        end
      RUBY
      write("test/xxx.rb", "puts 'XXX LOADED'")
    end

    it "does not include test by default" do
      result = testrbl "a_test.rb:6", :fail => true
      result.should_not include "ABC\n"
    end

    it "can use -Itest for line execution" do
      result = testrbl "-Itest a_test.rb:6"
      result.should include "ABC\n"
      result.should include "XXX LOADED\n"
      result.should_not include "BCD"
    end

    it "can use -I test for line execution" do
      result = testrbl "-I test a_test.rb:6"
      result.should include "ABC\n"
      result.should include "XXX LOADED\n"
      result.should_not include "BCD"
    end
  end

  context "def test_" do
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
      result = testrbl "a_test.rb:4"
      result.should include "ABC\n"
      result.should_not include "BCD"
    end

    it "runs by above a line" do
      result = testrbl "a_test.rb:5"
      result.should include "ABC\n"
      result.should_not include "BCD"
    end

    it "does not run when line is before test" do
      result = testrbl "a_test.rb:3", :fail => true
      result.should include "no test found before line 3"
      result.should_not include "ABC"
    end

    it "runs whole file without number" do
      result = testrbl "a_test.rb"
      result.should include "ABC\n"
      result.should include "BCD"
    end

    it "runs with options" do
      # TODO does not work with files in root folder ... WTF (only happens with a script that runs testrb)
      write("foo/a_test.rb", read("a_test.rb"))
      result = testrbl "foo/a_test.rb -n '/xxx/'"
      result.should include "ABC"
      result.should_not include "BCD"
    end
  end

  context "test with string" do
    before do
      write "a_test.rb", <<-RUBY
        REQUIRE
        class Xxx < ANCESTOR
          test "a" do
            puts 'ABC'
          end

          test "b" do
            puts 'BCD'
          end

          test "c -__.BLA:" do # line 12
            puts 'CDE'
          end

          test "c" do # line 16
            puts 'DEF'
          end

          test "x / y" do # line 20
            puts "XY"
          end
        end
      RUBY
    end

    [
      ["Test::Unit::TestCase", "require 'test/unit'\n"],
      ["ActiveSupport::TestCase", "require 'test/unit'\nrequire 'active_support/test_case'"],
    ].each do |ancestor, require|
      context "with #{ancestor}" do
        before do
          write("a_test.rb", read("a_test.rb").sub("REQUIRE", require).sub("ANCESTOR", ancestor))
        end

        it "runs test" do
          result = testrbl "a_test.rb:8"
          result.should_not include "ABC\n"
          result.should include "BCD\n"
          result.should_not include "CDE\n"
        end

        it "runs test explicitly" do
          result = testrbl "a_test.rb:16"
          result.should_not include "CDE\n"
          result.should include "DEF\n"
        end

        it "runs complex test names" do
          result = testrbl "a_test.rb:12"
          result.should include "CDE\n"
          result.should_not include "DEF\n"
        end

        it "runs with / in name" do
          result = testrbl "a_test.rb:20"
          result.should include "XY\n"
          result.should_not include "DEF\n"
        end
      end
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

            should "..'?! [(" do
              puts 'EFG'
            end
          end

          context "g a" do
            should "a" do
              puts "FGH"
            end
          end

          should "g" do
            puts "GHI"
          end
        end
      RUBY
    end

    it "runs should" do
      result = testrbl "a_test.rb:9"
      result.should_not include "ABC\n"
      result.should include "BCD\n"
      result.should_not include "CDE\n"
    end

    it "runs stuff with regex special chars" do
      result = testrbl "a_test.rb:22"
      result.should_not include "DEF\n"
      result.should include "EFG\n"
    end

    it "runs context" do
      result = testrbl "a_test.rb:13"
      result.should_not include "ABC\n"
      result.should_not include "BCD\n"
      result.should include "CDE\n"
      result.should include "DEF\n"
    end

    it "runs via nested context" do
      result = testrbl "a_test.rb:28"
      result.should_not include "ABC\n"
      result.should_not include "EFG\n"
      result.should include "FGH\n"
    end

    it "runs should explicitly" do
      result = testrbl "a_test.rb:33"
      result.should_not include "ABC\n"
      result.should include "GHI\n"
      result.should_not include "FGH\n"
    end
  end

  context "minitest test" do
    before do
      write "a_test.rb", <<-RUBY
        require 'minitest/autorun'

        class Xxx < MiniTest::Unit::TestCase
          def test_xxx
            puts 'ABC'
          end

          def test_yyy
            puts 'BCD'
          end
        end
      RUBY
    end

    it "runs" do
      result = testrbl "a_test.rb:4"
      result.should include "ABC\n"
      result.should_not include "BCD"
    end
  end

  context "minitest spec" do
    before do
      write "a_test.rb", <<-RUBY
        require 'minitest/autorun'

        describe "a-a" do
          it "b./_-b" do
            puts "ABC"
          end

          it "c-c" do
            puts "BCD"
          end
        end
      RUBY
    end

    it "runs" do
      result = testrbl "a_test.rb:4"
      result.should include "ABC\n"
      result.should_not include "BCD"
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
      result = testrbl "a"
      result.should_not include "ABC\n"
      result.should include "BCD\n"
      result.should include "CDE\n"
    end

    it "runs files and folders" do
      result = testrbl "a/b a/c/c_test.rb"
      result.should_not include "ABC\n"
      result.should_not include "BCD\n"
      result.should include "CDE\n"
      result.should include "DEF\n"
    end

    it "runs multiple files" do
      result = testrbl "a/b/c_test.rb a/c/c_test.rb"
      result.should_not include "ABC\n"
      result.should_not include "BCD\n"
      result.should include "CDE\n"
      result.should include "DEF\n"
    end

    context "avoiding testrb" do
      before do
        write "backtrace_test.rb", <<-RUBY
          puts caller
        RUBY
      end

      it "does not run via testrb if possible" do
        result = testrbl "a/b/c_test.rb backtrace_test.rb"
        result.should include("CDE")
        result.should_not include("bin/testrb:")
      end

      it "runs via testrb if not possible via ruby" do
        result = testrbl "a/b/c_test.rb backtrace_test.rb -v"
        result.should include("CDE")
        result.should include("bin/testrb:")
      end
    end
  end

  describe ".pattern_from_file" do
    def call(content, line)
      lines = content.split("\n").map{|l| l + "\n" }
      Testrbl.pattern_from_file(lines, line)
    end

    after do
      @result.should include("xxx")
      @result.should_not include("yyy")
      @result.should include("zzz")
    end

    it "does not find nested should calls" do
      @result = call("  context \"xxx\" do\n    test \"yyy\" do\n    if true do\n      test \"zzz\" do\n", 4)
    end

    it "does not find nested test calls" do
      @result = call("  context \"xxx\" do\n    test \"yyy\" do\n    if true do\n      test \"zzz\" do\n", 4)
    end

    it "does not find nested it calls" do
      @result = call("  context \"xxx\" do\n    it \"yyy\" do\n    if true do\n      it \"zzz\" do\n", 4)
    end
  end

  describe ".pattern_from_line" do
    def call(line)
      Testrbl.pattern_from_line(line)
    end

    it "finds simple tests" do
      call("  def test_xxx\n").should == ["  ", "xxx"]
    end

    it "does not find other methods" do
      call("  def xxx\n").should == nil
    end

    it "finds calls with single quotes" do
      call("  test 'xx xx' do\n").should == ["  ", "^test(: |_)xx.xx$"]
    end

    it "finds test do calls" do
      call("  test \"xx xx\" do\n").should == ["  ", "^test(: |_)xx.xx$"]
    end

    it "finds complex test do calls" do
      call("  test \"c -__.BLA:\" do\n").should == ["  ", "^test(: |_)c.\\-__\\.BLA:$"]
    end

    it "finds test do calls with comments" do
      call("  test \"x / y\" do # line 20\n").should == ["  ", "^test(: |_)x./.y$"]
    end

    it "finds interpolated test do calls" do
      call("  test \"c\#{111}b\" do\n").should == ["  ", "^test(: |_)c.*b$"]
    end

    it "finds should do calls" do
      call("  should \"xx xx\" do\n").should == ["  ", "should xx xx. (?:(.*))?$"]
    end

    it "finds interpolated context do calls" do
      call("  should \"c\#{111}b\" do\n").should == ["  ", "should c.*b. (?:(.*))?$"]
    end

    it "finds context do calls" do
      call("  context \"xx xx\" do\n").should == ["  ", "xx xx"]
    end

    it "finds context do calls with classes" do
      call("  context Foobar do\n").should == ["  ", "Foobar"]
    end

    it "finds interpolated context do calls" do
      call("  context \"c\#{111}b\" do\n").should == ["  ", "c.*b"]
    end

    it "finds minitest it do calls" do
      call("  it \"xx xx\" do\n").should == ["  ", "^test_\\d+_xx xx$"]
    end

    it "finds complex minitest it do calls" do
      call("  it \"xX ._-..  ___ Xx\" do\n").should == ["  ", "^test_\\d+_xX ._-..  ___ Xx$"]
    end

    it "does not find minitest describe do calls since we cannot run them" do
      call("  describe Foobar do\n").should == nil
    end

    it "escapes regex chars" do
      call("  context \"xx .* xx\" do\n").should == ["  ", "xx \\.\\* xx"]
    end

    it "escapes single quotes which we use to build the pattern" do
      call("  context \"xx ' xx\" do\n").should == ["  ", "xx . xx"]
    end
  end
end
