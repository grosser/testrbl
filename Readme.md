Run ruby Test::Unit/Shoulda tests by line-number / folder / the dozen.

Install
=======
    gem install rbtest


Usage
=====
    rbtest test/unit/xxx_test.rb:123                     # test by line number
    rbtest test/unit test/unit                           # everything _test.rb in a folder
    rbtest test/unit/xxx_test.rb test/unit/yyy_test.rb   # multiple files

Author
======
[Michael Grosser](http://grosser.it)<br/>
michael@grosser.it<br/>
License: MIT<br/>
[![Build Status](https://secure.travis-ci.org/grosser/rbt.png)](http://travis-ci.org/grosser/rbt)
