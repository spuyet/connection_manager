require "timeout"
require "connection_manager/version"
require "connection_manager/connection"

class ConnectionManager
  class TimeoutError < StandardError; end

  def initialize(**options)
    @connection_timeout = options.fetch(:connection_timeout, 0)
    @manager_timeout = options.fetch(:manager_timeout, 0)
    @connections = {}
    @mutex = Mutex.new
  end

  def clear
    execute do
      connections.delete_if do |_, connection|
        connection.synchronize do
          connection.closed?
        end
      end
    end
    true
  end

  def close(key)
    connection = execute do
      connections[key.to_sym]
    end
    connection.synchronize do
      connection.close
    end if connection
  end

  def closed?(key)
    connection = execute do
      connections[key.to_sym]
    end
    connection.synchronize do
      connection.closed?
    end if connection
  end

  def delete(key)
    execute do
      connection = connections[key.to_sym]
      connection.synchronize do
        connections.delete(key.to_sym)
        true
      end if connection
    end
  end

  def empty?
    size == 0
  end

  def exists?(key)
    execute do
      connections.key? key.to_sym
    end
  end

  def open?(key)
    connection = execute do
      connections[key.to_sym]
    end
    connection.synchronize do
      !connection.closed?
    end if connection
  end

  def pop(key)
    execute do
      connection = connections[key.to_sym]
      connection.synchronize do
        connections.delete(key.to_sym).connection
      end if connection
    end
  end

  def push(key, connection, **options)
    options[:timeout] ||= connection_timeout
    execute do
      previous_connection = connections[key.to_sym]
      executor = if previous_connection
        -> { previous_connection.synchronize { connections[key.to_sym] = Connection.new(connection, options) } }
      else
        -> { connections[key.to_sym] = Connection.new(connection, options) }
      end
      executor.call
    end
    true
  end

  def shutdown
    execute do
      connections.values.map do |connection|
        Thread.new do
          connection.synchronize { connection.close }
        end
      end.each(&:join)
    end
    true
  end

  def size
    execute do
      connections.keys.size
    end
  end

  def with(key, **options, &block)
    connection = execute do
      connections[key.to_sym]
    end
    connection.synchronize(options) do
      block.call(connection.connection)
    end if connection
  end

  private

  attr_reader :connections, :mutex, :connection_timeout, :manager_timeout

  def execute(&block)
    Timeout.timeout(manager_timeout, TimeoutError) do
      mutex.synchronize { block.call }
    end
  end
end
