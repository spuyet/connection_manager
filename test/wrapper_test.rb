require "test_helper"

describe ConnectionManager::Wrapper do
  before do
    @wrapper = ConnectionManager::Wrapper.new { TCPConnection.new }
  end

  describe "#initialize" do
    it "does not open the connection" do
      assert_nil @wrapper.connection
    end

    it "does set connection as open" do
      assert_equal false, @wrapper.closed?
    end

    it "does store metadata" do
     wrapper = ConnectionManager::Wrapper.new(metadata: "foo_bar") { TCPConnection.new }
     assert_equal "foo_bar", wrapper.metadata
    end
  end

  describe "#close" do
    before do
    end

    it "does close the connection" do
      assert_equal false, @wrapper.closed?
      @wrapper.synchronize {}
      assert_equal true, @wrapper.close
      assert_equal true, @wrapper.closed?
    end

    describe "when connection cannot be closed" do
      it "does not close connection" do
        wrapper = ConnectionManager::Wrapper.new { OpenStruct.new }
        wrapper.synchronize do
          assert_equal false, wrapper.closed?
          assert_equal false, wrapper.close
          assert_equal false, wrapper.closed?
        end
      end
    end

    describe "with a mapped #close method" do
      it "does call the mapped method when defined" do
        wrapper = ConnectionManager::Wrapper.new(close_method: :terminate) { OpenStruct.new(terminate: true) }
        wrapper.synchronize do
          assert_equal false, wrapper.closed?
          assert_equal true, wrapper.close
          assert_equal true, wrapper.closed?
        end
      end

      it "does not call the mapped method when not defined" do
        wrapper = ConnectionManager::Wrapper.new(close_method: :foo_bar) { OpenStruct.new(terminate: true) }
        wrapper.synchronize do
          assert_equal false, wrapper.closed?
          assert_equal false, wrapper.close
          assert_equal false, wrapper.closed?
        end
      end
    end
  end

  describe "#closed?" do
    it "does return true when connection is closed" do
      wrapper = ConnectionManager::Wrapper.new { OpenStruct.new(close: true) }
      wrapper.synchronize {}
      assert_equal false, wrapper.closed?
      assert_equal true, wrapper.close
      assert_equal true, wrapper.closed?
    end
  end

  describe "#reset" do
    it "does reset the connection" do
      wrapper = ConnectionManager::Wrapper.new(timeout: 0.001) { CustomConnection.new }
      wrapper.synchronize do
        wrapper.connection.write("foo_bar")
        assert_equal ["foo_bar"], wrapper.connection.data
        wrapper.reset
      end
      wrapper.synchronize { assert_equal [], wrapper.connection.data }
    end

    it "does reopen the connection when closed" do
      @wrapper.synchronize do
        assert_equal true, @wrapper.close
        assert_equal true, @wrapper.closed?
        assert_equal true, @wrapper.reset
        assert_equal false, @wrapper.closed?
      end
    end
  end

  def with_connection_locked(&block)
    wrapper = ConnectionManager::Wrapper.new(timeout: 0.001) { CustomConnection.new }
    t1 = Thread.new do
      wrapper.synchronize { sleep 42 }
    end
    sleep 0.001 while t1.status != "sleep"
    block.call(wrapper)
  end

  describe "#synchronize" do
    it "does call the block" do
      wrapper = ConnectionManager::Wrapper.new(timeout: 0.001) { CustomConnection.new }
      foo = 0
      wrapper.synchronize { foo = 42 }
      assert_equal 42, foo
    end

    describe "when timeout is set" do
      it "does raise a connection locking error when lock timeout elapsed" do
        with_connection_locked do |wrapper|
          assert_raises(ConnectionManager::Connection::LockingError) { wrapper.synchronize { raise } }
        end
      end
    end

    it "has to be thread safe" do
      wrapper = ConnectionManager::Wrapper.new { CustomConnection.new }
      5.times.map do |i|
        Thread.new do
          wrapper.synchronize do
            wrapper.connection.write(i)
            sleep 0.001
            wrapper.connection.write(i)
          end
        end
      end.each(&:join)
      wrapper.connection.data.each_slice(2) do |a, b|
        assert_equal a, b
      end
    end
  end
end
