Run ruby Test::Unit/Shoulda/Minitest tests by line-number / folder / the dozen.<br/>
(everything not matching "file:line" is simply passed to testrb)<br/>
Instant execution, 0 wait-time!

Install
=======
    gem install testrbl

Usage
=====
    testrbl test/unit/xxx_test.rb:123 # test by line number
    testrbl test/unit                 # everything _test.rb in a folder (on 1.8 this would be test/unit/*)
    testrbl xxx_test.rb yyy_test.rb   # multiple files

Tips
====
 - `can't find executable testrb`: uninstall old version of test-unit, they define testrb in multiple incompatible ways

TODO
====
 - fix tests on ree/1.9.2
 - alternate minitest syntax: test_0017_should not link already linked URLs

Author
======
[Michael Grosser](http://grosser.it)<br/>
michael@grosser.it<br/>
License: MIT<br/>
[![Build Status](https://secure.travis-ci.org/grosser/testrbl.png)](http://travis-ci.org/grosser/testrbl)
