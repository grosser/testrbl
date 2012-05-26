Run ruby Test::Unit/Shoulda tests by line-number or folder or the dozen.

Install
=======
    gem install run_test


Usage
=====
    rtest test/unit/xxx_test.rb:123                     # test by line number
    rtest test/unit test/unit                           # everything _test.rb in a folder
    rtest test/unit/xxx_test.rb test/unit/yyy_test.rb   # multiple files

Author
======
[Michael Grosser](http://grosser.it)<br/>
michael@grosser.it<br/>
License: MIT<br/>
[![Build Status](https://secure.travis-ci.org/grosser/run_test.png)](http://travis-ci.org/grosser/run_test)
