require "timeout"
require "connection_manager/version"
require "connection_manager/wrapper"

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
      connections.delete_if do |_, wrapper|
        wrapper.synchronize do
          wrapper.closed?
        end
      end
    end
    true
  end

  def close(key)
    wrapper = execute do
      connections[key.to_sym]
    end
    wrapper.synchronize do
      wrapper.close
    end if wrapper
  end

  def closed?(key)
    wrapper = execute do
      connections[key.to_sym]
    end
    wrapper.synchronize do
      wrapper.closed?
    end if wrapper
  end

  def delete(key)
    execute do
      wrapper = connections[key.to_sym]
      wrapper.synchronize do
        connections.delete(key.to_sym)
        true
      end if wrapper
    end
  end

  def delete_if(&block)
    execute do
      connections.delete_if do |_, wrapper|
        wrapper.synchronize do
          block.call(wrapper.connection, wrapper.metadata)
        end
      end
    end
    true
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
    wrapper = execute do
      connections[key.to_sym]
    end
    wrapper.synchronize do
      !wrapper.closed?
    end if wrapper
  end

  def pop(key)
    execute do
      wrapper = connections[key.to_sym]
      wrapper.synchronize do
        connections.delete(key.to_sym).connection
      end if wrapper
    end
  end

  def push(key, connection, **options)
    options[:timeout] ||= connection_timeout
    execute do
      previous_connection = connections[key.to_sym]
      executor = if previous_connection
        -> { previous_connection.synchronize { connections[key.to_sym] = Wrapper.new(connection, options) } }
      else
        -> { connections[key.to_sym] = Wrapper.new(connection, options) }
      end
      executor.call
    end
    true
  end

  def shutdown
    execute do
      connections.values.map do |wrapper|
        Thread.new do
          # Keep compatibility with ruby < 2.4
          Thread.current.report_on_exception = false if Thread.current.respond_to?(:report_on_exception=)
          wrapper.synchronize { wrapper.close }
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
    wrapper = execute do
      connections[key.to_sym]
    end
    wrapper.synchronize(options) do
      block.call(wrapper.connection, wrapper.metadata)
    end if wrapper
  end

  private

  attr_reader :connections, :mutex, :connection_timeout, :manager_timeout

  def execute(&block)
    Timeout.timeout(manager_timeout, TimeoutError) do
      mutex.synchronize { block.call }
    end
  end
end
