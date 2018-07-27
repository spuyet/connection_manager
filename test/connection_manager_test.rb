require "test_helper"

describe ConnectionManager do
  before do
    @connection_manager = ConnectionManager.new
  end

  def with_manager_locked(&block)
    connection_manager = ConnectionManager.new(manager_timeout: 0.001)

    t1 = Thread.new do
      connection_manager.instance_exec { @connections }.stub(:delete_if, proc { sleep 42 }) { connection_manager.clear }
    end
    sleep 0.001 while t1.status != "sleep"
    block.call(connection_manager)
  end

  def with_connection_locked(connection_name, &block)
    connection_manager = ConnectionManager.new(connection_timeout: 0.001)
    connection_manager.push(connection_name, TCPConnection.new)
    t1 = Thread.new do
      wrapper = connection_manager.instance_exec { connections[connection_name.to_sym] }
      wrapper.stub(:closed?, proc { sleep 42 }) { connection_manager.closed?("my_connection") }
    end
    sleep 0.001 while t1.status != "sleep"
    block.call(connection_manager)
  end

  describe "::VERSION" do
    it "returns a version number" do
      refute_nil ::ConnectionManager::VERSION
    end
  end

  describe "#clear" do
    it "works with no connection in pool" do
      assert @connection_manager.clear
    end

    it "removes closed connections" do
      assert @connection_manager.push("my_connection", TCPConnection.new)
      assert_equal 1, @connection_manager.size
      assert @connection_manager.close("my_connection")

      assert @connection_manager.clear
      assert_equal 0, @connection_manager.size
    end

    it "keeps open connections" do
      assert @connection_manager.push("my_open_connection", TCPConnection.new)
      assert @connection_manager.push("my_closed_connection", TCPConnection.new)
      assert @connection_manager.close("my_closed_connection")

      assert_equal 2, @connection_manager.size
      assert @connection_manager.clear
      assert_equal 1, @connection_manager.size
    end

    it "does raise a manager locking error when manager lock is not released on time" do
      with_manager_locked do |connection_manager|
        assert_raises(ConnectionManager::LockingError) { connection_manager.clear }
      end
    end

    it "does raise a connection locking error when connection lock is not released" do
      with_connection_locked("my_connection") do |connection_manager|
        assert_raises(ConnectionManager::Connection::LockingError) { connection_manager.clear }
      end
    end
  end

  describe "#close" do
    it "does close connection" do
      assert @connection_manager.push("my_connection", TCPConnection.new)
      refute @connection_manager.closed?("my_connection")
      assert @connection_manager.close("my_connection")
      assert @connection_manager.closed?("my_connection")
    end

    it "does nothing with unknown connection" do
      assert_nil @connection_manager.close("unknown_connection")
    end

    it "does not close other connections" do
      assert @connection_manager.push("my_connection_to_close", TCPConnection.new)
      assert @connection_manager.push("my_open_connection", TCPConnection.new)
      refute @connection_manager.closed?("my_connection_to_close")
      assert @connection_manager.close("my_connection_to_close")
      assert @connection_manager.closed?("my_connection_to_close")
      assert @connection_manager.open?("my_open_connection")
    end

    it "does raise a manager locking error when manager lock is not released on time" do
      with_manager_locked do |connection_manager|
        assert_raises(ConnectionManager::LockingError) { connection_manager.close("my_connection") }
      end
    end

    it "does raise a connection locking error when connection lock is not released" do
      with_connection_locked("my_connection") do |connection_manager|
        assert_raises(ConnectionManager::Connection::LockingError) { connection_manager.close("my_connection") }
      end
    end
  end

  describe "#closed?" do
    it "does nothing with unknown connection" do
      assert_nil @connection_manager.closed?("my_unknown_connection")
    end

    it "returns true when connection is closed" do
      assert @connection_manager.push("my_connection", TCPConnection.new)
      assert @connection_manager.close("my_connection")
      assert @connection_manager.closed?("my_connection")
    end

    it "returns false when connection is open" do
      assert @connection_manager.push("my_connection", TCPConnection.new)
      refute @connection_manager.closed?("my_connection")
    end

    it "does raise a manager locking error when manager lock is not released on time" do
      with_manager_locked do |connection_manager|
        assert_raises(ConnectionManager::LockingError) { connection_manager.closed?("my_connection") }
      end
    end

    it "does raise a connection locking error when connection lock is not released" do
      with_connection_locked("my_connection") do |connection_manager|
        assert_raises(ConnectionManager::Connection::LockingError) { connection_manager.closed?("my_connection") }
      end
    end
  end

  describe "#delete" do
    it "does delete connection from pool" do
      assert @connection_manager.push("my_connection", TCPConnection.new)
      assert @connection_manager.exists?("my_connection")
      assert @connection_manager.delete("my_connection")
      refute @connection_manager.exists?("my_connection")
    end

    it "returns nothing for unknown connection" do
      assert_nil @connection_manager.delete("unknown_connection")
    end

    it "does raise a manager locking error when manager lock is not released on time" do
      with_manager_locked do |connection_manager|
        assert_raises(ConnectionManager::LockingError) { connection_manager.delete("my_connection") }
      end
    end

    it "does raise a connection locking error when connection lock is not released" do
      with_connection_locked("my_connection") do |connection_manager|
        assert_raises(ConnectionManager::Connection::LockingError) { connection_manager.delete("my_connection") }
      end
    end
  end

  describe "#delete_if?" do
    it "does delete connection when block returns true" do
      assert @connection_manager.push("my_tcp_connection_to_delete", TCPConnection.new, metadata: { to_delete: true })
      assert @connection_manager.push("my_tcp_connection_to_keep", TCPConnection.new, metadata: { to_delete: false })
      assert @connection_manager.push("my_udp_connection_to_delete", TCPConnection.new, metadata: { to_delete: true })
      assert @connection_manager.push("my_udp_connection_to_keep", TCPConnection.new, metadata: { to_delete: false })
      assert @connection_manager.delete_if { |_, metadata| metadata[:to_delete] }
      assert_equal 2, @connection_manager.size
      assert @connection_manager.exists?("my_tcp_connection_to_keep")
      assert @connection_manager.exists?("my_udp_connection_to_keep")
    end

    it "does raise a manager locking error when manager lock is not released on time" do
      with_manager_locked do |connection_manager|
        assert_raises(ConnectionManager::LockingError) do
          connection_manager.delete_if { |connection, _| connection.is_a? TCPConnection }
        end
      end
    end

    it "does raise a connection locking error when connection lock is not released" do
      with_connection_locked("my_connection") do |connection_manager|
        assert_raises(ConnectionManager::Connection::LockingError) do
         connection_manager.delete_if { |connection, _| connection.is_a? TCPConnection }
        end
      end
    end
  end

  describe "#empty?" do
    it "returns true when pool is empty" do
      assert @connection_manager.empty?
    end

    it "returns false when pool is not empty" do
      assert @connection_manager.push("my_connection", TCPConnection.new)
      refute @connection_manager.empty?
    end

    it "does raise a manager locking error when manager lock is not released on time" do
      with_manager_locked do |connection_manager|
        assert_raises(ConnectionManager::LockingError) { connection_manager.empty? }
      end
    end
  end

  describe "#exists?" do
    it "returns true if connection does exist" do
      assert @connection_manager.push("my_connection", TCPConnection.new)
      assert @connection_manager.exists?("my_connection")
    end

    it "returns false if connection does not exist" do
      refute @connection_manager.exists?("my_connection")
    end

    it "does raise a manager locking error when manager lock is not released on time" do
      with_manager_locked do |connection_manager|
        assert_raises(ConnectionManager::LockingError) { connection_manager.exists?("my_connection") }
      end
    end
  end

  describe "#pop" do
    it "returns selected connection" do
      assert @connection_manager.push("my_connection", TCPConnection.new)
      assert_instance_of TCPConnection, @connection_manager.pop("my_connection")
    end

    it "returns nothing for unknown connection" do
      assert_nil @connection_manager.pop("unknown_connection")
    end

    it "removes connection from connection manager" do
      assert @connection_manager.push("my_connection", TCPConnection.new)
      refute @connection_manager.empty?
      @connection_manager.pop("my_connection")
      assert @connection_manager.empty?
    end

    it "does raise a manager locking error when manager lock is not released on time" do
      with_manager_locked do |connection_manager|
        assert_raises(ConnectionManager::LockingError) { connection_manager.pop("my_connection") }
      end
    end

    it "does raise a connection locking error when connection lock is not released" do
      with_connection_locked("my_connection") do |connection_manager|
        assert_raises(ConnectionManager::Connection::LockingError) { connection_manager.pop("my_connection") }
      end
    end
  end

  describe "#push" do
    it "adds connection to connection manager" do
      refute @connection_manager.exists?("my_connection")
      assert @connection_manager.push("my_connection", TCPConnection.new)
      assert @connection_manager.exists?("my_connection")
    end

    it "does override connection stored at key" do
      assert @connection_manager.push("my_connection", TCPConnection.new)
      assert_equal 1, @connection_manager.size
      assert @connection_manager.push("my_connection", UDPConnection.new)
      assert_equal 1, @connection_manager.size
      assert_instance_of UDPConnection,  @connection_manager.pop("my_connection")
    end

    it "does raise a manager locking error when manager lock is not released on time" do
      with_manager_locked do |connection_manager|
        assert_raises(ConnectionManager::LockingError) { connection_manager.push("my_connection", TCPConnection.new) }
      end
    end

    it "does raise a connection locking error when connection lock is not released" do
      with_connection_locked("my_connection") do |connection_manager|
        assert_raises(ConnectionManager::Connection::LockingError) { connection_manager.push("my_connection", TCPConnection.new) }
      end
    end
  end

  describe "#open?" do
    it "returns true for an open connection" do
      assert @connection_manager.push("my_connection", TCPConnection.new)
      assert @connection_manager.open?("my_connection")
    end

    it "returns false for a closed connection" do
      assert @connection_manager.push("my_connection", TCPConnection.new)
      assert @connection_manager.close("my_connection")
      assert @connection_manager.closed?("my_connection")
    end

    it "does raise a manager locking error when manager lock is not released on time" do
      with_manager_locked do |connection_manager|
        assert_raises(ConnectionManager::LockingError) { connection_manager.open?("my_connection") }
      end
    end

    it "does raise a connection locking error when connection lock is not released" do
      with_connection_locked("my_connection") do |connection_manager|
        assert_raises(ConnectionManager::Connection::LockingError) { connection_manager.open?("my_connection") }
      end
    end
  end

  describe "#shutdown" do
    it "does close all stored connections" do
      assert @connection_manager.push("my_tcp_connection", TCPConnection.new)
      assert @connection_manager.push("my_udp_connection", UDPConnection.new)
      assert @connection_manager.open?("my_tcp_connection")
      assert @connection_manager.open?("my_udp_connection")
      assert @connection_manager.shutdown
      assert @connection_manager.closed?("my_tcp_connection")
      assert @connection_manager.closed?("my_udp_connection")
    end

    it "does nothing when there is no connections stored" do
      assert @connection_manager.shutdown
    end

    it "does raise a manager locking error when manager lock is not released on time" do
      with_manager_locked do |connection_manager|
        assert_raises(ConnectionManager::LockingError) { connection_manager.shutdown }
      end
    end

    it "does raise a connection locking error when connection lock is not released" do
      with_connection_locked("my_connection") do |connection_manager|
        assert_raises(ConnectionManager::Connection::LockingError) { connection_manager.shutdown }
      end
    end
  end

  describe "#size" do
    it "is empty by default" do
      assert_equal @connection_manager.size, 0
    end

    it "increases when new connection is pushed" do
      assert_equal @connection_manager.size, 0
      assert @connection_manager.push("my_tcp_connection", TCPConnection.new)
      assert_equal @connection_manager.size, 1
      assert @connection_manager.push("my_udp_connection", UDPConnection.new)
      assert_equal @connection_manager.size, 2
    end

    it "decreases when a connection is removed" do
      assert @connection_manager.push("my_tcp_connection", TCPConnection.new)
      assert @connection_manager.push("my_udp_connection", UDPConnection.new)
      assert_equal @connection_manager.size, 2
      assert @connection_manager.delete("my_tcp_connection")
      assert_equal @connection_manager.size, 1
      assert @connection_manager.delete("my_udp_connection")
      assert_equal @connection_manager.size, 0
    end

    it "does raise a manager locking error when manager lock is not released on time" do
      with_manager_locked do |connection_manager|
        assert_raises(ConnectionManager::LockingError) { connection_manager.size }
      end
    end
  end

  describe "#with" do
    it "does pass the selected connection as argument" do
      assert @connection_manager.push("my_tcp_connection", TCPConnection.new)
      assert @connection_manager.push("my_udp_connection", UDPConnection.new)
      @connection_manager.with("my_tcp_connection") do |connection|
        assert_instance_of TCPConnection, connection
      end
    end

    it "does not call block with an unknow connection" do
      @connection_manager.with("unknown_connection") do |connection|
        raise StandardError, "never called"
      end
    end

    it "does raise a manager locking error when manager lock is not released on time" do
      with_manager_locked do |connection_manager|
        assert_raises(ConnectionManager::LockingError) { connection_manager.with("my_connection") {} }
      end
    end

    it "does raise a connection locking error when connection lock is not released" do
      with_connection_locked("my_connection") do |connection_manager|
        assert_raises(ConnectionManager::Connection::LockingError) { connection_manager.with("my_connection") {} }
      end
    end
  end
end
