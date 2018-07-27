require "test_helper"

describe ConnectionManager::Wrapper do
  before do
    @connection = ConnectionManager::Wrapper.new(TCPConnection.new)
  end

  describe "#close" do
    it "does close the connection" do
      refute @connection.closed?
      assert @connection.close
      assert @connection.closed?
    end

    describe "when connection cannot be closed" do
      it "does not close connection" do
        my_connection = OpenStruct.new
        wrapper = ConnectionManager::Wrapper.new(my_connection)
        refute wrapper.closed?
        refute wrapper.close
        refute wrapper.closed?
      end
    end

    describe "with a mapped #close method" do
      it "does call the mapped method when defined" do
        my_connection = OpenStruct.new(terminate: true)
        wrapper = ConnectionManager::Wrapper.new(my_connection, close_method: :terminate)
        refute wrapper.closed?
        assert wrapper.close
        assert wrapper.closed?
      end

      it "does not call the mapped method when not defined" do
        my_connection = OpenStruct.new(terminate: true)
        wrapper = ConnectionManager::Wrapper.new(my_connection, close_method: :foo_bar)
        refute wrapper.closed?
        refute wrapper.close
        refute wrapper.closed?
      end
    end
  end

  describe "#closed?" do
    it "does return true when connection is closed" do
      refute @connection.closed?
      assert @connection.close
      assert @connection.closed?
    end
  end

  def with_connection_locked(&block)
    wrapper = ConnectionManager::Wrapper.new(CustomConnection.new, timeout: 0.001)
    t1 = Thread.new do
      wrapper.synchronize { sleep 42 }
    end
    sleep 0.001 while t1.status != "sleep"
    block.call(wrapper)
  end

  describe "#synchronize" do
    describe "when timeout is set" do
      it "does raise a connection locking error when lock timeout elapsed" do
        with_connection_locked do |wrapper|
          assert_raises(ConnectionManager::Connection::LockingError) { wrapper.synchronize { raise } }
        end
      end
    end

    it "has to be thread safe" do
      wrapper = ConnectionManager::Wrapper.new(CustomConnection.new)
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