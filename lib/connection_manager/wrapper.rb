class ConnectionManager::Connection
  class LockingError < StandardError; end
end

class ConnectionManager::Wrapper
  attr_reader :connection, :metadata

  def initialize(connection, **options)
    @connection = connection
    @closed = false
    @close_method = options.fetch(:close_method, :close)
    @metadata = options[:metadata]
    @mutex = Mutex.new
    @timeout = options.fetch(:timeout, 0)
  end

  def close
    return false unless connection.respond_to?(@close_method)
    connection.public_send(@close_method)
    @closed = true
  end

  def closed?
    @closed
  end

  def synchronize(**options, &block)
    timeout = options.fetch(:timeout, @timeout)
    Timeout.timeout(*lock_timeout_args(timeout)) { mutex.lock }
    block.call.tap { mutex.unlock  }
  end

  private

  attr_reader :mutex

  def lock_timeout_args(timeout)
    [timeout, ConnectionManager::Connection::LockingError].tap do |args|
      args << "unable to acquire lock on time" if ConnectionManager::TIMEOUT_ARITY > 2
    end
  end
end
