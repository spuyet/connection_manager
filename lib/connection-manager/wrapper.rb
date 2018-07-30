require "connection-manager/custom_timeout"

class ConnectionManager::Connection
  class LockingError < StandardError; end
  class ClosedError < StandardError; end
end

class ConnectionManager::Wrapper
  include ::ConnectionManager::CustomTimeout

  attr_reader :connection, :metadata

  def initialize(options = {}, &block)
    @closed = false
    @close_method = options.fetch(:close_method, :close)
    @initializer = block
    @metadata = options.fetch(:metadata, {})
    @mutex = Mutex.new
    @timeout = options[:timeout]
  end

  def close
    return true if closed?
    return false unless connection.respond_to?(close_method)
    connection.public_send(close_method)
    @closed = true
  end

  def closed?
    @closed
  end

  def reset
    @closed = false
    @connection = nil
    true
  end

  def synchronize(**options, &block)
    @connection ||= initializer.call
    timeout = options.fetch(:timeout, @timeout)
    if timeout
      with_custom_timeout(timeout, mutex, ::ConnectionManager::Connection::LockingError, &block)
    else
      mutex.synchronize(&block)
    end
  end

  private

  attr_reader :close_method, :mutex, :initializer
end
