require 'spec_helper'

describe RunTest do
  it "has a VERSION" do
    RunTest::VERSION.should =~ /^[\.\da-z]+$/
  end
end
