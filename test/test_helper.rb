$LOAD_PATH.unshift File.expand_path("../../lib", __FILE__)
require "connection-manager"

require "minitest/autorun"
require "minitest/spec"
require "minitest/pride"

TCPConnection = Struct.new(:close)
UDPConnection = Struct.new(:close)

CustomConnection = Class.new do
  attr_reader :data

  def initialize
    @data = []
  end

  def write(data)
    @data << data
  end
end
