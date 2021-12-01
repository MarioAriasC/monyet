require "./spec_helper"
require "../src/objects"

include Objects

describe "Objects" do
  it "string hash key" do
    hello1 = MString.new("Hello World")
    hello2 = MString.new("Hello World")
    diff1 = MString.new("My name is johnny")
    diff2 = MString.new("My name is johnny")
    hello1.hash_key.should eq(hello2.hash_key)
    diff1.hash_key.should eq(diff2.hash_key)
    hello1.hash_key.should_not eq(diff2.hash_key)
  end
end
