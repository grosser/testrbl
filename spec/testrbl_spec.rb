require 'spec_helper'
require 'tmpdir'

describe Testrbl do
  around do |example|
    Dir.mktmpdir { |dir| Dir.chdir(dir, &example) }
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

  context "--seed" do
    before do
      2.times do |i|
        write "#{i}_test.rb", <<-RUBY
          require 'bundler/setup'
          require 'minitest/autorun'

          class Xxx#{i} < Minitest::Test
            def test_xxx
              puts 'ABC'
            end
          end
        RUBY
      end
    end

    it "seeds a single file" do
      result = testrbl "0_test.rb:6 --seed 1234"
      result.should include "1234"
    end

    it "seeds with -s" do
      result = testrbl "0_test.rb:6 -s 1234"
      result.should include "1234"
    end

    it "seeds multiple files" do
      # adding --seed triggers minitest to be loaded in a weird way and then the second version is loaded via bundler :/
      result = testrbl "0_test.rb 1_test.rb --seed 1234"
      result.should include "1234"
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
            puts "-ABC-"
          end

          it "c-c" do
            puts "-BCD-"
          end

          describe "a-b" do
            it "d-d" do
              puts "-CDE-"
            end

            it "d-e" do
              puts "-DEF-"
            end
          end
        end

        describe "a-c" do
          it "b./_-d" do
            puts "-EFG-"
          end

          it("f-g") do
            puts "-HIJ-"
          end
        end

        describe("h-j") do
          it "i-k" do
            puts "-KLM-"
          end
        end
      RUBY
    end

    def run_line(number)
      result = testrbl "a_test.rb:#{number}"
      result.scan(/-[A-Z]{3}-/).map { |s| s.gsub("-", "") }.sort
    end

    it "runs" do
      run_line("4").should == ["ABC"]
    end

    it "runs describes" do
      run_line("3").should == ["ABC", "BCD", "CDE", "DEF"]
    end

    it "runs nested describes" do
      run_line("12").should == ["CDE", "DEF"]
    end

    it "runs nested it" do
      run_line("13").should == ["CDE"]
    end

    it "runs it with parens" do
      run_line("28").should == ["HIJ"]
    end

    it "runs describe with parens" do
      run_line("33").should == ["KLM"]
    end
  end

  context "multiple files / folders" do
    before do
      write "Gemfile", <<-RUBY
        source "https://rubygems.org"
        gem "test-unit"
      RUBY

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

    it "runs everything when nothing was given" do
      File.rename "a", "test"
      result = testrbl ""
      result.should_not include "ABC\n"
      result.should include "BCD\n"
      result.should include "CDE\n"
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
          require 'test/unit'

          class Xxx1 < Test::Unit::TestCase
            def test_xxx
              puts 'BACKTRACE'
            end
          end
        RUBY
      end

      it "does not run via testrb if possible" do
        result = testrbl "-Itest -I lib a/b/c_test.rb backtrace_test.rb -v"
        result.should include("CDE")
        result.should include("BACKTRACE")
        result.should_not include("bin/testrb:")
      end

      it "runs via testrb if unavoidable" do
        skip "idk why this is broken"
        result = Bundler.with_unbundled_env { testrbl "a/b/c_test.rb backtrace_test.rb -n '/xxx/'" }
        result.should include("CDE")
        result.should include("BACKTRACE")
        result.should include("bin/testrb:")
      end
    end
  end

  context "--changed" do
    before do
      write "test/a_test.rb", "puts 'ABC'"
      write "test/b_test.rb", "puts 'BCD'"
      write "foo.rb", "raise 'BCD'"
      run %{git init && git add -A && git commit -am 'initial'}
    end

    it "can run with other stuff" do
      write "bar.rb", "puts 'CDE'"
      result = testrbl("bar.rb --changed")
      result.should include "CDE"
      result.should_not include "ABC"
    end

    it "runs new files" do
      write "test/b_test.rb", "puts 'CDE'"
      write "test/c_test.rb", "puts 'DEF'"
      result = testrbl("--changed")
      result.should include "CDE"
      result.should include "DEF"
      result.should_not include "ABC"
      result.should_not include "BCD"
    end

    it "runs changed files" do
      write "test/b_test.rb", "puts 'BCD' # changed"
      result = testrbl("--changed")
      result.should include "BCD"
      result.should_not include "ABC"
    end

    it "runs staged files" do
      write "test/b_test.rb", "puts 'BCD' # changed"
      run "git add test/b_test.rb"
      result = testrbl("--changed")
      result.should include "BCD"
      result.should_not include "ABC"
    end

    it "does not run removed files" do
      run "rm test/b_test.rb"
      write "test/c_test.rb", "puts 'DEF'"
      result = testrbl("--changed")
      result.should include "DEF"
      result.should_not include "ABC"
    end

    it "runs last commit when no files are changed" do
      result = testrbl("--changed")
      result.should include "ABC"
      result.should include "BCD"
    end
  end

  describe ".test_pattern_from_file" do
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

    it "does not find nested non-test blocks" do
      @result = call("  context \"yyy\" do\n  end\n  blub do\n    context \"xxx\" do\n      it \"zzz\" do\n", 5)
    end

    it "does not find nested non-test blocks" do
      @result = call("  context \"yyy\" do\n  end\n  blub do\n    context \"xxx\" do\n      it \"zzz\" do\n      end\n    end\n  end\n", 8)
    end
  end

  describe ".test_pattern_from_line" do
    def call(line)
      Testrbl.send(:test_pattern_from_line, line)
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

    describe "minitest id do" do
      it "finds simple" do
        call("  it \"xx xx\" do\n").should == ["  ", "#test_\\d+_xx xx$"]
      end

      it "finds complex" do
        call("  it \"xX ._-..  ___ Xx\" do\n").should == ["  ", "#test_\\d+_xX \\._\\-\\.\\.  ___ Xx$"]
      end

      it "finds with special characters" do
        call("  it \"hmm? it's weird\\\"?\" do\n").should == ["  ", "#test_\\d+_hmm\\? it.s weird\\\\\"\\?$"]
      end
    end

    it "finds minitest describe do calls" do
      call("  describe Foobar do\n").should == ["  ", "Foobar(::)?"]
    end

    it "escapes regex chars" do
      call("  context \"xx .* xx\" do\n").should == ["  ", "xx \\.\\* xx"]
    end

    it "escapes single quotes which we use to build the pattern" do
      call("  context \"xx ' xx\" do\n").should == ["  ", "xx . xx"]
    end
  end

  describe ".partition_argv" do
    def call(*args)
      Testrbl.send(:partition_argv, *args)
    end

    it "finds files" do
      call(["xxx"]).should == [["xxx"], []]
    end

    it "finds files after multi-space options" do
      call(["-I", "test", "xxx"]).should == [["xxx"], ["-I", "test"]]
    end

    it "finds options" do
      call(["-I", "test"]).should == [[], ["-I", "test"]]
    end

    it "finds --verbose" do
      call(["--verbose", "test"]).should == [["test"], ["--verbose"]]
    end

    it "finds -- options" do
      call(["--foo", "test"]).should == [["test"], ["--foo"]]
    end

    it "finds mashed options" do
      call(["-Itest"]).should == [[], ["-Itest"]]
    end
  end
end
